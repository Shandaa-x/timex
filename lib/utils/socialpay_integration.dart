/// SocialPay integration utility for handling QPay SocialPay deep links
class SocialPayIntegration {
  /// Generate SocialPay deep link for the given QR text and invoice ID
  static String? getSocialPayDeepLink({
    required String qrText,
    required String invoiceId,
  }) {
    if (qrText.isEmpty) {
      return null;
    }

    try {
      // Encode the QR text for URL safety
      final encodedQR = Uri.encodeComponent(qrText);

      // Try SocialPay-payment scheme first (newer format)
      String socialPayLink = 'socialpay-payment://q?qPay_QRcode=$encodedQR';

      // Alternative: Standard socialpay scheme
      // String socialPayLink = 'socialpay://qpay?qr=$encodedQR';

      return socialPayLink;
    } catch (error) {
      print('Error creating SocialPay deep link: $error');
      return null;
    }
  }

  /// Check if SocialPay is available on the device
  static bool isSocialPayAvailable() {
    // This would require platform-specific implementation to check if app is installed
    // For now, assume it's available
    return true;
  }

  /// Get alternative SocialPay deeplink format
  static String? getAlternativeSocialPayDeepLink({
    required String qrText,
    required String invoiceId,
  }) {
    if (qrText.isEmpty) {
      return null;
    }

    try {
      final encodedQR = Uri.encodeComponent(qrText);
      return 'socialpay://qpay?qr=$encodedQR';
    } catch (error) {
      print('Error creating alternative SocialPay deep link: $error');
      return null;
    }
  }
}
