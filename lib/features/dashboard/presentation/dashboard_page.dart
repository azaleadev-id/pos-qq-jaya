import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../expenses/presentation/expenses_page.dart';
import '../../history/data/history_repository.dart';
import '../../history/presentation/history_page.dart';
import '../../history/presentation/sale_detail_page.dart';
import '../../phones/presentation/phone_detail_page.dart';
import '../../phones/presentation/phones_page.dart';
import '../../products/presentation/products_page.dart' hide formatRupiah;
import '../../recaps/presentation/recaps_page.dart';
import '../../sales/presentation/sales_page.dart';
import '../../services/data/service_repository.dart';
import '../../services/presentation/service_detail_page.dart';
import '../../services/presentation/services_page.dart';
import '../../topups/presentation/topups_page.dart';
import '../../vouchers/presentation/vouchers_page.dart';
import '../data/api_connection_service.dart';
import '../data/dashboard_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  static const _backgroundColor = Color(0xFFF6F7FB);
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF16A34A);
  static const _warningColor = Color(0xFFF97316);
  static const _dangerColor = Color(0xFFDC2626);
  static const _textColor = Color(0xFF111827);
  static const _mutedColor = Color(0xFF6B7280);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _apiConnectionService = const ApiConnectionService();
  ApiConnectionStatus _apiStatus = const ApiConnectionStatus.checking();
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _checkApiConnection();
  }

  Future<void> _checkApiConnection() async {
    setState(() {
      _apiStatus = const ApiConnectionStatus.checking();
    });

    final status = await _apiConnectionService.checkApiConnection();
    if (!mounted) {
      return;
    }

    setState(() {
      _apiStatus = status;
    });
  }

  void _refreshDashboardData() {
    if (!mounted) {
      return;
    }
    setState(() {
      _refreshTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      _ShortcutItem('Penjualan', Icons.point_of_sale_outlined),
      _ShortcutItem('Servis HP', Icons.build_outlined),
      _ShortcutItem('Jual Beli HP', Icons.phone_android_outlined),
      _ShortcutItem('Pengeluaran', Icons.payments_outlined),
      _ShortcutItem('Barang', Icons.inventory_2_outlined),
      _ShortcutItem('Voucher', Icons.confirmation_number_outlined),
      _ShortcutItem('Pulsa & Paket', Icons.sim_card_outlined),
      _ShortcutItem('Riwayat', Icons.history_outlined),
      _ShortcutItem('Rekap', Icons.summarize_outlined),
    ];

    return Scaffold(
      backgroundColor: DashboardPage._backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(
                apiStatus: _apiStatus,
                onRefresh: _checkApiConnection,
              ),
              const SizedBox(height: 16),
              _ShortcutGrid(items: shortcuts),
              const SizedBox(height: 16),
              _FinanceSummaryCard(key: ValueKey('finance-$_refreshTick')),
              const SizedBox(height: 16),
              const _ActiveServiceCard(),
              const SizedBox(height: 16),
              _LowStockSection(key: ValueKey('stock-$_refreshTick')),
              const SizedBox(height: 16),
              _RecentTransactionsSection(key: ValueKey('recent-$_refreshTick')),
              const SizedBox(height: 16),
              _SalesChartPlaceholder(key: ValueKey('chart-$_refreshTick')),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.apiStatus, required this.onRefresh});

  final ApiConnectionStatus apiStatus;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final statusColor = apiStatus.message == 'Memeriksa koneksi...'
        ? DashboardPage._warningColor
        : apiStatus.isConnected
        ? DashboardPage._successColor
        : DashboardPage._dangerColor;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QQ Jaya Cell',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: DashboardPage._textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      apiStatus.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (apiStatus.apiVersion != null) ...[
                const SizedBox(height: 3),
                Text(
                  'API v${apiStatus.apiVersion}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: DashboardPage._mutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.sync_outlined),
          tooltip: 'Cek koneksi API',
        ),
        IconButton.filledTonal(
          onPressed: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Pengaturan')));
          },
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Pengaturan',
        ),
      ],
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({required this.items});

  final List<_ShortcutItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.86,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final navigator = Navigator.of(context);
              final dashboardState = context
                  .findAncestorStateOfType<_DashboardPageState>();
              if (item.label == 'Penjualan') {
                await navigator.push(
                  MaterialPageRoute<void>(
                    builder: (context) => const SalesPage(),
                  ),
                );
                dashboardState?._refreshDashboardData();
                return;
              }

              if (item.label == 'Servis HP') {
                await navigator.push(
                  MaterialPageRoute<void>(
                    builder: (context) => const ServicesPage(),
                  ),
                );
                dashboardState?._refreshDashboardData();
                return;
              }

              if (item.label == 'Jual Beli HP') {
                await navigator.push(
                  MaterialPageRoute<void>(
                    builder: (context) => const PhonesPage(),
                  ),
                );
                dashboardState?._refreshDashboardData();
                return;
              }

              if (item.label == 'Pengeluaran') {
                await navigator.push(
                  MaterialPageRoute<void>(
                    builder: (context) => const ExpensesPage(),
                  ),
                );
                dashboardState?._refreshDashboardData();
                return;
              }

              if (item.label == 'Voucher') {
                await navigator.push(
                  MaterialPageRoute<void>(
                    builder: (context) => const VouchersPage(),
                  ),
                );
                dashboardState?._refreshDashboardData();
                return;
              }

              if (item.label == 'Pulsa & Paket') {
                await navigator.push(
                  MaterialPageRoute<void>(
                    builder: (context) => const TopupsPage(),
                  ),
                );
                dashboardState?._refreshDashboardData();
                return;
              }

              if (item.label == 'Barang') {
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (context) => const ProductsPage(),
                  ),
                );
                return;
              }

              if (item.label == 'Riwayat') {
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (context) => const HistoryPage(),
                  ),
                );
                return;
              }

              if (item.label == 'Rekap') {
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (context) => const RecapsPage(),
                  ),
                );
                return;
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: DashboardPage._primaryColor.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      color: DashboardPage._primaryColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: DashboardPage._textColor,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FinanceSummaryCard extends StatefulWidget {
  const _FinanceSummaryCard({super.key});

  @override
  State<_FinanceSummaryCard> createState() => _FinanceSummaryCardState();
}

