import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../data/topup_repository.dart';

class TopupsPage extends StatelessWidget {
  const TopupsPage({super.key});

  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF16A34A);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  Future<void> _openForm(BuildContext context, TopupType type) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => TopupFormPage(type: type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Pulsa & Paket Data'),
        centerTitle: false,
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _ActionCard(
              title: 'Jual Pulsa',
              subtitle: 'Transaksi pulsa langsung tanpa stok',
              icon: Icons.phone_iphone_outlined,
              onTap: () => _openForm(context, TopupType.pulsa),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              title: 'Jual Paket Data',
              subtitle: 'Paket internet langsung tanpa stok',
              icon: Icons.data_usage_outlined,
              onTap: () => _openForm(context, TopupType.dataPackage),
            ),
            const SizedBox(height: 16),
            const _SectionCard(
              title: 'Pencatatan',
              child: Text(
                'Transaksi tersimpan sebagai penjualan dan muncul di Riwayat, Dashboard, grafik, serta Rekap.',
                style: TextStyle(
                  color: _mutedColor,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopupFormPage extends StatefulWidget {
  const TopupFormPage({super.key, required this.type});

  final TopupType type;

  @override
  State<TopupFormPage> createState() => _TopupFormPageState();
}

class _TopupFormPageState extends State<TopupFormPage> {
  static const _providers = [
    'Telkomsel',
    'Indosat',
    'XL',
    'Axis',
    'Tri',
    'Smartfren',
    'Lainnya',
  ];
  static const _nominals = [
    '5000',
    '10000',
    '20000',
    '25000',
    '50000',
    '100000',
  ];

  final _repository = const TopupRepository();
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _providerController = TextEditingController();
  final _itemController = TextEditingController();
  final _costController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;
  bool _providerEditedManually = false;

  int get _costPrice => parseIntValue(_costController.text);
  int get _sellingPrice => parseIntValue(_priceController.text);
  int get _profit => _sellingPrice - _costPrice;

  bool get _isPulsa => widget.type == TopupType.pulsa;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_detectProvider);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_detectProvider);
    _phoneController.dispose();
    _providerController.dispose();
    _itemController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _detectProvider() {
    if (_providerEditedManually) {
      return;
    }
    final detected = _providerFromPhone(_phoneController.text);
    if (detected == null || detected == _providerController.text) {
      return;
    }
    setState(() {
      _providerController.text = detected;
    });
  }

  String? _providerFromPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) {
      return null;
    }
    final prefix = digits.substring(0, 4);
    if ([
      '0811',
      '0812',
      '0813',
      '0821',
      '0822',
      '0823',
      '0851',
      '0852',
      '0853',
    ].contains(prefix)) {
      return 'Telkomsel';
    }
    if ([
      '0814',
      '0815',
      '0816',
      '0855',
      '0856',
      '0857',
      '0858',
    ].contains(prefix)) {
      return 'Indosat';
    }
    if (['0817', '0818', '0819', '0859', '0877', '0878'].contains(prefix)) {
      return 'XL';
    }
    if (['0831', '0832', '0833', '0838'].contains(prefix)) {
      return 'Axis';
    }
    if (['0895', '0896', '0897', '0898', '0899'].contains(prefix)) {
      return 'Tri';
    }
    if (RegExp(r'^088[1-9]$').hasMatch(prefix)) {
      return 'Smartfren';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final confirmed = await _showConfirmation();
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final result = await _repository.createTransaction(
        type: widget.type,
        phoneNumber: _phoneController.text,
        provider: _providerController.text,
        itemName: _itemController.text,
        costPrice: _costPrice,
        sellingPrice: _sellingPrice,
        notes: _notesController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.type.label} tersimpan (${result.transactionNumber})',
          ),
        ),
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Gagal menyimpan transaksi: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool?> _showConfirmation() {
    final profitLabel = _profit >= 0 ? 'Keuntungan' : 'Kerugian';
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Transaksi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ConfirmLine(label: 'Jenis', value: widget.type.label),
              _ConfirmLine(label: 'Nomor', value: _phoneController.text.trim()),
              _ConfirmLine(
                label: 'Provider',
                value: _providerController.text.trim(),
              ),
              _ConfirmLine(
                label: _isPulsa ? 'Nominal' : 'Paket',
                value: _itemController.text.trim(),
              ),
              _ConfirmLine(label: 'Modal', value: formatRupiah(_costPrice)),
              _ConfirmLine(
                label: 'Harga Jual',
                value: formatRupiah(_sellingPrice),
              ),
              _ConfirmLine(
                label: profitLabel,
                value: formatRupiah(_profit.abs()),
                valueColor: _profit >= 0
                    ? TopupsPage._successColor
                    : TopupsPage._dangerColor,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
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
    final title = _isPulsa ? 'Jual Pulsa' : 'Jual Paket Data';
    final profitColor = _profit >= 0
        ? TopupsPage._successColor
        : TopupsPage._dangerColor;

    return Scaffold(
      backgroundColor: TopupsPage._backgroundColor,
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
        backgroundColor: TopupsPage._backgroundColor,
        foregroundColor: TopupsPage._textColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: _SectionCard(
              title: 'Data Transaksi',
              child: Column(
                children: [
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Nomor HP Tujuan',
                      prefixIcon: Icon(Icons.phone_iphone_outlined),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _providerController,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _providerEditedManually = true,
                    decoration: InputDecoration(
                      labelText: 'Provider',
                      prefixIcon: const Icon(Icons.cell_tower_outlined),
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (value) {
                          setState(() {
                            _providerEditedManually = true;
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
                    controller: _itemController,
                    keyboardType: _isPulsa
                        ? TextInputType.number
                        : TextInputType.text,
                    textInputAction: TextInputAction.next,
                    inputFormatters: _isPulsa
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : null,
                    decoration: InputDecoration(
                      labelText: _isPulsa ? 'Nominal Pulsa' : 'Nama Paket',
                      prefixIcon: Icon(
                        _isPulsa
                            ? Icons.payments_outlined
                            : Icons.data_usage_outlined,
                      ),
                    ),
                    validator: _required,
                  ),
                  if (_isPulsa) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _nominals.map((nominal) {
                          return ActionChip(
                            label: Text(formatRupiah(parseIntValue(nominal))),
                            onPressed: () {
                              setState(() {
                                _itemController.text = nominal;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _NumberField(
                    controller: _costController,
                    label: 'Modal',
                    icon: Icons.shopping_bag_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _NumberField(
                    controller: _priceController,
                    label: 'Harga Jual',
                    icon: Icons.sell_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Opsional',
                      prefixIcon: Icon(Icons.notes_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
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
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isSaving ? 'Menyimpan...' : 'Konfirmasi & Simpan',
                      ),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: TopupsPage._primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: TopupsPage._primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: TopupsPage._textColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: TopupsPage._mutedColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: TopupsPage._mutedColor),
            ],
          ),
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
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
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
        prefixText: 'Rp ',
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
    this.valueColor = TopupsPage._textColor,
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
              color: TopupsPage._mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: valueColor, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _ConfirmLine extends StatelessWidget {
  const _ConfirmLine({
    required this.label,
    required this.value,
    this.valueColor = TopupsPage._textColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: TopupsPage._mutedColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium
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
        borderRadius: BorderRadius.circular(16),
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
              color: TopupsPage._textColor,
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
