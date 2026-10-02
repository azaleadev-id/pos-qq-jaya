import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../sales/presentation/sales_scanner_page.dart';
import '../data/product.dart';
import '../data/product_api_repository.dart';

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.product, this.initialBarcode = ''});

  final Product? product;
  final String initialBarcode;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);
  static const _categories = ['Barang', 'Pulsa', 'Paket Data', 'Voucher'];

  final _repository = const ProductApiRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();

  late String _selectedCategory;
  var _isSaving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _selectedCategory = product?.category ?? _categories.first;
    _nameController.text = product?.name ?? '';
    _barcodeController.text = product?.barcode ?? widget.initialBarcode;
    _costPriceController.text = product?.costPrice.toString() ?? '';
    _sellingPriceController.text = product?.sellingPrice.toString() ?? '';
    _stockController.text = product?.stock.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (context) => const SalesScannerPage()),
    );

    if (!mounted || code == null) {
      return;
    }

    setState(() {
      _barcodeController.text = code;
    });
  }

  Future<void> _saveProduct() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final existingProduct = widget.product;
    final product = Product(
      id: existingProduct?.id ?? '',
      name: _nameController.text.trim(),
      barcode: _barcodeController.text.trim(),
      costPrice: _parseNumber(_costPriceController.text),
      sellingPrice: _parseNumber(_sellingPriceController.text),
      stock: _parseNumber(_stockController.text),
      category: _selectedCategory,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      if (existingProduct == null) {
        await _repository.createProduct(product);
      } else {
        await _repository.updateProduct(product);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error.message))));
      return;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Barang' : 'Tambah Barang';
    final costPrice = _parseNumber(_costPriceController.text);
    final sellingPrice = _parseNumber(_sellingPriceController.text);

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
                  title: title,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nama Barang',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _barcodeController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Barcode / QR',
                          prefixIcon: const Icon(Icons.qr_code_2_outlined),
                          suffixIcon: IconButton(
                            onPressed: _scanBarcode,
                            icon: const Icon(Icons.qr_code_scanner_outlined),
                            tooltip: 'Scan Barcode',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value ?? _categories.first;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Kategori harus dipilih';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _costPriceController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Harga Modal',
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: (value) =>
                            _validateZeroOrPositive(value, 'Harga modal'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _sellingPriceController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Harga Jual',
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.point_of_sale_outlined),
                        ),
                        validator: (value) =>
                            _validateZeroOrPositive(value, 'Harga jual'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Stok',
                          prefixIcon: Icon(Icons.warehouse_outlined),
                        ),
                        validator: (value) =>
                            _validateZeroOrPositive(value, 'Stok'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Ringkasan',
                  child: _SummaryLine(
                    label: 'Keuntungan/unit',
                    value: formatRupiah(sellingPrice - costPrice),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveProduct,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Barang'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
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

  static int _parseNumber(String value) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  static String? _validateZeroOrPositive(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label harus diisi';
    }

    final number = _parseNumber(value);
    if (number < 0) {
      return '$label harus valid';
    }

    return null;
  }

  static String _friendlyError(String message) {
    if (message.toLowerCase().contains('barcode') ||
        message.toLowerCase().contains('qr')) {
      return 'Barcode sudah digunakan oleh barang lain';
    }
    return message;
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
              color: _ProductFormPageState._textColor,
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
  const _SummaryLine({required this.label, required this.value});

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
              color: _ProductFormPageState._mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: _ProductFormPageState._textColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

String formatRupiah(int value) {
  final isNegative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final positionFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }

  return '${isNegative ? '-' : ''}Rp ${buffer.toString()}';
}