class _FinanceSummaryCardState extends State<_FinanceSummaryCard> {
  final _repository = const DashboardRepository();

  DashboardSummary? _summary;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final snapshot = await _repository.fetchDashboard();
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = snapshot.summary;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat ringkasan: $error');
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

  @override
  Widget build(BuildContext context) {
    final summary = _summary ?? const DashboardSummary.empty();
    final items = [
      _FinanceItem(
        'Omzet',
        formatRupiah(summary.omzet),
        Icons.trending_up_outlined,
      ),
      _FinanceItem(
        'Keuntungan',
        formatRupiah(summary.grossProfit),
        Icons.savings_outlined,
      ),
      _FinanceItem(
        'Pengeluaran',
        formatRupiah(summary.expenses),
        Icons.receipt_long_outlined,
      ),
      _FinanceItem(
        'Laba Bersih',
        formatRupiah(summary.netProfit),
        Icons.account_balance_wallet_outlined,
      ),
    ];

    return _SectionCard(
      title: 'Ringkasan Keuangan',
      child: Builder(
        builder: (context) {
          if (_isLoading) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_error != null) {
            return _DashboardErrorState(
              message: _error!,
              onRetry: _loadSummary,
            );
          }
          return GridView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemBuilder: (context, index) {
              final item = items[index];

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DashboardPage._backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      color: DashboardPage._primaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: DashboardPage._mutedColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item.amount,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: DashboardPage._textColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ActiveServiceCard extends StatefulWidget {
  const _ActiveServiceCard();

  @override
  State<_ActiveServiceCard> createState() => _ActiveServiceCardState();
}

class _ActiveServiceCardState extends State<_ActiveServiceCard> {
  final _repository = const ServiceRepository();

  List<ServiceJob> _services = [];
  String? _error;
  bool _isLoading = true;

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
        _services = services
            .where((service) => service.isActive)
            .take(5)
            .toList();
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat servis aktif: $error');
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

  Future<void> _openDetail(ServiceJob service) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ServiceDetailPage(serviceId: service.id),
      ),
    );
    await _loadServices();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Servis Aktif',
      child: Builder(
        builder: (context) {
          if (_isLoading) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_error != null) {
            return _DashboardErrorState(
              message: _error!,
              onRetry: _loadServices,
            );
          }
          if (_services.isEmpty) {
            return const _EmptyState(message: 'Belum ada servis aktif.');
          }
          return Column(
            children: List.generate(_services.length, (index) {
              final service = _services[index];
              return Column(
                children: [
                  _ActiveServiceTile(
                    service: service,
                    onTap: () => _openDetail(service),
                  ),
                  if (index != _services.length - 1) const Divider(height: 18),
                ],
              );
            }),
          );
        },
      ),
    );
  }
}

