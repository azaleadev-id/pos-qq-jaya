import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../data/recap_repository.dart';

enum RecapPeriodFilter {
  today('Hari Ini'),
  thisWeek('Minggu Ini'),
  thisMonth('Bulan Ini'),
  all('Semua');

  const RecapPeriodFilter(this.label);

  final String label;
}

class RecapsPage extends StatefulWidget {
  const RecapsPage({super.key});

  @override
  State<RecapsPage> createState() => _RecapsPageState();
}

class _RecapsPageState extends State<RecapsPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF16A34A);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  final _repository = const RecapRepository();

  RecapSnapshot? _snapshot;
  String? _error;
  bool _isLoading = true;
  RecapPeriodFilter _periodFilter = RecapPeriodFilter.today;

  @override
  void initState() {
    super.initState();
    _loadRecap();
  }

  Future<void> _loadRecap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final range = _rangeFor(_periodFilter);
      final snapshot = await _repository.fetchRecap(
        from: range.$1,
        to: range.$2,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat rekap: $error');
    }
  }

  Future<void> _refreshRecap() async {
    try {
      final range = _rangeFor(_periodFilter);
      final snapshot = await _repository.fetchRecap(
        from: range.$1,
        to: range.$2,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat rekap: $error');
    }
  }

  void _setError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _error = message;
      _isLoading = false;
    });
  }

  (DateTime?, DateTime?) _rangeFor(RecapPeriodFilter filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (filter) {
      RecapPeriodFilter.today => (today, today),
      RecapPeriodFilter.thisWeek => (
        today.subtract(Duration(days: now.weekday - 1)),
        today,
      ),
      RecapPeriodFilter.thisMonth => (DateTime(now.year, now.month), today),
      RecapPeriodFilter.all => (null, null),
    };
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Rekap'),
        centerTitle: false,
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadRecap,
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'Refresh rekap',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshRecap,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _PeriodChips(
                selected: _periodFilter,
                onChanged: (filter) {
                  setState(() {
                    _periodFilter = filter;
                  });
                  _loadRecap();
                },
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const _LoadingState()
              else if (_error != null)
                _ErrorState(message: _error!, onRetry: _loadRecap)
              else if (snapshot == null)
                const _EmptyState(message: 'Rekap belum tersedia')
              else ...[
                _SummaryGrid(summary: snapshot.summary),
                const SizedBox(height: 16),
                _BreakdownCard(breakdown: snapshot.breakdown),
                const SizedBox(height: 16),
                _ProductDetailCard(products: snapshot.products),
                const SizedBox(height: 16),
                _ExpenseCategoryCard(items: snapshot.expenseCategories),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.selected, required this.onChanged});

  final RecapPeriodFilter selected;
  final ValueChanged<RecapPeriodFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: RecapPeriodFilter.values.map((filter) {
          return ChoiceChip(
            label: Text(filter.label),
            selected: selected == filter,
            onSelected: (_) => onChanged(filter),
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final RecapSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryItem('Omzet', formatRupiah(summary.omzet), Icons.trending_up),
      _SummaryItem(
        'Keuntungan',
        formatRupiah(summary.grossProfit),
        Icons.savings_outlined,
      ),
      _SummaryItem(
        'Pengeluaran',
        formatRupiah(summary.expenses),
        Icons.receipt_long_outlined,
        _RecapsPageState._dangerColor,
      ),
      _SummaryItem(
        'Laba Bersih',
        formatRupiah(summary.netProfit),
        Icons.account_balance_wallet_outlined,
        summary.netProfit >= 0
            ? _RecapsPageState._successColor
            : _RecapsPageState._dangerColor,
      ),
    ];
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.0,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: item.color ?? _RecapsPageState._primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _RecapsPageState._mutedColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.value,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: item.color ?? _RecapsPageState._textColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.breakdown});

  final RecapBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _BreakdownRow('Barang', breakdown.products, Icons.inventory_2_outlined),
      _BreakdownRow('Servis', breakdown.services, Icons.build_outlined),
      _BreakdownRow('HP', breakdown.phones, Icons.phone_android_outlined),
      _BreakdownRow(
        'Voucher',
        breakdown.vouchers,
        Icons.confirmation_number_outlined,
      ),
      _BreakdownRow('Pulsa', breakdown.pulsa, Icons.sim_card_outlined),
      _BreakdownRow(
        'Paket Data',
        breakdown.dataPackages,
        Icons.data_usage_outlined,
      ),
    ];
    return _SectionCard(
      title: 'Breakdown Kategori',
      child: Column(
        children: [
          ...List.generate(rows.length, (index) {
            final row = rows[index];
            return Column(
              children: [
                _SalesBreakdownTile(row: row),
                if (index != rows.length - 1) const Divider(height: 20),
              ],
            );
          }),
          const Divider(height: 24),
          _ExpenseBreakdownTile(expenses: breakdown.expenses),
        ],
      ),
    );
  }
}

