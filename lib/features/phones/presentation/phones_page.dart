import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../data/phone_repository.dart';
import 'phone_direct_sale_page.dart';
import 'phone_detail_page.dart';
import 'phone_form_page.dart';

class PhonesPage extends StatefulWidget {
  const PhonesPage({super.key});

  @override
  State<PhonesPage> createState() => _PhonesPageState();
}

class _PhonesPageState extends State<PhonesPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF16A34A);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  final _repository = const PhoneRepository();
  final _searchController = TextEditingController();

  List<PhoneStockItem> _phones = [];
  String? _error;
  bool _isLoading = true;
  bool _showSold = false;

  List<PhoneStockItem> get _filteredPhones {
    final query = _searchController.text;
    return _phones.where((phone) {
      final matchesStatus = _showSold ? phone.isSold : !phone.isSold;
      return matchesStatus && phone.matchesQuery(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPhones();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPhones() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final phones = await _repository.fetchPhones();
      if (!mounted) {
        return;
      }
      setState(() {
        _phones = phones;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat data HP: $error');
    }
  }

  Future<void> _refreshPhones() async {
    try {
      final phones = await _repository.fetchPhones();
      if (!mounted) {
        return;
      }
      setState(() {
        _phones = phones;
        _error = null;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat data HP: $error');
    }
  }

  void _setError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _error = message;
    });
  }

  Future<void> _openForm() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => const PhoneFormPage()),
    );
    if (changed == true) {
      await _loadPhones();
    }
  }

  Future<void> _openDirectSale() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => const PhoneDirectSalePage(),
      ),
    );
    if (changed == true) {
      setState(() {
        _showSold = true;
      });
      await _loadPhones();
    }
  }

  Future<void> _openDetail(PhoneStockItem phone) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PhoneDetailPage(phoneId: phone.id),
      ),
    );
    await _refreshPhones();
  }

  @override
  Widget build(BuildContext context) {
    final filteredPhones = _filteredPhones;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Jual Beli HP'),
        centerTitle: false,
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadPhones,
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'Refresh HP',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_outlined),
        label: const Text('Beli HP'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshPhones,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _ActionGrid(
                onBuy: _openForm,
                onSell: _openDirectSale,
                onStock: () {
                  setState(() {
                    _showSold = false;
                  });
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.inventory_2_outlined),
                    label: Text('Stok'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('Terjual'),
                  ),
                ],
                selected: {_showSold},
                showSelectedIcon: false,
                onSelectionChanged: (selected) {
                  setState(() {
                    _showSold = selected.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Cari HP',
                  prefixIcon: Icon(Icons.search_outlined),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorState(message: _error!, onRetry: _loadPhones)
              else if (filteredPhones.isEmpty)
                _EmptyState(
                  message: _showSold
                      ? 'Belum ada HP terjual'
                      : 'Belum ada stok HP',
                )
              else
                ...filteredPhones.map(
                  (phone) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PhoneCard(
                      phone: phone,
                      onTap: () => _openDetail(phone),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onBuy,
    required this.onSell,
    required this.onStock,
  });

  final VoidCallback onBuy;
  final VoidCallback onSell;
  final VoidCallback onStock;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem('Beli HP', Icons.add_shopping_cart_outlined, onBuy),
      _ActionItem('Jual HP', Icons.sell_outlined, onSell),
      _ActionItem('Stok HP', Icons.inventory_2_outlined, onStock),
    ];
    return Row(
      children: actions.map((item) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: item == actions.last ? 0 : 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _PhonesPageState._primaryColor.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.icon,
                          color: _PhonesPageState._primaryColor,
                          size: 21,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: _PhonesPageState._textColor,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActionItem {
  const _ActionItem(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({required this.phone, required this.onTap});

  final PhoneStockItem phone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priceLabel = phone.isSold ? 'Harga Jual' : 'Harga Jual';
    final priceValue = phone.targetOrSellingPrice == null
        ? '-'
        : formatRupiah(phone.targetOrSellingPrice!);
    final result = phone.isSold ? phone.actualProfit : phone.potentialProfit;
    final resultLabel = phone.isSold
        ? (phone.actualProfit >= 0 ? 'Laba' : 'Rugi')
        : result == null
        ? 'Potensi'
        : result >= 0
        ? 'Potensi Untung'
        : 'Potensi Rugi';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _PhonesPageState._primaryColor.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.phone_android_outlined,
                      color: _PhonesPageState._primaryColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phone.deviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: _PhonesPageState._textColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (phone.condition.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            phone.condition,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: _PhonesPageState._mutedColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          'IMEI: ${phone.phoneCode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _PhonesPageState._mutedColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_outlined),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricBlock(
                      label: 'Modal',
                      value: formatRupiah(phone.purchasePrice),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricBlock(label: priceLabel, value: priceValue),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MetricBlock(
                label: resultLabel,
                value: result == null ? '-' : formatRupiah(result.abs()),
                valueColor: result == null || result >= 0
                    ? _PhonesPageState._successColor
                    : _PhonesPageState._dangerColor,
              ),
              const SizedBox(height: 10),
              Text(
                formatShortDateTime(
                  phone.isSold ? phone.historyDate : phone.purchaseDate,
                ),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _PhonesPageState._mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    this.valueColor = _PhonesPageState._textColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _PhonesPageState._backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _PhonesPageState._mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: valueColor, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _PhonesPageState._mutedColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _PhonesPageState._dangerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _PhonesPageState._dangerColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
