import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../data/service_repository.dart';

class ServiceFormPage extends StatefulWidget {
  const ServiceFormPage({super.key});

  @override
  State<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends State<ServiceFormPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  final _repository = const ServiceRepository();
  final _formKey = GlobalKey<FormState>();
  final _deviceController = TextEditingController();
  final _workController = TextEditingController();
  final _priceController = TextEditingController();
  final _deliveryController = TextEditingController(text: '0');
  final _customerController = TextEditingController();
  final _downPaymentController = TextEditingController();

  List<ServicePreset> _presets = [];
  ServiceInitialPayment _initialPayment = ServiceInitialPayment.unpaid;
  bool _hasWarranty = false;
  bool _isSaving = false;

  int get _servicePrice => parseIntValue(_priceController.text);
  int get _deliveryCost => parseIntValue(_deliveryController.text);
  int get _downPayment => parseIntValue(_downPaymentController.text);
  int get _invoiceTotal => _servicePrice + _deliveryCost;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  @override
  void dispose() {
    _deviceController.dispose();
    _workController.dispose();
    _priceController.dispose();
    _deliveryController.dispose();
    _customerController.dispose();
    _downPaymentController.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    final query = '${_deviceController.text} ${_workController.text}'.trim();
    try {
      final presets = await _repository.fetchPresets(search: query);
      if (!mounted) {
        return;
      }
      setState(() {
        _presets = presets;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _presets = [];
      });
    }
  }

  ServicePreset? get _matchingPreset {
    final device = _deviceController.text.trim().toLowerCase();
    final work = _workController.text.trim().toLowerCase();
    if (device.isEmpty || work.isEmpty) {
      return null;
    }
    for (final preset in _presets) {
      if (preset.deviceName.toLowerCase() == device &&
          preset.serviceName.toLowerCase() == work) {
        return preset;
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.createService(
        deviceName: _deviceController.text.trim(),
        serviceName: _workController.text.trim(),
        servicePrice: _servicePrice,
        deliveryCost: _deliveryCost,
        customerName: _customerController.text.trim(),
        hasWarranty: _hasWarranty,
        initialPayment: _initialPayment,
        downPayment: _downPayment,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Servis berhasil disimpan')));
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Gagal menyimpan servis: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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
    final preset = _matchingPreset;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Servis HP'),
        centerTitle: false,
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _SectionCard(
                  title: 'Data Servis',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _deviceController,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _loadPresets(),
                        decoration: const InputDecoration(
                          labelText: 'Merk & Model HP',
                          prefixIcon: Icon(Icons.phone_android_outlined),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _workController,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _loadPresets(),
                        decoration: const InputDecoration(
                          labelText: 'Pekerjaan',
                          prefixIcon: Icon(Icons.build_outlined),
                        ),
                        validator: _required,
                      ),
                      if (preset != null) ...[
                        const SizedBox(height: 10),
                        _PresetSuggestion(
                          preset: preset,
                          onUse: () {
                            setState(() {
                              _priceController.text = preset.servicePrice
                                  .toString();
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Biaya Servis',
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: _positiveNumber,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _deliveryController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Ongkir Sparepart',
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.local_shipping_outlined),
                        ),
                        validator: _zeroOrPositiveNumber,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _customerController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Nama Pelanggan',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        value: _hasWarranty,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Garansi'),
                        subtitle: Text(
                          _hasWarranty ? '1 x 24 Jam' : 'Tidak Ada',
                        ),
                        secondary: const Icon(Icons.verified_user_outlined),
                        onChanged: (value) {
                          setState(() {
                            _hasWarranty = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Pembayaran Awal',
                  child: Column(
                    children: [
                      SegmentedButton<ServiceInitialPayment>(
                        segments: const [
                          ButtonSegment(
                            value: ServiceInitialPayment.unpaid,
                            label: Text('Belum'),
                          ),
                          ButtonSegment(
                            value: ServiceInitialPayment.downPayment,
                            label: Text('DP'),
                          ),
                          ButtonSegment(
                            value: ServiceInitialPayment.paid,
                            label: Text('Lunas'),
                          ),
                        ],
                        selected: {_initialPayment},
                        showSelectedIcon: false,
                        onSelectionChanged: (selected) {
                          setState(() {
                            _initialPayment = selected.first;
                          });
                        },
                      ),
                      if (_initialPayment ==
                          ServiceInitialPayment.downPayment) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _downPaymentController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Nominal DP',
                            prefixText: 'Rp ',
                            prefixIcon: Icon(Icons.savings_outlined),
                          ),
                          validator: (value) {
                            final amount = parseIntValue(value);
                            if (amount <= 0) {
                              return 'DP harus valid';
                            }
                            if (amount > _invoiceTotal) {
                              return 'DP melebihi total tagihan';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 14),
                      _SummaryRow(
                        label: 'Total Tagihan',
                        value: formatRupiah(_invoiceTotal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Servis'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Wajib diisi';
    }
    return null;
  }

  String? _positiveNumber(String? value) {
    if (parseIntValue(value) <= 0) {
      return 'Nilai harus valid';
    }
    return null;
  }

  String? _zeroOrPositiveNumber(String? value) {
    if (parseIntValue(value) < 0) {
      return 'Nilai tidak valid';
    }
    return null;
  }
}

class _PresetSuggestion extends StatelessWidget {
  const _PresetSuggestion({required this.preset, required this.onUse});

  final ServicePreset preset;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ServiceFormPageState._primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Harga sebelumnya ${formatRupiah(preset.servicePrice)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _ServiceFormPageState._textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(onPressed: onUse, child: const Text('Pakai')),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _ServiceFormPageState._mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _ServiceFormPageState._textColor,
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
              color: _ServiceFormPageState._textColor,
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
