import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../products/data/product.dart';
import '../../products/data/product_api_repository.dart';
import '../data/sale_api_repository.dart';
import 'sales_scanner_page.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF16A34A);
  static const _warningColor = Color(0xFFF97316);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  final _productRepository = const ProductApiRepository();
  final _saleRepository = const SaleApiRepository();
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _manualItemController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  List<Product> _products = [];
  String? _selectedProductId;
  String? _productsError;
  bool _isManualItem = false;
  bool _isLoadingProducts = true;
  bool _isSaving = false;

  Product? get _selectedProduct {
    final selectedProductId = _selectedProductId;
    if (selectedProductId == null) {
      return null;
    }
    return _productById(selectedProductId);
  }

  List<Product> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty || _isManualItem) {
      return _products;
    }

    return _products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList();
  }

  int get _costPrice => _parseNumber(_costPriceController.text);
  int get _sellingPrice => _parseNumber(_sellingPriceController.text);
  int get _quantity => _parseNumber(_quantityController.text);
  int get _summaryQuantity => _quantity == 0 ? 1 : _quantity;
  int get _totalCost => _costPrice * _summaryQuantity;
  int get _totalSales => _sellingPrice * _summaryQuantity;
  int get _profit => (_sellingPrice - _costPrice) * _summaryQuantity;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualItemController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({bool keepSelection = false}) async {
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });

    try {
      final products = await _productRepository.fetchProducts();
      if (!mounted) {
        return;
      }

      setState(() {
        _products = products;
        _isLoadingProducts = false;
        if (!keepSelection || _selectedProduct == null) {
          _selectedProductId = null;
        }
      });
    } on ApiException catch (error) {
      _setProductsError(error.message);
    } catch (error) {
      _setProductsError('Gagal memuat barang: $error');
    }
  }

  void _setProductsError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingProducts = false;
      _productsError = message;
    });
  }

  void _refreshSummary() {
    setState(() {});
  }

  void _applyProduct(Product product) {
    _isManualItem = false;
    _selectedProductId = product.id;
    _searchController.text = product.name;
    _manualItemController.clear();
    _costPriceController.text = product.costPrice.toString();
    _sellingPriceController.text = product.sellingPrice.toString();
    if (_quantityController.text.trim().isEmpty ||
        _parseNumber(_quantityController.text) < 1) {
      _quantityController.text = '1';
    }
  }

  void _selectProduct(Product product) {
    setState(() {
      _applyProduct(product);
    });
  }

  void _useManualInput() {
    setState(() {
      _isManualItem = true;
      _selectedProductId = null;
      _searchController.clear();
      _manualItemController.clear();
      _costPriceController.clear();
      _sellingPriceController.clear();
      _quantityController.text = '1';
    });
  }

  Future<void> _openScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (context) => const SalesScannerPage()),
    );

    if (!mounted || code == null) {
      return;
    }

    final product = _productByBarcode(code);
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barang dengan kode ini belum terdaftar')),
      );
      return;
    }

    _selectProduct(product);
  }

  Future<void> _saveSale() async {
    if (_isSaving) {
      return;
    }

    if (!_isManualItem && _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barang tidak boleh kosong')),
      );
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final selectedProduct = _selectedProduct;

    setState(() {
      _isSaving = true;
    });

    try {
      final result = selectedProduct == null
          ? await _saleRepository.createManualSale(
              productName: _manualItemController.text.trim(),
              quantity: _quantity,
              costPrice: _costPrice,
              sellingPrice: _sellingPrice,
            )
          : await _saleRepository.createProductSale(
              product: selectedProduct,
              quantity: _quantity,
              sellingPrice: _sellingPrice,
            );

      if (!mounted) {
        return;
      }

      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.transactionNumber.isEmpty
                ? 'Penjualan berhasil disimpan'
                : 'Penjualan ${result.transactionNumber} berhasil disimpan',
          ),
        ),
      );

      setState(() {
        _isManualItem = false;
        _selectedProductId = null;
        _searchController.clear();
        _manualItemController.clear();
        _costPriceController.clear();
        _sellingPriceController.clear();
        _quantityController.text = '1';
      });
      await _loadProducts(keepSelection: false);
    } on ApiException catch (error) {
      _showSaveError(error.message);
    } catch (error) {
      _showSaveError('Gagal menyimpan penjualan: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSaveError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Product? _productById(String id) {
    for (final product in _products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  Product? _productByBarcode(String barcode) {
    final normalized = barcode.trim();
    for (final product in _products) {
      if (product.barcode.trim() == normalized) {
        return product;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedProduct = _selectedProduct;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Penjualan'),
        centerTitle: false,
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _isLoadingProducts || _isSaving
                ? null
                : () => _loadProducts(keepSelection: true),
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'Refresh barang',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionCard(
                  title: 'Barang',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) {
                          setState(() {
                            _isManualItem = false;
                            _selectedProductId = null;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Cari barang',
                          prefixIcon: const Icon(Icons.search_outlined),
                          suffixIcon: IconButton(
                            onPressed: _isLoadingProducts || _isSaving
                                ? null
                                : _openScanner,
                            icon: const Icon(Icons.qr_code_scanner_outlined),
                            tooltip: 'Scan barang',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isManualItem)
                        TextFormField(
                          controller: _manualItemController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nama barang manual',
                            prefixIcon: Icon(Icons.edit_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Barang tidak boleh kosong';
                            }
                            return null;
                          },
                        )
                      else ...[
                        if (_isLoadingProducts)
                          const _ProductsLoadingView()
                        else if (_productsError != null)
                          _ProductsErrorView(
                            message: _productsError!,
                            onRetry: () => _loadProducts(keepSelection: true),
                          )
                        else
                          _ProductPickerList(
                            products: _filteredProducts,
                            selectedProductId: _selectedProductId,
                            onSelected: _selectProduct,
                          ),
                        const SizedBox(height: 12),
                        if (selectedProduct != null)
                          _StockIndicator(product: selectedProduct),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _useManualInput,
                          icon: const Icon(Icons.edit_note_outlined),
                          label: const Text('Input barang manual'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Transaksi Penjualan',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _costPriceController,
                        readOnly: !_isManualItem && selectedProduct != null,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => _refreshSummary(),
                        decoration: const InputDecoration(
                          labelText: 'Harga Modal',
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: (value) =>
                            _validatePositiveNumber(value, 'Harga modal'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _sellingPriceController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => _refreshSummary(),
                        decoration: const InputDecoration(
                          labelText: 'Harga Jual',
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.point_of_sale_outlined),
                        ),
                        validator: (value) =>
                            _validatePositiveNumber(value, 'Harga jual'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => _refreshSummary(),
                        decoration: const InputDecoration(
                          labelText: 'Jumlah',
                          prefixIcon: Icon(Icons.format_list_numbered),
                        ),
                        validator: (value) {
                          final quantity = _parseNumber(value ?? '');
                          if (quantity < 1) {
                            return 'Jumlah minimal 1';
                          }

                          if (!_isManualItem &&
                              selectedProduct != null &&
                              quantity > selectedProduct.stock) {
                            return 'Stok tidak mencukupi';
                          }

                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SummaryCard(
                  totalCost: _totalCost,
                  totalSales: _totalSales,
                  profit: _profit,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveSale,
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

  static String? _validatePositiveNumber(String? value, String label) {
    final number = _parseNumber(value ?? '');
    if (number <= 0) {
      return '$label harus valid';
    }
    return null;
  }
}

class _ProductPickerList extends StatelessWidget {
  const _ProductPickerList({
    required this.products,
    required this.selectedProductId,
    required this.onSelected,
  });

  final List<Product> products;
  final String? selectedProductId;
  final ValueChanged<Product> onSelected;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _SalesPageState._backgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Barang tidak ditemukan',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _SalesPageState._mutedColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final product = products[index];
          final isSelected = product.id == selectedProductId;

          return Material(
            color: isSelected
                ? _SalesPageState._primaryColor.withValues(alpha: 0.09)
                : _SalesPageState._backgroundColor,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelected(product),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _SalesPageState._primaryColor.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: _SalesPageState._primaryColor,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: _SalesPageState._textColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${product.category} - ${product.barcode}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: _SalesPageState._mutedColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StockPill(stock: product.stock),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductsLoadingView extends StatelessWidget {
  const _ProductsLoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SalesPageState._backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Memuat barang...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _SalesPageState._mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductsErrorView extends StatelessWidget {
  const _ProductsErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SalesPageState._dangerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _SalesPageState._dangerColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _SalesPageState._dangerColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

class _StockIndicator extends StatelessWidget {
  const _StockIndicator({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final color = _stockColor(product.stock);
    final label = product.stock == 0
        ? 'Stok habis'
        : product.stock <= 3
        ? 'Stok menipis: ${product.stock}'
        : 'Stok tersedia: ${product.stock}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _SalesPageState._textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Text(
            formatRupiah(product.sellingPrice),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _SalesPageState._textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final color = _stockColor(stock);
    final label = stock == 0 ? 'Habis' : 'Stok $stock';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalCost,
    required this.totalSales,
    required this.profit,
  });

  final int totalCost;
  final int totalSales;
  final int profit;

  @override
  Widget build(BuildContext context) {
    final profitColor = profit < 0
        ? _SalesPageState._dangerColor
        : _SalesPageState._successColor;

    return _SectionCard(
      title: 'Ringkasan',
      child: Column(
        children: [
          _SummaryRow(label: 'Total Modal', value: formatRupiah(totalCost)),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Total Penjualan',
            value: formatRupiah(totalSales),
          ),
          const Divider(height: 28),
          _SummaryRow(
            label: 'Keuntungan',
            value: formatRupiah(profit),
            valueColor: profitColor,
            isEmphasized: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor = _SalesPageState._textColor,
    this.isEmphasized = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _SalesPageState._mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style:
              (isEmphasized
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.titleSmall)
                  ?.copyWith(color: valueColor, fontWeight: FontWeight.w900),
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
              color: _SalesPageState._textColor,
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

Color _stockColor(int stock) {
  if (stock == 0) {
    return _SalesPageState._dangerColor;
  }

  if (stock <= 3) {
    return _SalesPageState._warningColor;
  }

  return _SalesPageState._successColor;
}
