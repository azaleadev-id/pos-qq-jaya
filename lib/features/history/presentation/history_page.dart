import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../expenses/presentation/expenses_page.dart';
import '../data/history_repository.dart';
import 'sale_detail_page.dart';
import '../../phones/presentation/phone_detail_page.dart';
import '../../services/presentation/service_detail_page.dart';

enum HistoryDateFilter {
  today('Hari Ini'),
  thisWeek('Minggu Ini'),
  thisMonth('Bulan Ini'),
  all('Semua');

  const HistoryDateFilter(this.label);

  final String label;
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF16A34A);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  final _repository = const HistoryRepository();
  final _searchController = TextEditingController();

  List<HistoryItem> _items = [];
  String? _error;
  bool _isLoading = true;
  HistoryCategory? _selectedCategory;
  HistoryDateFilter _dateFilter = HistoryDateFilter.all;

  List<HistoryItem> get _filteredItems {
    final query = _searchController.text;
    return _items.where((item) {
      final selectedCategory = _selectedCategory;
      final matchesCategory =
          selectedCategory == null || item.category == selectedCategory;
      return matchesCategory &&
          item.matchesQuery(query) &&
          _matchesDateFilter(item);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _repository.fetchHistoryItems();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat riwayat: $error');
    }
  }

  Future<void> _refreshSales() async {
    try {
      final items = await _repository.fetchHistoryItems();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _error = null;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat riwayat: $error');
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

  bool _matchesDateFilter(HistoryItem item) {
    if (_dateFilter == HistoryDateFilter.all) {
      return true;
    }

    final now = DateTime.now();
    final date = item.date.toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);

    return switch (_dateFilter) {
      HistoryDateFilter.today =>
        !date.isBefore(todayStart) &&
            date.isBefore(todayStart.add(const Duration(days: 1))),
      HistoryDateFilter.thisWeek => !date.isBefore(
        todayStart.subtract(Duration(days: now.weekday - 1)),
      ),
      HistoryDateFilter.thisMonth => !date.isBefore(
        DateTime(now.year, now.month),
      ),
      HistoryDateFilter.all => true,
    };
  }

  void _openDetail(HistoryItem item) {
    if (item.type == HistoryType.service) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ServiceDetailPage(serviceId: item.id),
        ),
      );
      return;
    }

    if (item.type == HistoryType.phone) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => PhoneDetailPage(phoneId: item.id),
        ),
      );
      return;
    }

    if (item.type == HistoryType.expense) {
      _showExpenseDetail(item);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SaleDetailPage(saleId: item.id),
      ),
    );
  }

  void _showExpenseDetail(HistoryItem item) {
    final expense = item.expense;
    if (expense == null) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Pengeluaran',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _textColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _DetailLine(
                  label: 'Tanggal',
                  value: formatLongDateTime(expense.date),
                ),
                _DetailLine(label: 'Kategori', value: expense.category),
                _DetailLine(label: 'Keterangan', value: expense.name),
                _DetailLine(
                  label: 'Nominal',
                  value: '-${formatRupiah(expense.amount)}',
                  valueColor: _dangerColor,
                ),
                if (expense.notes.isNotEmpty)
                  _DetailLine(label: 'Catatan', value: expense.notes),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const ExpensesPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: const Text('Buka Modul Pengeluaran'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Riwayat'),
        centerTitle: false,
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSales,
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'Refresh riwayat',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshSales,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _HistoryControls(
                selectedCategory: _selectedCategory,
                onCategoryChanged: (index) {
                  setState(() {
                    _selectedCategory = index;
                  });
                },
                searchController: _searchController,
                onSearchChanged: (_) => setState(() {}),
                selectedDateFilter: _dateFilter,
                onDateFilterChanged: (filter) {
                  setState(() {
                    _dateFilter = filter;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const _LoadingState()
              else if (_error != null)
                _ErrorState(message: _error!, onRetry: _loadSales)
              else if (filteredItems.isEmpty)
                const _EmptyState(message: 'Belum ada transaksi')
              else
                ...filteredItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistoryCard(
                      item: item,
                      onTap: () => _openDetail(item),
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

class _HistoryControls extends StatelessWidget {
  const _HistoryControls({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedDateFilter,
    required this.onDateFilterChanged,
  });

  final HistoryCategory? selectedCategory;
  final ValueChanged<HistoryCategory?> onCategoryChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final HistoryDateFilter selectedDateFilter;
  final ValueChanged<HistoryDateFilter> onDateFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Semua'),
                    selected: selectedCategory == null,
                    onSelected: (_) => onCategoryChanged(null),
                  ),
                ),
                ...HistoryCategory.values.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category.label),
                      selected: selectedCategory == category,
                      onSelected: (_) => onCategoryChanged(category),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'Cari transaksi',
            prefixIcon: Icon(Icons.search_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HistoryDateFilter.values.map((filter) {
              return ChoiceChip(
                label: Text(filter.label),
                selected: filter == selectedDateFilter,
                onSelected: (_) => onDateFilterChanged(filter),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.onTap});

  final HistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                      color: _HistoryPageState._primaryColor.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconFor(item.category),
                      color: _HistoryPageState._primaryColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayType,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: _HistoryPageState._textColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatShortDateTime(item.date),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _HistoryPageState._mutedColor,
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
              if (item.reference.isNotEmpty)
                Text(
                  '#${item.reference}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _HistoryPageState._primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (item.title.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _HistoryPageState._textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricBlock(
                      label: switch (item.type) {
                        HistoryType.sale => item.category.label,
                        HistoryType.service => 'Total Tagihan',
                        HistoryType.phone =>
                          item.title.startsWith('Beli ')
                              ? 'Modal Beli'
                              : 'Harga Jual',
                        HistoryType.expense => item.subtitle,
                      },
                      value: item.amountText,
                      valueColor: item.type == HistoryType.expense
                          ? _HistoryPageState._dangerColor
                          : _HistoryPageState._textColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricBlock(
                      label: item.subtitle,
                      value: item.status,
                      valueColor: item.type == HistoryType.sale
                          ? _HistoryPageState._successColor
                          : item.type == HistoryType.expense
                          ? _HistoryPageState._dangerColor
                          : _HistoryPageState._textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(HistoryCategory category) {
    return switch (category) {
      HistoryCategory.product => Icons.inventory_2_outlined,
      HistoryCategory.service => Icons.build_outlined,
      HistoryCategory.phone => Icons.phone_android_outlined,
      HistoryCategory.voucher => Icons.confirmation_number_outlined,
      HistoryCategory.pulsa => Icons.sim_card_outlined,
      HistoryCategory.dataPackage => Icons.data_usage_outlined,
      HistoryCategory.expense => Icons.payments_outlined,
    };
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.valueColor = _HistoryPageState._textColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _HistoryPageState._mutedColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: valueColor, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    this.valueColor = _HistoryPageState._textColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _HistoryPageState._backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _HistoryPageState._mutedColor,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: Center(child: CircularProgressIndicator()),
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
            color: _HistoryPageState._mutedColor,
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
        color: _HistoryPageState._dangerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _HistoryPageState._dangerColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _HistoryPageState._dangerColor,
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