class _ActiveServiceTile extends StatelessWidget {
  const _ActiveServiceTile({required this.service, required this.onTap});

  final ServiceJob service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DashboardPage._primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.build_outlined,
                  color: DashboardPage._primaryColor,
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DashboardPage._textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${service.serviceName} - ${service.status.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DashboardPage._mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Sisa ${formatRupiah(service.remainingPayment)}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: DashboardPage._textColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowStockSection extends StatefulWidget {
  const _LowStockSection({super.key});

  @override
  State<_LowStockSection> createState() => _LowStockSectionState();
}

class _LowStockSectionState extends State<_LowStockSection> {
  final _repository = const DashboardRepository();

  List<DashboardLowStockProduct> _products = [];
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLowStock();
  }

  Future<void> _loadLowStock() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final snapshot = await _repository.fetchDashboard();
      if (!mounted) {
        return;
      }
      setState(() {
        _products = snapshot.lowStockProducts.take(5).toList();
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat stok menipis: $error');
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

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Stok Menipis',
      child: Builder(
        builder: (context) {
          if (_isLoading) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_error != null) {
            return _DashboardErrorState(
              message: _error!,
              onRetry: _loadLowStock,
            );
          }
          if (_products.isEmpty) {
            return const _EmptyState(message: 'Tidak ada stok menipis.');
          }
          return Column(
            children: List.generate(_products.length, (index) {
              final product = _products[index];
              return Column(
                children: [
                  _LowStockTile(product: product),
                  if (index != _products.length - 1) const Divider(height: 18),
                ],
              );
            }),
          );
        },
      ),
    );
  }
}

class _LowStockTile extends StatelessWidget {
  const _LowStockTile({required this.product});

  final DashboardLowStockProduct product;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: DashboardPage._warningColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.warehouse_outlined,
            color: DashboardPage._warningColor,
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DashboardPage._textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                product.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DashboardPage._mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${product.stock}/${product.minimumStock} ${product.unit}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: DashboardPage._warningColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RecentTransactionsSection extends StatefulWidget {
  const _RecentTransactionsSection({super.key});

  @override
  State<_RecentTransactionsSection> createState() =>
      _RecentTransactionsSectionState();
}

class _RecentTransactionsSectionState
    extends State<_RecentTransactionsSection> {
  final _repository = const HistoryRepository();

  List<HistoryItem> _transactions = [];
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentTransactions();
  }

