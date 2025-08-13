/// Banking app availability checker for deep links
library banking_app_checker;

import 'package:url_launcher/url_launcher.dart';
import 'logger.dart';

/// Class to check what banking apps are available on the device
class BankingAppChecker {
  
  /// Common Mongolian banking app schemes based on QPay documentation
  static const Map<String, String> bankingAppSchemes = {
    'Khan Bank': 'khanbank://',
    'State Bank': 'statebank://',
    'TDB Bank': 'tdbbank://',
    'Xac Bank': 'xacbank://',
    'Most Money': 'most://',
    'NIB Bank': 'nibank://',
    'Chinggis Khaan Bank': 'ckbank://',
    'Capitron Bank': 'capitronbank://',
    'Bogd Bank': 'bogdbank://',
    'Candy Pay': 'candypay://',
    'QPay Wallet': 'qpay://',
    'Social Pay': 'socialpay://',
  };

  /// Check which banking apps are available on the device
  static Future<Map<String, bool>> checkAvailableBankingApps() async {
    final availabilityMap = <String, bool>{};
    
    AppLogger.info('Checking banking app availability...');
    
    for (final entry in bankingAppSchemes.entries) {
      try {
        final testUri = Uri.parse('${entry.value}test');
        final isAvailable = await canLaunchUrl(testUri);
        availabilityMap[entry.key] = isAvailable;
        
        if (isAvailable) {
          AppLogger.success('${entry.key} is available');
        } else {
          AppLogger.info('${entry.key} not available');
        }
      } catch (error) {
        AppLogger.error('Error checking ${entry.key}', error);
        availabilityMap[entry.key] = false;
      }
    }
    
    final availableCount = availabilityMap.values.where((available) => available).length;
    AppLogger.success('Found $availableCount available banking apps out of ${bankingAppSchemes.length}');
    
    return availabilityMap;
  }
  
  /// Test a specific deep link
  static Future<bool> testDeepLink(String deepLink) async {
    try {
      final uri = Uri.parse(deepLink);
      final canLaunch = await canLaunchUrl(uri);
      AppLogger.info('Deep link test: $deepLink - ${canLaunch ? 'Available' : 'Not available'}');
      return canLaunch;
    } catch (error) {
      AppLogger.error('Error testing deep link: $deepLink', error);
      return false;
    }
  }
  
  /// Get a formatted report of available banking apps
  static Future<String> getAvailabilityReport() async {
    final availability = await checkAvailableBankingApps();
    final report = StringBuffer();
    
    report.writeln('Banking App Availability Report:');
    report.writeln('================================');
    
    for (final entry in availability.entries) {
      final status = entry.value ? '✅ Available' : '❌ Not Available';
      report.writeln('${entry.key}: $status');
    }
    
    return report.toString();
  }
}
