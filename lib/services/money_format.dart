/// Service for formatting money amounts in Mongolian Tugrik (₮)
/// Provides consistent formatting across the application
class MoneyFormatService {
  /// Formats an integer amount to a string with thousands separators and decimal places
  /// 
  /// Example: 15000 -> "15,000.00"
  /// Example: 1234567 -> "1,234,567.00"
  /// Example: 0 -> "0.00"
  static String format(int amount) {
    if (amount == 0) {
      return '0.00';
    }
    
    // Convert to string and add decimal places
    final String amountStr = amount.toString();
    
    // Add thousands separators
    String formattedAmount = '';
    int digitCount = 0;
    
    // Process digits from right to left
    for (int i = amountStr.length - 1; i >= 0; i--) {
      if (digitCount > 0 && digitCount % 3 == 0) {
        formattedAmount = ',$formattedAmount';
      }
      formattedAmount = amountStr[i] + formattedAmount;
      digitCount++;
    }
    
    // Add decimal places
    return '$formattedAmount.00';
  }
  
  /// Formats an integer amount with the tugrik symbol (₮)
  /// 
  /// Example: 15000 -> "₮15,000.00"
  static String formatWithSymbol(int amount) {
    return '₮${format(amount)}';
  }
  
  /// Formats a double amount to a string with thousands separators and two decimal places
  /// 
  /// Example: 15000.50 -> "15,000.50"
  /// Example: 1234567.89 -> "1,234,567.89"
  static String formatDouble(double amount) {
    // Round to 2 decimal places
    final roundedAmount = (amount * 100).round() / 100;
    
    // Split into integer and decimal parts
    final parts = roundedAmount.toStringAsFixed(2).split('.');
    final integerPart = int.parse(parts[0]);
    final decimalPart = parts[1];
    
    // Format integer part with thousands separators
    final formattedInteger = _formatIntegerPart(integerPart);
    
    return '$formattedInteger.$decimalPart';
  }
  
  /// Formats a double amount with the tugrik symbol (₮)
  /// 
  /// Example: 15000.50 -> "₮15,000.50"
  static String formatDoubleWithSymbol(double amount) {
    return '₮${formatDouble(amount)}';
  }
  
  /// Helper method to format the integer part with thousands separators
  static String _formatIntegerPart(int amount) {
    if (amount == 0) {
      return '0';
    }
    
    final String amountStr = amount.toString();
    String formattedAmount = '';
    int digitCount = 0;
    
    // Process digits from right to left
    for (int i = amountStr.length - 1; i >= 0; i--) {
      if (digitCount > 0 && digitCount % 3 == 0) {
        formattedAmount = ',$formattedAmount';
      }
      formattedAmount = amountStr[i] + formattedAmount;
      digitCount++;
    }
    
    return formattedAmount;
  }
  
  /// Formats a balance that can be positive or negative
  /// 
  /// Example: 15000 -> "₮15,000.00"
  /// Example: -5000 -> "-₮5,000.00"
  static String formatBalance(double balance) {
    if (balance >= 0) {
      return formatDoubleWithSymbol(balance);
    } else {
      return '-₮${formatDouble(-balance)}';
    }
  }
}
