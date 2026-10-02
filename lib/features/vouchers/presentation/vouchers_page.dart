import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../sales/presentation/sales_scanner_page.dart';
import '../data/voucher_repository.dart';

class VouchersPage extends StatefulWidget {
  const VouchersPage({super.key});

  @override
  State<VouchersPage> createState() => _VouchersPageState();
}

class _VouchersPageState extends State<VouchersPage> {
  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF16A34A);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  final _repository = const VoucherRepository();
  final _searchController = TextEditingController();

  List<VoucherItem> _vouchers = [];
  String? _error;
  bool _isLoading = true;

  List<VoucherItem> get _filteredVouchers {
    final query = _searchController.text;
    return _vouchers.where((voucher) => voucher.matchesQuery(query)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVouchers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final vouchers = await _repository.fetchVouchers();
      if (!mounted) {
        return;
      }
      setState(() {
        _vouchers = vouchers;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat voucher: $error');
    }
  }

  Future<void> _refreshVouchers() async {
    try {
      final vouchers = await _repository.fetchVouchers();
      if (!mounted) {
        return;
      }
      setState(() {
        _vouchers = vouchers;
        _error = null;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat voucher: $error');
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

  Future<void> _openAddForm() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => const VoucherFormPage()),
    );
    if (changed == true) {
      await _loadVouchers();
    }
  }

  Future<void> _openSellForm([VoucherItem? voucher]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => VoucherSalePage(initialVoucher: voucher),
      ),
    );
    if (changed == true) {
      await _loadVouchers();
    }
  }

  Future<void> _scanAndSell() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (context) => const SalesScannerPage()),
    );
    if (!mounted || code == null) {
      return;
    }
    final normalized = code.trim();
    final match = _vouchers.where((voucher) => voucher.code == normalized);
    if (match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voucher dengan kode ini tidak ditemukan'),
        ),
      );
      return;
    }
    final voucher = match.first;
    if (voucher.stock <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voucher ini sudah habis')));
      return;
    }
    await _openSellForm(voucher);
  }

  @override
  Widget build(BuildContext context) {
    final vouchers = _filteredVouchers;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Voucher'),
        centerTitle: false,
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadVouchers,
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'Refresh voucher',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddForm,
        icon: const Icon(Icons.add_outlined),
        label: const Text('Tambah'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshVouchers,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _ActionGrid(
                onAdd: _openAddForm,
                onSell: () => _openSellForm(),
                onScan: _scanAndSell,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Cari provider, voucher, atau kode',
                  prefixIcon: Icon(Icons.search_outlined),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorState(message: _error!, onRetry: _loadVouchers)
              else if (vouchers.isEmpty)
                const _EmptyState(message: 'Belum ada stok voucher')
              else
                ...vouchers.map(
                  (voucher) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VoucherCard(
                      voucher: voucher,
                      onSell: () => _openSellForm(voucher),
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

class VoucherFormPage extends StatefulWidget {
  const VoucherFormPage({super.key});

  @override
  State<VoucherFormPage> createState() => _VoucherFormPageState();
}

class _VoucherFormPageState extends State<VoucherFormPage> {
  static const _providers = [
    'Telkomsel',
    'Indosat',
    'XL',
    'Axis',
    'Tri',
    'Smartfren',
  ];

  final _repository = const VoucherRepository();
  final _formKey = GlobalKey<FormState>();
  final _providerController = TextEditingController(text: _providers.first);
  final _nameController = TextEditingController();
  final _packageController = TextEditingController();
  final _codeController = TextEditingController();
  final _costController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  bool _isSaving = false;

  @override
  void dispose() {
    _providerController.dispose();
    _nameController.dispose();
    _packageController.dispose();
    _codeController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _scanCode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (context) => const SalesScannerPage()),
    );
    if (!mounted || code == null) {
      return;
    }
    setState(() {
      _codeController.text = code.trim();
    });
  }

  Future<void> _save() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await _repository.createVoucher(
        provider: _providerController.text.trim(),
        voucherName: _nameController.text.trim(),
        packageName: _packageController.text.trim(),
        code: _codeController.text.trim(),
        costPrice: parseIntValue(_costController.text),
        sellingPrice: parseIntValue(_priceController.text),
        quantity: parseIntValue(_quantityController.text),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Voucher tersimpan')));
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Gagal menyimpan voucher: $error');
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
    return Scaffold(
      backgroundColor: _VouchersPageState._backgroundColor,
      appBar: AppBar(
        title: const Text('Tambah Voucher'),
        centerTitle: false,
        backgroundColor: _VouchersPageState._backgroundColor,
        foregroundColor: _VouchersPageState._textColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: _SectionCard(
              title: 'Data Voucher',
              child: Column(
                children: [
                  TextFormField(
                    controller: _providerController,
                    decoration: InputDecoration(
                      labelText: 'Provider',
                      prefixIcon: const Icon(Icons.cell_tower_outlined),
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (value) {
                          setState(() {
                            _providerController.text = value;
                          });
                        },
                        itemBuilder: (context) => _providers
                            .map(
                              (provider) => PopupMenuItem(
                                value: provider,
                                child: Text(provider),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nama / Jenis Voucher',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _packageController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nominal / Paket',
                      prefixIcon: Icon(Icons.data_usage_outlined),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codeController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Kode / Serial',
                      prefixIcon: const Icon(Icons.qr_code_2_outlined),
                      suffixIcon: IconButton(
                        onPressed: _scanCode,
                        icon: const Icon(Icons.qr_code_scanner_outlined),
                        tooltip: 'Scan kode voucher',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _NumberField(
                    controller: _costController,
                    label: 'Modal',
                    icon: Icons.shopping_bag_outlined,
                  ),
                  const SizedBox(height: 14),
                  _NumberField(
                    controller: _priceController,
                    label: 'Harga Jual',
                    icon: Icons.sell_outlined,
                  ),
                  const SizedBox(height: 14),
                  _NumberField(
                    controller: _quantityController,
                    label: 'Jumlah',
                    icon: Icons.inventory_2_outlined,
                    prefixText: null,
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
                    ),
                  ),
                ],
              ),
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
}

class VoucherSalePage extends StatefulWidget {
  const VoucherSalePage({super.key, this.initialVoucher});

  final VoucherItem? initialVoucher;

  @override
  State<VoucherSalePage> createState() => _VoucherSalePageState();
}

class _VoucherSalePageState extends State<VoucherSalePage> {
  final _repository = const VoucherRepository();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  List<VoucherItem> _vouchers = [];
  VoucherItem? _selectedVoucher;
  String? _error;
  bool _isLoading = true;
  bool _isSaving = false;

  int get _quantity => parseIntValue(_quantityController.text);
  int get _sellingPrice => parseIntValue(_priceController.text);
  int get _profit {
    final voucher = _selectedVoucher;
    if (voucher == null) {
      return 0;
    }
    return (_sellingPrice - voucher.costPrice) * _quantity;
  }

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadVouchers() async {
    try {
      final vouchers = await _repository.fetchVouchers();
      if (!mounted) {
        return;
      }
      final available = vouchers.where((voucher) => voucher.stock > 0).toList();
      final initial = widget.initialVoucher;
      VoucherItem? selected;
      if (initial == null) {
        selected = available.isEmpty ? null : available.first;
      } else {
        for (final voucher in available) {
          if (voucher.id == initial.id) {
            selected = voucher;
            break;
          }
        }
      }
      setState(() {
        _vouchers = available;
        _selectedVoucher = selected;
        _priceController.text = selected?.sellingPrice.toString() ?? '';
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat voucher: $error');
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

  Future<void> _scanVoucher() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (context) => const SalesScannerPage()),
    );
    if (!mounted || code == null) {
      return;
    }
    final match = _vouchers.where((voucher) => voucher.code == code.trim());
    if (match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voucher tidak ditemukan atau stok habis'),
        ),
      );
      return;
    }
    setState(() {
      _selectedVoucher = match.first;
      _priceController.text = match.first.sellingPrice.toString();
    });
  }

  Future<void> _sell() async {
    final voucher = _selectedVoucher;
    if (_isSaving || voucher == null) {
      return;
    }
    if (_quantity <= 0) {
      _showError('Jumlah harus lebih dari 0');
      return;
    }
    if (_quantity > voucher.stock) {
      _showError('Stok tidak cukup. Tersedia ${voucher.stock}.');
      return;
    }
    if (_sellingPrice <= 0) {
      _showError('Harga jual harus valid');
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await _repository.sellVoucher(
        voucher: voucher,
        quantity: _quantity,
        sellingPrice: _sellingPrice,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voucher berhasil dijual')));
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Gagal menjual voucher: $error');
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
    final voucher = _selectedVoucher;
    final profitColor = _profit >= 0
        ? _VouchersPageState._successColor
        : _VouchersPageState._dangerColor;
    return Scaffold(
      backgroundColor: _VouchersPageState._backgroundColor,
      appBar: AppBar(
        title: const Text('Jual Voucher'),
        centerTitle: false,
        backgroundColor: _VouchersPageState._backgroundColor,
        foregroundColor: _VouchersPageState._textColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _scanVoucher,
            icon: const Icon(Icons.qr_code_scanner_outlined),
            tooltip: 'Scan voucher',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: _isLoading
              ? const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadVouchers)
              : _vouchers.isEmpty
              ? const _EmptyState(message: 'Belum ada stok voucher tersedia')
              : _SectionCard(
                  title: 'Transaksi Voucher',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: voucher?.id,
                        decoration: const InputDecoration(
                          labelText: 'Voucher',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                        ),
                        items: _vouchers.map((item) {
                          return DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.displayName} (${item.stock})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          final selected = _vouchers.firstWhere(
                            (item) => item.id == id,
                          );
                          setState(() {
                            _selectedVoucher = selected;
                            _priceController.text = selected.sellingPrice
                                .toString();
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      _NumberField(
                        controller: _quantityController,
                        label: 'Jumlah',
                        icon: Icons.inventory_2_outlined,
                        prefixText: null,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      _NumberField(
                        controller: _priceController,
                        label: 'Harga Jual Satuan',
                        icon: Icons.sell_outlined,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      if (voucher != null)
                        _InfoLine(
                          label: 'Modal Satuan',
                          value: formatRupiah(voucher.costPrice),
                        ),
                      const SizedBox(height: 10),
                      _InfoLine(
                        label: _profit >= 0 ? 'Keuntungan' : 'Kerugian',
                        value: formatRupiah(_profit.abs()),
                        valueColor: profitColor,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _sell,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sell_outlined),
                          label: Text(_isSaving ? 'Menyimpan...' : 'Jual'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onAdd,
    required this.onSell,
    required this.onScan,
  });

  final VoidCallback onAdd;
  final VoidCallback onSell;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem('Tambah Voucher', Icons.add_outlined, onAdd),
      _ActionItem('Jual Voucher', Icons.sell_outlined, onSell),
      _ActionItem('Scan', Icons.qr_code_scanner_outlined, onScan),
    ];
    return Row(
      children: List.generate(actions.length, (index) {
        final item = actions[index];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == actions.length - 1 ? 0 : 8,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Icon(item.icon, color: _VouchersPageState._primaryColor),
                      const SizedBox(height: 8),
                      Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: _VouchersPageState._textColor,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher, required this.onSell});

  final VoucherItem voucher;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    final stockColor = voucher.stock <= 0
        ? _VouchersPageState._dangerColor
        : voucher.stock <= 3
        ? const Color(0xFFF97316)
        : _VouchersPageState._successColor;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  color: _VouchersPageState._primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    voucher.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: _VouchersPageState._textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'Stok ${voucher.stock}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: stockColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (voucher.code.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                voucher.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _VouchersPageState._mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricBlock(
                    label: 'Modal',
                    value: formatRupiah(voucher.costPrice),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricBlock(
                    label: 'Harga Jual',
                    value: formatRupiah(voucher.sellingPrice),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricBlock(
                    label: 'Untung / pcs',
                    value: formatRupiah(voucher.profitPerUnit),
                    valueColor: voucher.profitPerUnit >= 0
                        ? _VouchersPageState._successColor
                        : _VouchersPageState._dangerColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: voucher.stock <= 0 ? null : onSell,
                    icon: const Icon(Icons.sell_outlined),
                    label: const Text('Jual'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.icon,
    this.prefixText = 'Rp ',
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? prefixText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        prefixIcon: Icon(icon),
      ),
      validator: (value) {
        if (parseIntValue(value) <= 0) {
          return '$label harus lebih dari 0';
        }
        return null;
      },
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.valueColor = _VouchersPageState._textColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _VouchersPageState._mutedColor,
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
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    this.valueColor = _VouchersPageState._textColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _VouchersPageState._backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _VouchersPageState._mutedColor,
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
              color: _VouchersPageState._textColor,
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

class _ActionItem {
  const _ActionItem(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
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
            color: _VouchersPageState._mutedColor,
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
        color: _VouchersPageState._dangerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _VouchersPageState._dangerColor,
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