class _SalesBreakdownTile extends StatelessWidget {
  const _SalesBreakdownTile({required this.row});

  final _BreakdownRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(row.icon, color: _RecapsPageState._primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _RecapsPageState._textColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${row.data.transactions} transaksi'
                '${row.data.quantity > 0 ? ' - ${row.data.quantity} unit' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _RecapsPageState._mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatRupiah(row.data.omzet),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _RecapsPageState._textColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Untung ${formatRupiah(row.data.profit)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: row.data.profit >= 0
                    ? _RecapsPageState._successColor
                    : _RecapsPageState._dangerColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExpenseBreakdownTile extends StatelessWidget {
  const _ExpenseBreakdownTile({required this.expenses});

  final RecapExpenseSummary expenses;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.payments_outlined,
          color: _RecapsPageState._dangerColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Pengeluaran',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _RecapsPageState._textColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '-${formatRupiah(expenses.amount)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _RecapsPageState._dangerColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProductDetailCard extends StatelessWidget {
  const _ProductDetailCard({required this.products});

  final List<RecapProductDetail> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _SectionCard(
        title: 'Detail Barang',
        child: _EmptyInline(message: 'Belum ada penjualan barang.'),
      );
    }
    return _SectionCard(
      title: 'Detail Barang',
      child: Column(
        children: List.generate(products.length, (index) {
          final product = products[index];
          return Column(
            children: [
              _SimpleAmountTile(
                title: product.name,
                subtitle: 'Terjual ${product.quantity}',
                amount: product.omzet,
                trailing: 'Untung ${formatRupiah(product.profit)}',
              ),
              if (index != products.length - 1) const Divider(height: 20),
            ],
          );
        }),
      ),
    );
  }
}

class _ExpenseCategoryCard extends StatelessWidget {
  const _ExpenseCategoryCard({required this.items});

  final List<RecapExpenseCategory> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _SectionCard(
        title: 'Pengeluaran per Kategori',
        child: _EmptyInline(message: 'Belum ada pengeluaran.'),
      );
    }
    return _SectionCard(
      title: 'Pengeluaran per Kategori',
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              _SimpleAmountTile(
                title: item.category,
                subtitle: '${item.transactions} transaksi',
                amount: item.amount,
                isExpense: true,
              ),
              if (index != items.length - 1) const Divider(height: 20),
            ],
          );
        }),
      ),
    );
  }
}

class _SimpleAmountTile extends StatelessWidget {
  const _SimpleAmountTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    this.trailing,
    this.isExpense = false,
  });

  final String title;
  final String subtitle;
  final int amount;
  final String? trailing;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final amountText = '${isExpense ? '-' : ''}${formatRupiah(amount)}';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _RecapsPageState._textColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                trailing == null ? subtitle : '$subtitle - $trailing',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _RecapsPageState._mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          amountText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isExpense
                ? _RecapsPageState._dangerColor
                : _RecapsPageState._textColor,
            fontWeight: FontWeight.w900,
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _RecapsPageState._textColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          child,
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
      child: Center(child: _EmptyInline(message: message)),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: _RecapsPageState._mutedColor,
        fontWeight: FontWeight.w700,
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
        color: _RecapsPageState._dangerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _RecapsPageState._dangerColor,
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

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.icon, [this.color]);

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
}

class _BreakdownRow {
  const _BreakdownRow(this.label, this.data, this.icon);

  final String label;
  final RecapSalesCategory data;
  final IconData icon;
}
