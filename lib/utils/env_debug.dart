import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

/// Environment debugging utilities for QPay integration
class EnvDebug {
  /// Check the status of environment variables
  static Map<String, dynamic> checkEnvironmentStatus() {
    AppLogger.info('🔍 Checking environment variables status...');

    try {
      // Check if dotenv is loaded
      final qpayMode = dotenv.env['QPAY_MODE'];
      final qpayUsername = dotenv.env['QPAY_USERNAME'];
      final qpayPassword = dotenv.env['QPAY_PASSWORD'];
      final qpayTemplate = dotenv.env['QPAY_TEMPLATE'];
      final qpayCallbackUrl = dotenv.env['QPAY_CALLBACK_URL'];

      final status = {
        'dotenv_loaded': qpayMode != null,
        'variables': {
          'QPAY_MODE': qpayMode ?? 'NOT_SET',
          'QPAY_USERNAME': qpayUsername != null
              ? '${qpayUsername.substring(0, 3)}***'
              : 'NOT_SET',
          'QPAY_PASSWORD': qpayPassword != null ? '***' : 'NOT_SET',
          'QPAY_TEMPLATE': qpayTemplate ?? 'NOT_SET',
          'QPAY_CALLBACK_URL': qpayCallbackUrl ?? 'NOT_SET',
        },
        'urls': {
          'QPAY_URL': dotenv.env['QPAY_URL'] ?? 'NOT_SET',
          'QPAY_TEST_URL': dotenv.env['QPAY_TEST_URL'] ?? 'NOT_SET',
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      AppLogger.info('✅ Environment check completed');
      return status;
    } catch (error) {
      AppLogger.error('❌ Environment check failed: $error');
      return {
        'dotenv_loaded': false,
        'error': error.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Reload environment variables
  static Future<Map<String, dynamic>> reloadEnvironment() async {
    AppLogger.info('🔄 Reloading environment variables...');

    try {
      await dotenv.load(fileName: '.env');
      AppLogger.success('✅ Environment variables reloaded successfully');
      return {
        'success': true,
        'message': 'Environment variables reloaded successfully',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      AppLogger.error('❌ Failed to reload environment variables: $error');
      return {
        'success': false,
        'error': error.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Print environment debug information
  static void printDebugInfo() {
    final status = checkEnvironmentStatus();

    print('🔍 Environment Debug Information:');
    print('================================');
    print('DotEnv Loaded: ${status['dotenv_loaded']}');
    print('');

    if (status['variables'] != null) {
      print('Variables:');
      final variables = status['variables'] as Map<String, dynamic>;
      variables.forEach((key, value) {
        print('  $key: $value');
      });
      print('');
    }

    if (status['urls'] != null) {
      print('URLs:');
      final urls = status['urls'] as Map<String, dynamic>;
      urls.forEach((key, value) {
        print('  $key: $value');
      });
      print('');
    }

    if (status['error'] != null) {
      print('Error: ${status['error']}');
      print('');
    }

    print('Timestamp: ${status['timestamp']}');
    print('================================');
  }
}
