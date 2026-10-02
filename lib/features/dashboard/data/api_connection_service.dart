import '../../../core/network/api_client.dart';

class ApiConnectionService {
  const ApiConnectionService();

  Future<ApiConnectionStatus> checkApiConnection() async {
    try {
      final response = await ApiClient.getJson('/', requiresApiKey: false);
      final data = response['data'];

      if (data is! Map<String, dynamic>) {
        return const ApiConnectionStatus.disconnected(
          'Response API tidak valid.',
        );
      }

      final name = data['name']?.toString();
      final version = data['version']?.toString();
      if (name != 'QQ Jaya Cell API' || version == null || version.isEmpty) {
        return const ApiConnectionStatus.disconnected(
          'Identitas API tidak sesuai.',
        );
      }

      final apiName = name ?? '';
      final apiVersion = version;
      return ApiConnectionStatus.connected(
        apiName: apiName,
        apiVersion: apiVersion,
      );
    } on ApiException catch (error) {
      return ApiConnectionStatus.disconnected(error.message);
    } catch (error) {
      return ApiConnectionStatus.disconnected(error.toString());
    }
  }
}

class ApiConnectionStatus {
  const ApiConnectionStatus._({
    required this.isConnected,
    required this.message,
    this.apiName,
    this.apiVersion,
  });

  const ApiConnectionStatus.checking()
    : this._(isConnected: false, message: 'Memeriksa koneksi...');

  const ApiConnectionStatus.connected({
    required String apiName,
    required String apiVersion,
  }) : this._(
         isConnected: true,
         message: 'Terhubung',
         apiName: apiName,
         apiVersion: apiVersion,
       );

  const ApiConnectionStatus.disconnected(String reason)
    : this._(isConnected: false, message: 'Tidak terhubung: $reason');

  final bool isConnected;
  final String message;
  final String? apiName;
  final String? apiVersion;
}
