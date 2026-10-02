import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../data/phone_repository.dart';
import 'phone_form_page.dart';

class PhoneDetailPage extends StatefulWidget {
  const PhoneDetailPage({super.key, required this.phoneId});

  final String phoneId;

  @override
  State<PhoneDetailPage> createState() => _PhoneDetailPageState();
}

class _PhoneDetailPageState extends State<PhoneDetailPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _successColor = Color(0xFF16A34A);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  final _repository = const PhoneRepository();

  PhoneStockItem? _phone;
  String? _error;
  bool _isLoading = true;
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final phone = await _repository.fetchPhone(widget.phoneId);
      if (!mounted) {
        return;
      }
      setState(() {
        _phone = phone;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat detail HP: $error');
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

  Future<void> _openEdit(PhoneStockItem phone) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => PhoneFormPage(phone: phone),
      ),
    );
    if (changed == true) {
      await _loadPhone();
    }
  }

  Future<void> _openSellSheet(PhoneStockItem phone) async {
    final result = await showModalBottomSheet<_SellPhoneInput>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SellPhoneSheet(phone: phone),
    );
    if (result == null || _isMutating) {
      return;
    }
    setState(() {
      _isMutating = true;
    });
    try {
      final sold = await _repository.sellPhone(
        id: phone.id,
        sellingPrice: result.sellingPrice,
        buyerName: result.buyerName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _phone = sold;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('HP berhasil dijual')));
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Gagal menjual HP: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phone;
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Detail HP'),
        centerTitle: false,
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadPhone,
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'Refresh detail',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPhone,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (_isLoading)
                const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorState(message: _error!, onRetry: _loadPhone)
              else if (phone == null)
                const _EmptyState(message: 'Data HP tidak ditemukan')
              else ...[
                _PhoneInfoCard(phone: phone),
                const SizedBox(height: 16),
                if (!phone.isSold)
                  _ActionCard(
                    isMutating: _isMutating,
                    onEdit: () => _openEdit(phone),
                    onSell: () => _openSellSheet(phone),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneInfoCard extends StatelessWidget {
  const _PhoneInfoCard({required this.phone});

  final PhoneStockItem phone;

  @override
  Widget build(BuildContext context) {
    final result = phone.isSold ? phone.actualProfit : phone.potentialProfit;
    final resultLabel = phone.isSold
        ? (phone.actualProfit >= 0 ? 'Laba' : 'Rugi')
        : result == null
        ? 'Potensi'
        : result >= 0
        ? 'Potensi Laba'
        : 'Potensi Rugi';
    return _SectionCard(
      title: phone.isSold ? 'Transaksi HP' : 'Stok HP',
      child: Column(
        children: [
          _InfoRow(label: 'Merk & Model HP', value: phone.deviceName),
          const SizedBox(height: 12),
          _InfoRow(label: 'IMEI', value: phone.phoneCode),
          if (phone.condition.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow(label: 'Kondisi', value: phone.condition),
          ],
          if (phone.sellerName.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow(label: 'Penjual', value: phone.sellerName),
          ],
          if (phone.buyerName.isNotEmpty && phone.isSold) ...[
            const SizedBox(height: 12),
            _InfoRow(label: 'Pembeli', value: phone.buyerName),
          ],
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Tanggal Masuk',
            value: formatLongDateTime(phone.purchaseDate),
          ),
          if (phone.isSold && phone.saleDate != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Tanggal Terjual',
              value: formatLongDateTime(phone.saleDate!),
            ),
          ],
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Harga Beli',
            value: formatRupiah(phone.purchasePrice),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: phone.isSold ? 'Harga Jual Final' : 'Harga Jual Target',
            value: phone.targetOrSellingPrice == null
                ? '-'
                : formatRupiah(phone.targetOrSellingPrice!),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: resultLabel,
            value: result == null ? '-' : formatRupiah(result.abs()),
            valueColor: result == null || result >= 0
                ? _PhoneDetailPageState._successColor
                : _PhoneDetailPageState._dangerColor,
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Status', value: phone.status.label),
          if (phone.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow(label: 'Catatan', value: phone.notes),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.isMutating,
    required this.onEdit,
    required this.onSell,
  });

  final bool isMutating;
  final VoidCallback onEdit;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Aksi',
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isMutating ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isMutating ? null : onSell,
              icon: const Icon(Icons.sell_outlined),
              label: const Text('Jual HP'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SellPhoneSheet extends StatefulWidget {
  const _SellPhoneSheet({required this.phone});

  final PhoneStockItem phone;

  @override
  State<_SellPhoneSheet> createState() => _SellPhoneSheetState();
}

class _SellPhoneSheetState extends State<_SellPhoneSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  final _buyerController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.phone.targetOrSellingPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _buyerController.dispose();
    super.dispose();
  }

  int get _sellingPrice => parseIntValue(_priceController.text);
  int get _profit => _sellingPrice - widget.phone.purchasePrice;

  void _submit() {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    Navigator.of(context).pop(
      _SellPhoneInput(
        sellingPrice: _sellingPrice,
        buyerName: _buyerController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jual HP',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(widget.phone.deviceName),
            const SizedBox(height: 8),
            Text('Modal: ${formatRupiah(widget.phone.purchasePrice)}'),
            if (widget.phone.targetOrSellingPrice != null)
              Text(
                'Target: ${formatRupiah(widget.phone.targetOrSellingPrice!)}',
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Harga Jual Final',
                prefixText: 'Rp ',
              ),
              validator: (value) {
                if (parseIntValue(value) <= 0) {
                  return 'Harga jual wajib valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _buyerController,
              decoration: const InputDecoration(
                labelText: 'Nama Pembeli',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _profit >= 0
                  ? 'Laba: ${formatRupiah(_profit)}'
                  : 'Rugi: ${formatRupiah(_profit.abs())}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _profit >= 0
                    ? _PhoneDetailPageState._successColor
                    : _PhoneDetailPageState._dangerColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Konfirmasi Penjualan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellPhoneInput {
  const _SellPhoneInput({required this.sellingPrice, required this.buyerName});

  final int sellingPrice;
  final String buyerName;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = _PhoneDetailPageState._textColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _PhoneDetailPageState._mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: valueColor, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _PhoneDetailPageState._textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
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
            color: _PhoneDetailPageState._mutedColor,
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
        color: _PhoneDetailPageState._dangerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _PhoneDetailPageState._dangerColor,
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
