import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../data/service_repository.dart';
import 'service_detail_page.dart';
import 'service_form_page.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF16A34A);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  final _repository = const ServiceRepository();

  List<ServiceJob> _services = [];
  String? _error;
  bool _isLoading = true;
  bool _showCompleted = false;

  List<ServiceJob> get _filteredServices {
    return _services.where((service) {
      return _showCompleted ? !service.isActive : service.isActive;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final services = await _repository.fetchServices();
      if (!mounted) {
        return;
      }
      setState(() {
        _services = services;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat servis: $error');
    }
  }

  Future<void> _refreshServices() async {
    try {
      final services = await _repository.fetchServices();
      if (!mounted) {
        return;
      }
      setState(() {
        _services = services;
        _error = null;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat servis: $error');
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
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => const ServiceFormPage()),
    );
    if (created == true) {
      await _loadServices();
    }
  }

  Future<void> _openDetail(ServiceJob service) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ServiceDetailPage(serviceId: service.id),
      ),
    );
    await _refreshServices();
  }

  @override
  Widget build(BuildContext context) {
    final filteredServices = _filteredServices;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Servis HP'),
        centerTitle: false,
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadServices,
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'Refresh servis',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_outlined),
        label: const Text('Tambah'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshServices,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.handyman_outlined),
                    label: Text('Aktif'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('Selesai'),
                  ),
                ],
                selected: {_showCompleted},
                showSelectedIcon: false,
                onSelectionChanged: (selected) {
                  setState(() {
                    _showCompleted = selected.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorState(message: _error!, onRetry: _loadServices)
              else if (filteredServices.isEmpty)
                _EmptyState(
                  message: _showCompleted
                      ? 'Belum ada servis selesai'
                      : 'Belum ada servis aktif',
                )
              else
                ...filteredServices.map(
                  (service) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ServiceCard(
                      service: service,
                      onTap: () => _openDetail(service),
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

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onTap});

  final ServiceJob service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                      color: _ServicesPageState._primaryColor.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.build_outlined,
                      color: _ServicesPageState._primaryColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.deviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: _ServicesPageState._textColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          service.serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _ServicesPageState._mutedColor,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(label: service.status.label),
                  _StatusChip(label: service.paymentStatus.label),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricBlock(
                      label: 'Total',
                      value: formatRupiah(service.invoiceTotal),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricBlock(
                      label: 'Sisa',
                      value: formatRupiah(service.remainingPayment),
                      valueColor: service.remainingPayment == 0
                          ? _ServicesPageState._successColor
                          : _ServicesPageState._dangerColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                formatShortDateTime(service.receivedAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _ServicesPageState._mutedColor,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _ServicesPageState._primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _ServicesPageState._primaryColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    this.valueColor = _ServicesPageState._textColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ServicesPageState._backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _ServicesPageState._mutedColor,
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
            color: _ServicesPageState._mutedColor,
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
        color: _ServicesPageState._dangerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _ServicesPageState._dangerColor,
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
