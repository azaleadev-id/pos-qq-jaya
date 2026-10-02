import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../sales/presentation/sales_scanner_page.dart';
import '../data/product.dart';
import '../data/product_api_repository.dart';
import 'product_form_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF16A34A);
  static const _warningColor = Color(0xFFF97316);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);
  static const _categories = [
    'Semua',
    'Barang',
    'Pulsa',
    'Paket Data',
    'Voucher',
  ];

  final _repository = const ProductApiRepository();
  final _searchController = TextEditingController();
  String _selectedCategory = 'Semua';
  var _isLoading = true;
  String? _errorMessage;
  List<Product> _products = [];

  List<Product> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();

    return _products.where((product) {
      final matchesCategory =
          _selectedCategory == 'Semua' || product.category == _selectedCategory;
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await _repository.fetchProducts();
      if (!mounted) {
        return;
      }
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddProduct({String initialBarcode = ''}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ProductFormPage(initialBarcode: initialBarcode),
      ),
    );

    if (saved == true) {
      await _loadProducts();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barang berhasil ditambahkan')),
      );
    }
  }

  Future<void> _openEditProduct(Product product) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ProductFormPage(product: product),
      ),
    );

    if (saved == true) {
      await _loadProducts();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barang berhasil diperbarui')),
      );
    }
  }

  Future<void> _scanProduct() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (context) => const SalesScannerPage()),
    );

    if (!mounted || code == null) {
      return;
    }

    Product? product;
    for (final item in _products) {
      if (item.barcode == code) {
        product = item;
        break;
      }
    }
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Barang dengan barcode ini belum terdaftar'),
          action: SnackBarAction(
            label: 'Tambah',
            onPressed: () => _openAddProduct(initialBarcode: code),
          ),
        ),
      );
      return;
    }

    _openEditProduct(product);
  }

  Future<void> _confirmDelete(Product product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus barang ini?'),
          content: Text(product.name),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: _dangerColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _repository.deleteProduct(product.id);
      await _loadProducts();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      return;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Barang berhasil dihapus')));
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Barang'),
        centerTitle: false,
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _scanProduct,
            icon: const Icon(Icons.qr_code_scanner_outlined),
            tooltip: 'Scan barcode',
          ),
          IconButton.filledTonal(
            onPressed: () => _openAddProduct(),
            icon: const Icon(Icons.add),
            tooltip: 'Tambah barang',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProducts,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Cari nama atau barcode',
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((category) {
                    final isSelected = category == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const _LoadingProductsCard()
              else if (_errorMessage != null)
                _ErrorProductsCard(
                  message: 'Gagal memuat barang',
                  detail: _errorMessage!,
                  onRetry: _loadProducts,
                )
              else if (_products.isEmpty)
                _EmptyProductsCard(
                  message: 'Belum ada barang',
                  onAddProduct: () => _openAddProduct(),
                )
              else if (products.isEmpty)
                _EmptyProductsCard(
                  message: 'Barang tidak ditemukan',
                  onAddProduct: () => _openAddProduct(),
                )
              else
                ...products.map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProductCard(
                      product: product,
                      onTap: () => _openEditProduct(product),
                      onDelete: () => _confirmDelete(product),
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final stockColor = _stockColor(product.stock);
    final stockText = product.stock == 0
        ? 'Stok habis'
        : product.stock <= 3
        ? 'Stok menipis'
        : 'Stok: ${product.stock}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _ProductsPageState._primaryColor.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: _ProductsPageState._primaryColor,
                  size: 22,
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _ProductsPageState._textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _ProductsPageState._mutedColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatRupiah(product.sellingPrice),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _ProductsPageState._textColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _SmallChip(label: stockText, color: stockColor),
                        if (product.barcode.isNotEmpty)
                          _SmallChip(
                            label: product.barcode,
                            color: _ProductsPageState._mutedColor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'delete', child: Text('Hapus Barang')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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

class _EmptyProductsCard extends StatelessWidget {
  const _EmptyProductsCard({required this.message, required this.onAddProduct});

  final String message;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: _ProductsPageState._mutedColor,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: _ProductsPageState._textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAddProduct,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Barang'),
          ),
        ],
      ),
    );
  }
}

class _LoadingProductsCard extends StatelessWidget {
  const _LoadingProductsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorProductsCard extends StatelessWidget {
  const _ErrorProductsCard({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: _ProductsPageState._dangerColor,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: _ProductsPageState._textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _ProductsPageState._mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
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

Color _stockColor(int stock) {
  if (stock == 0) {
    return _ProductsPageState._dangerColor;
  }

  if (stock <= 3) {
    return _ProductsPageState._warningColor;
  }

  return _ProductsPageState._successColor;
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
