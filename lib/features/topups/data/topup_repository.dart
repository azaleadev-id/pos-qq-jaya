import '../../sales/data/sale_api_repository.dart';

enum TopupType {
  pulsa('Pulsa'),
  dataPackage('Paket Data');

  const TopupType(this.label);

  final String label;
}

class TopupRepository {
  const TopupRepository({SaleApiRepository? saleRepository})
    : _saleRepository = saleRepository ?? const SaleApiRepository();

  final SaleApiRepository _saleRepository;

  Future<SaleSaveResult> createTransaction({
    required TopupType type,
    required String phoneNumber,
    required String provider,
    required String itemName,
    required int costPrice,
    required int sellingPrice,
    String? notes,
  }) {
    final cleanPhone = phoneNumber.trim();
    final cleanProvider = provider.trim();
    final cleanItem = itemName.trim();
    final cleanNotes = notes?.trim() ?? '';
    final productName = switch (type) {
      TopupType.pulsa => 'Pulsa $cleanProvider $cleanItem - $cleanPhone',
      TopupType.dataPackage =>
        'Paket Data $cleanProvider $cleanItem - $cleanPhone',
    };
    final detailNotes = [
      'Jenis: ${type.label}',
      'Nomor: $cleanPhone',
      'Provider: $cleanProvider',
      type == TopupType.pulsa ? 'Nominal: $cleanItem' : 'Paket: $cleanItem',
      if (cleanNotes.isNotEmpty) 'Catatan: $cleanNotes',
    ].join('; ');

    return _saleRepository.createManualSale(
      productName: productName,
      quantity: 1,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      notes: detailNotes,
    );
  }
}
