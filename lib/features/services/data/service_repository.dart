import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';

class ServiceRepository {
  const ServiceRepository();

  static const _uuid = Uuid();

  Future<List<ServiceJob>> fetchServices({String? status}) async {
    final query = status == null ? '' : '?status=$status';
    final response = await ApiClient.getJson('/api/services$query');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response servis tidak valid.');
    }
    final services = data['services'];
    if (services is! List) {
      throw const ApiException('Data servis tidak valid.');
    }
    return services
        .whereType<Map<String, dynamic>>()
        .map(ServiceJob.fromJson)
        .toList();
  }

  Future<List<ServicePreset>> fetchPresets({String search = ''}) async {
    final suffix = search.trim().isEmpty
        ? ''
        : '?search=${Uri.encodeQueryComponent(search.trim())}';
    final response = await ApiClient.getJson('/api/service-presets$suffix');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response preset servis tidak valid.');
    }
    final presets = data['presets'];
    if (presets is! List) {
      throw const ApiException('Data preset servis tidak valid.');
    }
    return presets
        .whereType<Map<String, dynamic>>()
        .map(ServicePreset.fromJson)
        .toList();
  }

  Future<ServiceDetail> fetchServiceDetail(String id) async {
    final response = await ApiClient.getJson('/api/services/$id');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response detail servis tidak valid.');
    }
    return ServiceDetail.fromJson(data);
  }

  Future<ServiceDetail> createService({
    required String deviceName,
    required String serviceName,
    required int servicePrice,
    required int deliveryCost,
    required String customerName,
    required bool hasWarranty,
    required ServiceInitialPayment initialPayment,
    required int downPayment,
  }) async {
    final total = servicePrice + deliveryCost;
    final initialAmount = switch (initialPayment) {
      ServiceInitialPayment.unpaid => 0,
      ServiceInitialPayment.downPayment => downPayment,
      ServiceInitialPayment.paid => total,
    };
    final paymentType = switch (initialPayment) {
      ServiceInitialPayment.unpaid => null,
      ServiceInitialPayment.downPayment => 'down_payment',
      ServiceInitialPayment.paid => 'full',
    };

    final response = await ApiClient.postJson(
      '/api/services',
      data: {
        'id': _uuid.v4(),
        'device_name': deviceName,
        'service_name': serviceName,
        'service_price': servicePrice,
        'parts_cost': 0,
        'delivery_cost': deliveryCost,
        if (customerName.trim().isNotEmpty)
          'customer_name': customerName.trim(),
        'service_status': 'in',
        if (hasWarranty) ...{'warranty_value': 24, 'warranty_unit': 'hour'},
        'initial_payment': initialAmount,
        if (initialAmount > 0) 'payment_method': 'cash',
        if (initialAmount > 0) 'payment_type': paymentType,
      },
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response simpan servis tidak valid.');
    }
    return ServiceDetail.fromJson(data);
  }

  Future<ServiceDetail> updateStatus({
    required String id,
    required ServiceStatus status,
  }) async {
    final response = await ApiClient.patchJson(
      '/api/services/$id/status',
      data: {'status': status.apiValue},
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response update status tidak valid.');
    }
    return ServiceDetail.fromJson(data);
  }

  Future<ServiceDetail> addPayment({
    required String id,
    required int amount,
    required bool settlement,
  }) async {
    final response = await ApiClient.postJson(
      '/api/services/$id/payments',
      data: {
        'id': _uuid.v4(),
        'amount': amount,
        'payment_method': 'cash',
        'payment_type': settlement ? 'settlement' : 'down_payment',
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response pembayaran servis tidak valid.');
    }
    return ServiceDetail.fromJson(data);
  }
}

enum ServiceStatus {
  incoming('in', 'Masuk'),
  waiting('waiting', 'Menunggu'),
  working('working', 'Dikerjakan'),
  completed('completed', 'Selesai');

  const ServiceStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ServiceStatus fromApi(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return switch (text) {
      'waiting' || 'menunggu' => ServiceStatus.waiting,
      'working' ||
      'dikerjakan' ||
      'process' ||
      'processing' => ServiceStatus.working,
      'completed' || 'selesai' || 'done' => ServiceStatus.completed,
      _ => ServiceStatus.incoming,
    };
  }
}

enum ServicePaymentStatus {
  unpaid('unpaid', 'Belum Bayar'),
  downPayment('down_payment', 'DP'),
  paid('paid', 'Lunas');

  const ServicePaymentStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ServicePaymentStatus fromApi(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return switch (text) {
      'down_payment' ||
      'dp' ||
      'partial' ||
      'belum lunas' => ServicePaymentStatus.downPayment,
      'paid' || 'full' || 'lunas' => ServicePaymentStatus.paid,
      _ => ServicePaymentStatus.unpaid,
    };
  }
}

enum ServiceInitialPayment { unpaid, downPayment, paid }

