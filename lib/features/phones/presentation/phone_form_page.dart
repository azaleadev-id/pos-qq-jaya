import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../data/phone_repository.dart';

class PhoneFormPage extends StatefulWidget {
  const PhoneFormPage({super.key, this.phone});

  final PhoneStockItem? phone;

  @override
  State<PhoneFormPage> createState() => _PhoneFormPageState();
}

class _PhoneFormPageState extends State<PhoneFormPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _textColor = Color(0xFF111827);

  final _repository = const PhoneRepository();
  final _formKey = GlobalKey<FormState>();
  final _imeiController = TextEditingController();
  final _deviceController = TextEditingController();
  final _purchaseController = TextEditingController();
  final _targetController = TextEditingController();
  final _conditionController = TextEditingController();
  final _sellerController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  bool get _isEdit => widget.phone != null;

  @override
  void initState() {
    super.initState();
    final phone = widget.phone;
    if (phone != null) {
      _imeiController.text = phone.phoneCode;
      _deviceController.text = phone.deviceName;
      _purchaseController.text = phone.purchasePrice.toString();
      _targetController.text = phone.targetOrSellingPrice?.toString() ?? '';
      _conditionController.text = phone.condition;
      _sellerController.text = phone.sellerName;
      _notesController.text = phone.notes;
    }
  }

  @override
  void dispose() {
    _imeiController.dispose();
    _deviceController.dispose();
    _purchaseController.dispose();
    _targetController.dispose();
    _conditionController.dispose();
    _sellerController.dispose();
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
      final target = _targetController.text.trim().isEmpty
          ? null
          : parseIntValue(_targetController.text);
      if (_isEdit) {
        await _repository.updatePhone(
          id: widget.phone!.id,
          imei: _imeiController.text.trim(),
          deviceName: _deviceController.text.trim(),
          purchasePrice: parseIntValue(_purchaseController.text),
          targetSellingPrice: target,
          condition: _conditionController.text.trim(),
          sellerName: _sellerController.text.trim(),
          notes: _notesController.text.trim(),
        );
      } else {
        await _repository.createPurchase(
          imei: _imeiController.text.trim(),
          deviceName: _deviceController.text.trim(),
          purchasePrice: parseIntValue(_purchaseController.text),
          targetSellingPrice: target,
          condition: _conditionController.text.trim(),
          sellerName: _sellerController.text.trim(),
          notes: _notesController.text.trim(),
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Data HP diperbarui' : 'HP tersimpan'),
        ),
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Gagal menyimpan HP: $error');
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
    final title = _isEdit ? 'Edit HP' : 'Beli HP';
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(title),
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
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _purchaseController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Harga Beli',
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.shopping_bag_outlined),
                        ),
                        validator: _positiveNumber,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _targetController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Harga Jual Target',
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                        validator: _emptyOrPositiveNumber,
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
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _sellerController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nama Penjual',
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
                    label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
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

  String? _emptyOrPositiveNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (parseIntValue(value) <= 0) {
      return 'Nilai harus valid';
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
              color: _PhoneFormPageState._textColor,
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
