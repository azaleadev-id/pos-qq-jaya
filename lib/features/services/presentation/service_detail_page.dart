import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../data/service_repository.dart';

class ServiceDetailPage extends StatefulWidget {
  const ServiceDetailPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF16A34A);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  final _repository = const ServiceRepository();

  ServiceDetail? _detail;
  String? _error;
  bool _isLoading = true;
  bool _isMutating = false;

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
      final detail = await _repository.fetchServiceDetail(widget.serviceId);
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
      _setError('Gagal memuat detail servis: $error');
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

  Future<void> _changeStatus(ServiceStatus status) async {
    if (_detail == null || _isMutating) {
      return;
    }
    setState(() {
      _isMutating = true;
    });
    try {
      final detail = await _repository.updateStatus(
        id: widget.serviceId,
        status: status,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
      });
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Gagal mengubah status: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Future<void> _openPaymentSheet(ServiceJob service) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _PaymentAmountSheet(remainingPayment: service.remainingPayment),
    );

    if (amount == null) {
      return;
    }
    if (amount <= 0) {
      _showError('Nominal pembayaran harus lebih dari nol.');
      return;
    }
    if (amount > service.remainingPayment) {
      _showError('Pembayaran melebihi sisa tagihan.');
      return;
    }

    setState(() {
      _isMutating = true;
    });
    try {
      final detail = await _repository.addPayment(
        id: widget.serviceId,
        amount: amount,
        settlement: amount == service.remainingPayment,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
      });
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Gagal menyimpan pembayaran: $error');
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
    final detail = _detail;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Detail Servis'),
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
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorState(message: _error!, onRetry: _loadDetail)
              else if (detail == null)
                const _EmptyState(message: 'Data servis tidak ditemukan')
              else ...[
                _ServiceInfoCard(service: detail.service),
                const SizedBox(height: 16),
                _StatusCard(
                  service: detail.service,
                  isMutating: _isMutating,
                  onChangeStatus: _changeStatus,
                ),
                const SizedBox(height: 16),
                _PaymentCard(
                  detail: detail,
                  isMutating: _isMutating,
                  onAddPayment: () => _openPaymentSheet(detail.service),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceInfoCard extends StatelessWidget {
  const _ServiceInfoCard({required this.service});

  final ServiceJob service;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Servis',
      child: Column(
        children: [
          _InfoRow(label: 'Merk & Model HP', value: service.deviceName),
          const SizedBox(height: 12),
          _InfoRow(label: 'Pekerjaan', value: service.serviceName),
          if (service.customerName.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow(label: 'Pelanggan', value: service.customerName),
          ],
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Tanggal Masuk',
            value: formatLongDateTime(service.receivedAt),
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Garansi', value: service.warrantyLabel),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.service,
    required this.isMutating,
    required this.onChangeStatus,
  });

  final ServiceJob service;
  final bool isMutating;
  final ValueChanged<ServiceStatus> onChangeStatus;

  ServiceStatus? get _nextStatus {
    return switch (service.status) {
      ServiceStatus.incoming => ServiceStatus.waiting,
      ServiceStatus.waiting => ServiceStatus.working,
      ServiceStatus.working => ServiceStatus.completed,
      ServiceStatus.completed => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextStatus;
    final otherStatuses = ServiceStatus.values
        .where((status) => status != service.status)
        .toList();
    return _SectionCard(
      title: 'Status Servis',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusPill(label: service.status.label),
          if (next != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isMutating ? null : () => onChangeStatus(next),
                icon: const Icon(Icons.arrow_forward_outlined),
                label: Text('Ubah ke ${next.label}'),
              ),
            ),
          ],
          if (otherStatuses.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<ServiceStatus>(
              initialValue: service.status,
              decoration: const InputDecoration(
                labelText: 'Koreksi status',
                prefixIcon: Icon(Icons.edit_note_outlined),
              ),
              items: ServiceStatus.values
                  .map(
                    (status) => DropdownMenuItem<ServiceStatus>(
                      value: status,
                      child: Text(status.label),
                    ),
                  )
                  .toList(),
              onChanged: isMutating
                  ? null
                  : (status) {
                      if (status != null && status != service.status) {
                        onChangeStatus(status);
                      }
                    },
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.detail,
    required this.isMutating,
    required this.onAddPayment,
  });

  final ServiceDetail detail;
  final bool isMutating;
  final VoidCallback onAddPayment;

  @override
  Widget build(BuildContext context) {
    final service = detail.service;
    return _SectionCard(
      title: 'Pembayaran',
      child: Column(
        children: [
          _InfoRow(
            label: 'Biaya Servis',
            value: formatRupiah(service.servicePrice),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Ongkir Sparepart',
            value: formatRupiah(service.deliveryCost),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Total Tagihan',
            value: formatRupiah(service.invoiceTotal),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Total Dibayar',
            value: formatRupiah(service.totalPaid),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Sisa Pembayaran',
            value: formatRupiah(service.remainingPayment),
            valueColor: service.remainingPayment == 0
                ? _ServiceDetailPageState._successColor
                : _ServiceDetailPageState._dangerColor,
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Status', value: service.paymentStatus.label),
          if (service.remainingPayment > 0) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isMutating ? null : onAddPayment,
                icon: const Icon(Icons.add_card_outlined),
                label: const Text('Tambah Pembayaran'),
              ),
            ),
          ],
          const Divider(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Riwayat Pembayaran',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _ServiceDetailPageState._textColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (detail.payments.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Belum ada pembayaran.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _ServiceDetailPageState._mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ...detail.payments.map(
              (payment) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PaymentTile(payment: payment),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentAmountSheet extends StatefulWidget {
  const _PaymentAmountSheet({required this.remainingPayment});

  final int remainingPayment;

  @override
  State<_PaymentAmountSheet> createState() => _PaymentAmountSheetState();
}

class _PaymentAmountSheetState extends State<_PaymentAmountSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.remainingPayment.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isSubmitting) {
      return;
    }
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    Navigator.of(context).pop(parseIntValue(_controller.text));
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
              'Tambah Pembayaran',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text('Sisa: ${formatRupiah(widget.remainingPayment)}'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Nominal pembayaran',
                prefixText: 'Rp ',
              ),
              validator: (value) {
                final amount = parseIntValue(value);
                if (amount <= 0) {
                  return 'Nominal pembayaran harus lebih dari nol';
                }
                if (amount > widget.remainingPayment) {
                  return 'Pembayaran melebihi sisa tagihan';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
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
                    : const Text('Simpan Pembayaran'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final ServicePayment payment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment.typeLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _ServiceDetailPageState._textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                formatShortDateTime(payment.paidAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _ServiceDetailPageState._mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Text(
          formatRupiah(payment.amount),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _ServiceDetailPageState._textColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _ServiceDetailPageState._primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: _ServiceDetailPageState._primaryColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = _ServiceDetailPageState._textColor,
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
              color: _ServiceDetailPageState._mutedColor,
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
              color: _ServiceDetailPageState._textColor,
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
            color: _ServiceDetailPageState._mutedColor,
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
        color: _ServiceDetailPageState._dangerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _ServiceDetailPageState._dangerColor,
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