class ServiceJob {
  const ServiceJob({
    required this.id,
    required this.serviceNumber,
    required this.deviceName,
    required this.serviceName,
    required this.customerName,
    required this.servicePrice,
    required this.deliveryCost,
    required this.totalPaid,
    required this.remainingPayment,
    required this.status,
    required this.paymentStatus,
    required this.receivedAt,
    required this.warrantyValue,
    required this.warrantyUnit,
    required this.warrantyStartedAt,
    required this.warrantyEndsAt,
  });

  final String id;
  final String serviceNumber;
  final String deviceName;
  final String serviceName;
  final String customerName;
  final int servicePrice;
  final int deliveryCost;
  final int totalPaid;
  final int remainingPayment;
  final ServiceStatus status;
  final ServicePaymentStatus paymentStatus;
  final DateTime receivedAt;
  final int? warrantyValue;
  final String? warrantyUnit;
  final DateTime? warrantyStartedAt;
  final DateTime? warrantyEndsAt;

  int get invoiceTotal => servicePrice + deliveryCost;
  bool get isActive => status != ServiceStatus.completed;
  String get warrantyLabel {
    if (warrantyValue == null || warrantyUnit == null) {
      return 'Tidak Ada';
    }
    if (warrantyValue == 24 && warrantyUnit == 'hour') {
      return '1 x 24 Jam';
    }
    return '$warrantyValue ${warrantyUnit == 'day' ? 'hari' : 'jam'}';
  }

  bool get hasWarranty => warrantyValue != null && warrantyUnit != null;

  factory ServiceJob.fromJson(Map<String, dynamic> json) {
    return ServiceJob(
      id: json['id']?.toString() ?? '',
      serviceNumber: json['service_number']?.toString() ?? '',
      deviceName:
          (json['device_name'] ?? json['device'] ?? json['phone_model'])
              ?.toString() ??
          '',
      serviceName:
          (json['service_name'] ?? json['work'] ?? json['job_name'])
              ?.toString() ??
          '',
      customerName: json['customer_name']?.toString() ?? '',
      servicePrice: parseMoney(json['service_price'] ?? json['service_cost']),
      deliveryCost: parseMoney(json['delivery_cost'] ?? json['shipping_cost']),
      totalPaid: parseMoney(json['total_paid'] ?? json['paid']),
      remainingPayment: parseMoney(
        json['remaining_payment'] ?? json['remaining'],
      ),
      status: ServiceStatus.fromApi(json['service_status']),
      paymentStatus: ServicePaymentStatus.fromApi(json['payment_status']),
      receivedAt: parseBackendDateTime(
        json['received_at'] ?? json['created_at'],
      ),
      warrantyValue: json['warranty_value'] == null
          ? null
          : parseIntValue(json['warranty_value']),
      warrantyUnit: json['warranty_unit']?.toString(),
      warrantyStartedAt: json['warranty_started_at'] == null
          ? null
          : parseBackendDateTime(json['warranty_started_at']),
      warrantyEndsAt: json['warranty_ends_at'] == null
          ? null
          : parseBackendDateTime(json['warranty_ends_at']),
    );
  }

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return serviceNumber.toLowerCase().contains(normalized) ||
        deviceName.toLowerCase().contains(normalized) ||
        serviceName.toLowerCase().contains(normalized) ||
        customerName.toLowerCase().contains(normalized);
  }
}

class ServiceDetail {
  const ServiceDetail({required this.service, required this.payments});

  final ServiceJob service;
  final List<ServicePayment> payments;

  factory ServiceDetail.fromJson(Map<String, dynamic> json) {
    final service = json['service'];
    if (service is! Map<String, dynamic>) {
      throw const ApiException('Data servis tidak valid.');
    }
    final payments = json['payments'];
    if (payments is! List) {
      throw const ApiException('Data pembayaran servis tidak valid.');
    }
    return ServiceDetail(
      service: ServiceJob.fromJson(service),
      payments: payments
          .whereType<Map<String, dynamic>>()
          .map(ServicePayment.fromJson)
          .toList(),
    );
  }
}

class ServicePayment {
  const ServicePayment({
    required this.id,
    required this.type,
    required this.method,
    required this.amount,
    required this.paidAt,
  });

  final String id;
  final String type;
  final String method;
  final int amount;
  final DateTime paidAt;

  String get typeLabel {
    return switch (type) {
      'full' => 'Lunas',
      'settlement' => 'Pelunasan',
      _ => 'DP',
    };
  }

  factory ServicePayment.fromJson(Map<String, dynamic> json) {
    return ServicePayment(
      id: json['id']?.toString() ?? '',
      type: json['payment_type']?.toString() ?? '',
      method: json['payment_method']?.toString() ?? '',
      amount: parseMoney(json['amount']),
      paidAt: parseBackendDateTime(json['paid_at']),
    );
  }
}

class ServicePreset {
  const ServicePreset({
    required this.deviceName,
    required this.serviceName,
    required this.servicePrice,
  });

  final String deviceName;
  final String serviceName;
  final int servicePrice;

  factory ServicePreset.fromJson(Map<String, dynamic> json) {
    return ServicePreset(
      deviceName: json['device_name']?.toString() ?? '',
      serviceName: json['service_name']?.toString() ?? '',
      servicePrice: parseMoney(json['service_price']),
    );
  }
}
