import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../data/history_repository.dart';

class SaleDetailPage extends StatefulWidget {
  const SaleDetailPage({super.key, required this.saleId});

  final String saleId;

  @override
  State<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends State<SaleDetailPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF16A34A);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  final _repository = const HistoryRepository();

  SaleDetail? _detail;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await _repository.fetchSaleDetail(widget.saleId);
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat detail penjualan: $error');
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

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Detail Penjualan'),
        centerTitle: false,
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadDetail,
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'Refresh detail',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDetail,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (_isLoading)
                const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorState(message: _error!, onRetry: _loadDetail)
              else if (detail == null)
                const _EmptyState(message: 'Transaksi tidak ditemukan')
              else ...[
                _HeaderCard(detail: detail),
                const SizedBox(height: 16),
                _ItemsCard(items: detail.items),
                const SizedBox(height: 16),
                _TotalsCard(summary: detail.summary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});

  final SaleDetail detail;

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;
    return _SectionCard(
      title: 'Transaksi',
      child: Column(
        children: [
          _InfoRow(label: 'Tanggal', value: formatLongDateTime(summary.soldAt)),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'ID Transaksi',
            value: summary.transactionNumber.isEmpty
                ? summary.id
                : '#${summary.transactionNumber}',
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Jumlah Item', value: '${detail.items.length} item'),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items});

  final List<SaleItemSnapshot> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Barang',
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              _SaleItemTile(item: item),
              if (index != items.length - 1) const Divider(height: 20),
            ],
          );
        }),
      ),
    );
  }
}

class _SaleItemTile extends StatelessWidget {
  const _SaleItemTile({required this.item});

  final SaleItemSnapshot item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _SaleDetailPageState._primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.productId == null
                ? Icons.edit_note_outlined
                : Icons.inventory_2_outlined,
            color: _SaleDetailPageState._primaryColor,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _SaleDetailPageState._textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.quantity} x ${formatRupiah(item.unitPrice)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _SaleDetailPageState._mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.productCategory.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  item.productCategory,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _SaleDetailPageState._primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 3),
              Text(
                'Modal ${formatRupiah(item.unitCost)} - Untung ${formatRupiah(item.lineProfit)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _SaleDetailPageState._mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          formatRupiah(item.lineTotal),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _SaleDetailPageState._textColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.summary});

  final SaleSummary summary;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Ringkasan',
      child: Column(
        children: [
          _InfoRow(
            label: 'Total Modal',
            value: formatRupiah(summary.totalCost),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Total Penjualan',
            value: formatRupiah(summary.total),
          ),
          const Divider(height: 28),
          _InfoRow(
            label: 'Keuntungan',
            value: formatRupiah(summary.profit),
            valueColor: _SaleDetailPageState._successColor,
            isEmphasized: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = _SaleDetailPageState._textColor,
    this.isEmphasized = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _SaleDetailPageState._mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style:
                (isEmphasized
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.bodyMedium)
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
              color: _SaleDetailPageState._textColor,
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
            color: _SaleDetailPageState._mutedColor,
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
        color: _SaleDetailPageState._dangerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _SaleDetailPageState._dangerColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _SaleDetailPageState._dangerColor,
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
