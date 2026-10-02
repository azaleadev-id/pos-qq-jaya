import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../data/phone_repository.dart';

class PhoneDirectSalePage extends StatefulWidget {
  const PhoneDirectSalePage({super.key});

  @override
  State<PhoneDirectSalePage> createState() => _PhoneDirectSalePageState();
}

class _PhoneDirectSalePageState extends State<PhoneDirectSalePage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF16A34A);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  final _repository = const PhoneRepository();
  final _formKey = GlobalKey<FormState>();
  final _deviceController = TextEditingController();
  final _imeiController = TextEditingController();
  final _conditionController = TextEditingController();
  final _purchaseController = TextEditingController();
  final _sellingController = TextEditingController();
  final _buyerController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSaving = false;

  int get _purchasePrice => parseIntValue(_purchaseController.text);
  int get _sellingPrice => parseIntValue(_sellingController.text);
  int get _profit => _sellingPrice - _purchasePrice;

  @override
  void initState() {
    super.initState();
    _conditionController.text = 'Baru';
  }

  @override
  void dispose() {
    _deviceController.dispose();
    _imeiController.dispose();
    _conditionController.dispose();
    _purchaseController.dispose();
    _sellingController.dispose();
    _buyerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await _repository.createDirectSale(
        imei: _imeiController.text.trim(),
        deviceName: _deviceController.text.trim(),
        purchasePrice: _purchasePrice,
        sellingPrice: _sellingPrice,
        condition: _conditionController.text.trim(),
        buyerName: _buyerController.text.trim(),
        notes: _notesController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Penjualan HP langsung tersimpan')),
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Gagal menyimpan penjualan HP: $error');
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
    final profitColor = _profit >= 0 ? _successColor : _dangerColor;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Jual HP'),
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
                  title: 'Data HP',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _deviceController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Merk & Model HP',
                          prefixIcon: Icon(Icons.phone_android_outlined),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _imeiController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'IMEI',
                          prefixIcon: Icon(Icons.qr_code_2_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _conditionController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Kondisi',
                          prefixIcon: Icon(Icons.fact_check_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Transaksi',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _purchaseController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Modal / Harga Beli',
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.shopping_bag_outlined),
                        ),
                        validator: _positiveNumber,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _sellingController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Harga Jual',
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                        validator: _positiveNumber,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _buyerController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Pelanggan',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Catatan',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SummaryLine(
                        label: _profit >= 0 ? 'Keuntungan' : 'Kerugian',
                        value: formatRupiah(_profit.abs()),
                        valueColor: profitColor,
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
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Penjualan',
                    ),
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
      return 'Nilai harus lebih dari 0';
    }
    return null;
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
              color: _PhoneDirectSalePageState._textColor,
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

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _PhoneDirectSalePageState._backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _PhoneDirectSalePageState._mutedColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: valueColor, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