  Future<void> _loadRecentTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final transactions = await _repository.fetchHistoryItems();
      if (!mounted) {
        return;
      }
      setState(() {
        _transactions = transactions.take(5).toList();
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat transaksi terbaru: $error');
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

  void _openDetail(HistoryItem item) {
    if (item.type == HistoryType.sale) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => SaleDetailPage(saleId: item.id),
        ),
      );
      return;
    }
    if (item.type == HistoryType.service) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ServiceDetailPage(serviceId: item.id),
        ),
      );
      return;
    }
    if (item.type == HistoryType.expense) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (context) => const ExpensesPage()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PhoneDetailPage(phoneId: item.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Transaksi Terbaru',
      child: Builder(
        builder: (context) {
          if (_isLoading) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (_error != null) {
            return _DashboardErrorState(
              message: _error!,
              onRetry: _loadRecentTransactions,
            );
          }

          if (_transactions.isEmpty) {
            return const _EmptyState(message: 'Belum ada transaksi.');
          }

          return Column(
            children: List.generate(_transactions.length, (index) {
              final item = _transactions[index];
              return Column(
                children: [
                  _RecentTransactionTile(
                    item: item,
                    onTap: () => _openDetail(item),
                  ),
                  if (index != _transactions.length - 1)
                    const Divider(height: 18),
                ],
              );
            }),
          );
        },
      ),
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({required this.item, required this.onTap});

  final HistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.type) {
      HistoryType.service => Icons.build_outlined,
      HistoryType.phone => Icons.phone_android_outlined,
      HistoryType.expense => Icons.payments_outlined,
      HistoryType.sale => Icons.point_of_sale_outlined,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DashboardPage._primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: DashboardPage._primaryColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DashboardPage._textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.type.label} - ${formatShortDateTime(item.date)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DashboardPage._mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatRupiah(item.amount),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DashboardPage._textColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DashboardPage._dangerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DashboardPage._dangerColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DashboardPage._dangerColor,
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

class _SalesChartPlaceholder extends StatefulWidget {
  const _SalesChartPlaceholder({super.key});

  @override
  State<_SalesChartPlaceholder> createState() => _SalesChartPlaceholderState();
}

class _SalesChartPlaceholderState extends State<_SalesChartPlaceholder> {
  final _repository = const DashboardRepository();

  List<DashboardChartPoint> _points = [];
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  Future<void> _loadChart() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final snapshot = await _repository.fetchDashboard();
      if (!mounted) {
        return;
      }
      setState(() {
        _points = snapshot.salesChart.take(7).toList();
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Gagal memuat grafik: $error');
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

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Grafik Penjualan',
      child: Builder(
        builder: (context) {
          if (_isLoading) {
            return const SizedBox(
              height: 90,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_error != null) {
            return _DashboardErrorState(message: _error!, onRetry: _loadChart);
          }
          if (_points.isEmpty) {
            return const _EmptyState(message: 'Data penjualan belum tersedia.');
          }
          return _SalesBarChart(points: _points);
        },
      ),
    );
  }
}

class _SalesBarChart extends StatelessWidget {
  const _SalesBarChart({required this.points});

  final List<DashboardChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxAmount = points
        .map((point) => point.omzet)
        .fold<int>(0, (max, amount) => amount > max ? amount : max);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((point) {
          final factor = maxAmount == 0 ? 0.0 : point.omzet / maxAmount;
          final height = 24 + (82 * factor);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatRupiah(point.omzet),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: DashboardPage._mutedColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: height,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: DashboardPage._primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _shortDay(point.day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: DashboardPage._mutedColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _shortDay(String day) {
    if (day.length >= 10) {
      return day.substring(5);
    }
    return day;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DashboardPage._backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: DashboardPage._mutedColor,
          fontWeight: FontWeight.w700,
        ),
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
              color: DashboardPage._textColor,
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

class _ShortcutItem {
  const _ShortcutItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _FinanceItem {
  const _FinanceItem(this.label, this.amount, this.icon);

  final String label;
  final String amount;
  final IconData icon;
}
