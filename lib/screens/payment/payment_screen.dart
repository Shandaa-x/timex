import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/money_format.dart';
import '../../services/qpay_helper_service.dart';
import '../../services/user_payment_service.dart';
import '../../services/lifecycle_payment_service.dart';
import '../../utils/qr_utils.dart';
import '../../utils/banking_app_checker.dart';
import '../../widgets/beautiful_circular_progress.dart';
import '../../widgets/payment_status_bottom_sheet.dart';
import '../../models/food_payment_models.dart';
import '../../services/integrated_food_payment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class PaymentScreen extends StatefulWidget {
  final int? initialAmount;
  final Map<String, dynamic>? invoiceData;
  final Function(Map<String, dynamic>)? onPaymentComplete;
  final List<FoodItem>? foodItems;

  const PaymentScreen({
    super.key,
    this.initialAmount,
    this.invoiceData,
    this.onPaymentComplete,
    this.foodItems,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  double _enteredAmount = 0.0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _availableBanks = [];
  double _currentBalance = 0.0;
  String _currentPaymentStatus = 'none';
  bool _showBankOptions = false;
  bool _isProcessingPayment = false;
  String? _validationError;
  bool _isValidAmount = false;

  // Enhanced lifecycle payment service
  final LifecyclePaymentService _lifecyclePaymentService =
      LifecyclePaymentService();

  // Invoice tracking variables
  String? _currentInvoiceId;
  String? _currentOrderId;
  String? _currentAccessToken;
  Map<String, dynamic>? _selectedBank;
  Map<String, dynamic>? _qpayResult;

  // Bank data with proper icons and information matching the design
  final List<Map<String, dynamic>> _bankData = [
    {
      'name': 'Khan Bank',
      'mongolianName': 'Хаан банк',
      'icon': 'assets/images/khan.jpg',
      'packageName': 'mn.khan.bank',
      'scheme': 'khanbank://',
    },
    {
      'name': 'State Bank',
      'mongolianName': 'Төрийн банк 3.0',
      'icon': 'assets/images/state.png',
      'packageName': 'mn.statebank',
      'scheme': 'statebank://',
    },
    {
      'name': 'Xac Bank',
      'mongolianName': 'Хас банк',
      'icon': 'assets/images/xac.png',
      'packageName': 'mn.xac.bank',
      'scheme': 'xacbank://',
    },
    {
      'name': 'TDB Bank',
      'mongolianName': 'TDB online',
      'icon': 'assets/images/tdb.png',
      'packageName': 'mn.tdb.online',
      'scheme': 'tdbbank://',
    },
    {
      'name': 'SocialPay',
      'mongolianName': 'Сошиал Пэй',
      'icon': 'assets/images/socialpay.png',
      'packageName': 'mn.socialpay.app',
      'scheme': 'socialpay://',
    },
    {
      'name': 'Most Money',
      'mongolianName': 'МОСТ мони',
      'icon': 'assets/images/mostmoney.webp',
      'packageName': 'mn.most.money',
      'scheme': 'most://',
    },
    {
      'name': 'Trade Bank',
      'mongolianName': 'Үндэсний хөрөнгө оруулалтын банк',
      'icon': 'assets/images/mbank.png',
      'packageName': 'mn.trade.bank',
      'scheme': 'tradebank://',
    },
    {
      'name': 'Chinggis Khaan Bank',
      'mongolianName': 'Чингис Хаан банк',
      'icon': 'assets/images/toki.webp',
      'packageName': 'mn.chinggisnbank',
      'scheme': 'chinggisnbank://',
    },
    {
      'name': 'Capitron Bank',
      'mongolianName': 'Капитрон банк',
      'icon': 'assets/images/kapitron.webp',
      'packageName': 'mn.capitron.bank',
      'scheme': 'capitronbank://',
    },
    {
      'name': 'Bogd Bank',
      'mongolianName': 'Богд банк',
      'icon': 'assets/images/bogd.webp',
      'packageName': 'mn.bogd.bank',
      'scheme': 'bogdbank://',
    },
    {
      'name': 'Ard Bank',
      'mongolianName': 'Ард банк',
      'icon': 'assets/images/ard.webp',
      'packageName': 'mn.ard.bank',
      'scheme': 'ardbank://',
    },
    {
      'name': 'Arig Bank',
      'mongolianName': 'Ариг банк',
      'icon': 'assets/images/arig.webp',
      'packageName': 'mn.arig.bank',
      'scheme': 'arigbank://',
    },
    {
      'name': 'Trans Bank',
      'mongolianName': 'Транс банк',
      'icon': 'assets/images/trans.webp',
      'packageName': 'mn.trans.bank',
      'scheme': 'transbank://',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount.toString();
      _enteredAmount = widget.initialAmount!.toDouble();
    }

    // Initialize lifecycle payment service
    _lifecyclePaymentService.initialize();

    _loadAvailableBanks();
    _ensureUserDocument();
    _loadCurrentBalance();
  }

  Future<void> _ensureUserDocument() async {
    await UserPaymentService.ensureUserDocument();
  }

  /// Always fetch current balance from Firestore to ensure accuracy
  Future<void> _loadCurrentBalance() async {
    final paymentInfo = await UserPaymentService.getUserPaymentInfo();
    if (paymentInfo['success'] == true) {
      setState(() {
        _currentBalance = paymentInfo['totalFoodAmount'] ?? 0.0;
        _currentPaymentStatus = paymentInfo['qpayStatus'] ?? 'none';

        // Re-validate current entered amount with new balance
        _validatePaymentAmount();
        _showBankOptions = _isValidAmount && _enteredAmount > 0;
      });
    }
  }

  void _onAmountChanged(String value) {
    setState(() {
      _enteredAmount = double.tryParse(value) ?? 0.0;
      _validatePaymentAmount();
      _showBankOptions = _isValidAmount && _enteredAmount > 0;
    });
  }

  /// Validate payment amount against remaining balance
  void _validatePaymentAmount() {
    _validationError = null;
    _isValidAmount = false;

    if (_enteredAmount <= 0) {
      _validationError = 'Please enter a valid amount';
      return;
    }

    if (_currentBalance <= 0) {
      _validationError = 'No balance remaining to pay';
      return;
    }

    if (_enteredAmount > _currentBalance) {
      _validationError =
          'Amount cannot exceed remaining balance of ₮${_currentBalance.toStringAsFixed(0)}';
      return;
    }

    // Valid amount
    _isValidAmount = true;
  }

  /// Auto-adjust amount to maximum allowed (remaining balance)
  void _setMaxAmount() {
    if (_currentBalance > 0) {
      _amountController.text = _currentBalance.toStringAsFixed(0);
      _onAmountChanged(_amountController.text);
    }
  }

  Future<void> _loadAvailableBanks() async {
    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> availableBanks = [];

      for (final bank in _bankData) {
        // Always assume banks are available - let the user try them
        // canLaunchUrl checks are unreliable and may prevent working apps
        bool isAvailable = true;
        String availabilityNote = '';

        // Don't do preemptive canLaunchUrl checks as they're unreliable
        // and often return false negatives for working banking apps
        debugPrint('📱 Adding bank to available list: ${bank['name']}');

        // Add bank with availability info
        final bankWithInfo = Map<String, dynamic>.from(bank);
        bankWithInfo['availabilityNote'] = availabilityNote;
        bankWithInfo['isAvailable'] = isAvailable;
        availableBanks.add(bankWithInfo);
      }

      setState(() {
        _availableBanks = availableBanks;
      });

      debugPrint(
        '📱 Available banks: ${availableBanks.map((b) => '${b['name']}${b['availabilityNote']}')}',
      );
    } catch (e) {
      debugPrint('Error loading banks: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processPayment(Map<String, dynamic> bank) async {
    // Refresh balance before processing payment to ensure accuracy
    await _loadCurrentBalance();

    if (!_isValidAmount || _enteredAmount <= 0) {
      _showSnackBar(_validationError ?? 'Please enter a valid amount', true);
      return;
    }

    if (_enteredAmount > _currentBalance) {
      _showSnackBar('Payment amount exceeds remaining balance', true);
      return;
    }

    setState(() {
      _isProcessingPayment = true;
      _selectedBank = bank;
    });

    try {
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      final String userUid = currentUser?.uid ?? 'unknown';
      final String orderId =
          'TIMEX_PAYMENT_${DateTime.now().millisecondsSinceEpoch}';

      // Create QPay invoice
      final result = await QPayHelperService.createInvoiceWithQR(
        amount: _enteredAmount,
        orderId: orderId,
        userId: userUid,
        invoiceDescription:
            'TIMEX Payment - ₮${_enteredAmount.toStringAsFixed(0)}',
        enableSocialPay: true,
        callbackUrl: 'http://localhost:3000/qpay/webhook',
      );

      if (result['success'] == true) {
        final invoice = result['invoice'];
        final qrText = invoice['qr_text'] ?? '';
        final invoiceId = invoice['invoice_id'];

        // Store invoice details for status checking
        _currentInvoiceId = invoiceId;
        _currentOrderId = orderId;
        _currentAccessToken = result['access_token'];

        // Store the QPay result for advanced banking app detection
        _qpayResult = invoice;

        // Start lifecycle tracking with the payment service
        _lifecyclePaymentService.startTrackingPayment(
          invoiceId: invoiceId,
          accessToken: _currentAccessToken!,
        );

        // Try to launch banking app
        await _launchMobileBankingApp(bank, qrText, invoiceId);

        // Show enhanced payment status bottom sheet immediately
        if (mounted) {
          _showPaymentStatusBottomSheet(bank);
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to create QPay invoice');
      }
    } catch (e) {
      print('Payment error: $e');
      _showSnackBar('Payment failed: $e', true);
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  /// Launch deep link to mobile banking app with robust fallback system
  Future<void> _launchMobileBankingApp(
    Map<String, dynamic> bank,
    String qrText,
    String invoiceId,
  ) async {
    try {
      // Special handling for SocialPay first
      if (bank['name'] == 'SocialPay' ||
          bank['mongolianName']?.contains('Сошиал') == true) {
        await _launchSocialPay(qrText, invoiceId);
        return;
      }

      // Try QPay response banking apps first (most reliable)
      final bankingApps = QRUtils.extractBankingApps(_qpayResult ?? {});
      print('🔍 Found ${bankingApps.length} banking apps from QPay response');

      // Try to find a matching bank from QPay response
      String? matchingDeepLink;
      String? matchingBankName;

      for (final entry in bankingApps.entries) {
        final app = entry.value;
        final bankName = bank['name']?.toString().toLowerCase() ?? '';
        final mongolianName =
            bank['mongolianName']?.toString().toLowerCase() ?? '';

        // Check if this QPay bank matches our selected bank
        if (_bankMatches(app.name, bankName, mongolianName)) {
          matchingDeepLink = app.deepLink;
          matchingBankName = app.name;
          print('✅ Found matching bank: ${app.name} -> ${app.deepLink}');
          break;
        }
      }

      // Try the matching deep link from QPay response
      if (matchingDeepLink != null && matchingBankName != null) {
        if (await _tryLaunchDeepLink(matchingDeepLink, matchingBankName)) {
          return;
        }
      }

      // Fallback: Try multiple schemes for the bank
      final fallbackSchemes = _generateFallbackSchemes(bank, qrText, invoiceId);
      print(
        '🔄 Trying ${fallbackSchemes.length} fallback schemes for ${bank['name']}',
      );

      for (final scheme in fallbackSchemes) {
        if (await _tryLaunchDeepLink(scheme, bank['name'] ?? 'Banking App')) {
          return;
        }
      }

      // Final fallback: Show all available banking apps
      print('🔍 All launch attempts failed, showing banking app options');
      _showBankingAppOptions();
    } catch (error) {
      print('Error in _launchMobileBankingApp: $error');
      _showSnackBar('Failed to open banking app: $error', true);
    }
  }

  /// Special handling for SocialPay with proper deep link format
  Future<void> _launchSocialPay(String qrText, String invoiceId) async {
    final socialPaySchemes = [
      'socialpay-payment://q?qPay_QRcode=${Uri.encodeComponent(qrText)}',
      'socialpay://qpay?qr=${Uri.encodeComponent(qrText)}',
      'socialpay://payment?qr=${Uri.encodeComponent(qrText)}',
      'socialpay://q?qPay_QRcode=${Uri.encodeComponent(qrText)}',
    ];

    print('🔄 Trying ${socialPaySchemes.length} SocialPay schemes');

    for (final scheme in socialPaySchemes) {
      if (await _tryLaunchDeepLink(scheme, 'SocialPay')) {
        return;
      }
    }

    _showSnackBar('SocialPay app not installed or not supported', true);
  }

  /// Check if a QPay bank matches our selected bank
  bool _bankMatches(
    String qpayBankName,
    String selectedBankName,
    String mongolianName,
  ) {
    final qpayLower = qpayBankName.toLowerCase();
    final selectedLower = selectedBankName.toLowerCase();
    final mongolianLower = mongolianName.toLowerCase();

    // Direct name matches
    if (qpayLower.contains(selectedLower) ||
        selectedLower.contains(qpayLower)) {
      return true;
    }

    // Mongolian name matches
    if (mongolianLower.isNotEmpty && qpayLower.contains(mongolianLower)) {
      return true;
    }

    // Special mappings
    final mappings = {
      'khan': ['хаан', 'khan bank'],
      'state': ['төрийн', 'state bank'],
      'xac': ['хас', 'xac bank'],
      'tdb': ['trade', 'development', 'тdб'],
      'most': ['мост', 'most money'],
      'social': ['голомт', 'socialpay', 'social pay'],
      'capitron': ['капитрон', 'capitron bank'],
      'bogd': ['богд', 'bogd bank'],
      'chinggis': ['чингис', 'chinggis khaan'],
      'arig': ['ариг', 'arig bank'],
      'trans': ['тээвэр', 'trans bank'],
    };

    for (final entry in mappings.entries) {
      final key = entry.key;
      final variations = entry.value;

      if (selectedLower.contains(key) || mongolianLower.contains(key)) {
        for (final variation in variations) {
          if (qpayLower.contains(variation)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Generate fallback deep link schemes for a bank
  List<String> _generateFallbackSchemes(
    Map<String, dynamic> bank,
    String qrText,
    String invoiceId,
  ) {
    final schemes = <String>[];
    final encodedQR = Uri.encodeComponent(qrText);
    final bankName = bank['name']?.toString().toLowerCase() ?? '';

    // Add original scheme if available
    if (bank['scheme'] != null) {
      schemes.add('${bank['scheme']}qpay?qr=$encodedQR');
      schemes.add('${bank['scheme']}q?qPay_QRcode=$encodedQR');
    }

    // Add bank-specific schemes
    switch (bankName) {
      case 'khan bank':
        schemes.addAll([
          'khanbank://q?qPay_QRcode=$encodedQR',
          'khanbank://qpay?qr=$encodedQR',
          'khan://qpay?qr=$encodedQR',
          'khanbankapp://payment?qr=$encodedQR',
        ]);
        break;
      case 'state bank':
        schemes.addAll([
          'statebankmongolia://q?qPay_QRcode=$encodedQR',
          'statebank://q?qPay_QRcode=$encodedQR',
          'statebank://qpay?qr=$encodedQR',
          'statebankapp://payment?qr=$encodedQR',
        ]);
        break;
      case 'xac bank':
        schemes.addAll([
          'xacbank://q?qPay_QRcode=$encodedQR',
          'xacbank://qpay?qr=$encodedQR',
          'xac://qpay?qr=$encodedQR',
        ]);
        break;
      case 'tdb bank':
        schemes.addAll([
          'tdbbank://q?qPay_QRcode=$encodedQR',
          'tdbbank://qpay?qr=$encodedQR',
          'tdb://qpay?qr=$encodedQR',
        ]);
        break;
      case 'most money':
        schemes.addAll([
          'most://q?qPay_QRcode=$encodedQR',
          'most://qpay?qr=$encodedQR',
          'mostmoney://payment?qr=$encodedQR',
        ]);
        break;
      default:
        // Generic fallbacks
        final baseName = bankName.replaceAll(' bank', '').replaceAll(' ', '');
        schemes.addAll([
          '$baseName://q?qPay_QRcode=$encodedQR',
          '$baseName://qpay?qr=$encodedQR',
          '${baseName}bank://q?qPay_QRcode=$encodedQR',
        ]);
    }

    return schemes;
  }

  /// Try to launch a deep link and return success status
  Future<bool> _tryLaunchDeepLink(String deepLink, String appName) async {
    try {
      print('🚀 Trying to launch: $deepLink');
      final uri = Uri.parse(deepLink);

      // Try direct launch first (more reliable)
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnackBar('Opened $appName', false);
        print('✅ Successfully launched: $deepLink');
        return true;
      } catch (e) {
        print('❌ Direct launch failed: $e');

        // Try with canLaunchUrl check as fallback
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          _showSnackBar('Opened $appName', false);
          print('✅ Successfully launched with canLaunchUrl: $deepLink');
          return true;
        }
      }
    } catch (error) {
      print('❌ Failed to launch $deepLink: $error');
    }

    return false;
  }

  /// Show available banking app options with enhanced detection
  void _showBankingAppOptions() async {
    if (_qpayResult == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final qrText = _qpayResult!['qr_text'] ?? '';
      final invoiceId = _qpayResult!['invoice_id'];

      // Use optimized banking app detection
      final optimizedLinks = await BankingAppChecker.getOptimizedDeepLinks(
        qrText,
        invoiceId,
      );

      // Get traditional banking apps from QPay response
      final bankingApps = QRUtils.extractBankingApps(_qpayResult!);

      // Fallback to legacy method
      Map<String, String> legacyDeepLinks = {};
      if (bankingApps.isEmpty && optimizedLinks.isEmpty) {
        String? qpayShortUrl;
        if (_qpayResult!['qpay_shortUrl'] != null) {
          qpayShortUrl = _qpayResult!['qpay_shortUrl'].toString();
        } else if (_qpayResult!['urls'] != null) {
          final urls = _qpayResult!['urls'];
          if (urls is List && urls.isNotEmpty) {
            for (final url in urls) {
              if (url is Map && url['link'] != null) {
                final link = url['link'].toString();
                if (link.startsWith('http')) {
                  qpayShortUrl = link;
                  break;
                }
              }
            }
          }
        }

        legacyDeepLinks = QRUtils.generateDeepLinks(
          qrText,
          qpayShortUrl,
          invoiceId,
        );
      }

      Navigator.pop(context); // Close loading dialog

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Banking App',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),

                  // Show optimized banking apps first
                  if (optimizedLinks.isNotEmpty) ...[
                    Text(
                      'Available Banking Apps:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...optimizedLinks.entries.map((entry) {
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            _getBankIcon(entry.key),
                            color: Colors.green,
                            size: 32,
                          ),
                          title: Text(
                            entry.key,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('Tap to open'),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () async {
                            Navigator.pop(context);
                            await _launchBankingApp(entry.value, entry.key);
                          },
                        ),
                      );
                    }).toList(),
                    SizedBox(height: 16),
                  ],

                  // Banking apps from QPay response
                  if (bankingApps.isNotEmpty) ...[
                    Text(
                      'QPay Suggested Apps:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...bankingApps.entries.map((entry) {
                      final app = entry.value;
                      return ListTile(
                        leading: Icon(
                          _getBankIcon(app.name),
                          color: Colors.blue,
                        ),
                        title: Text(app.name),
                        subtitle: Text(
                          app.description.isNotEmpty
                              ? app.description
                              : 'Mobile banking app',
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await _launchBankingApp(app.deepLink, app.name);
                        },
                      );
                    }).toList(),
                    SizedBox(height: 16),
                  ],

                  // Legacy deep links as fallback
                  if (legacyDeepLinks.isNotEmpty) ...[
                    Text(
                      'Other Options:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...legacyDeepLinks.entries.map((entry) {
                      String appName = _getLegacyAppName(entry.key);
                      return ListTile(
                        leading: Icon(
                          _getBankIcon(appName),
                          color: Colors.orange,
                        ),
                        title: Text(appName),
                        subtitle: Text(
                          entry.key == 'banking' ? 'Web browser' : 'Mobile app',
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await _launchBankingApp(entry.value, appName);
                        },
                      );
                    }).toList(),
                  ],

                  SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      Navigator.pop(context); // Close loading dialog
      print('Error showing banking app options: $error');
      _showSnackBar('Failed to load banking apps: $error', true);
    }
  }

  IconData _getBankIcon(String bankName) {
    switch (bankName.toLowerCase()) {
      case 'khan bank':
      case 'khanbank':
        return Icons.account_balance;
      case 'qpay wallet':
      case 'qpay':
        return Icons.payment;
      case 'social pay':
      case 'socialpay':
        return Icons.people;
      case 'state bank':
      case 'statebank':
        return Icons.account_balance_wallet;
      case 'tdb bank':
      case 'tdbbank':
        return Icons.business;
      case 'xac bank':
      case 'xacbank':
        return Icons.monetization_on;
      case 'most money':
      case 'mostmoney':
        return Icons.money;
      case 'nib bank':
      case 'nibbank':
        return Icons.account_balance;
      case 'chinggis khaan bank':
      case 'ckbank':
        return Icons.castle;
      case 'capitron bank':
      case 'capitronbank':
        return Icons.corporate_fare;
      case 'bogd bank':
      case 'bogdbank':
        return Icons.location_city;
      case 'candy pay':
      case 'candypay':
        return Icons.card_giftcard;
      default:
        return Icons.open_in_new;
    }
  }

  String _getLegacyAppName(String key) {
    switch (key) {
      case 'qpay':
        return 'QPay App';
      case 'socialpay':
        return 'Social Pay (Khan Bank)';
      case 'khanbank':
      case 'khanbankalt':
        return 'Khan Bank';
      case 'statebank':
      case 'statebankalt':
        return 'State Bank';
      case 'tdbbank':
      case 'tdb':
        return 'TDB Bank';
      case 'xacbank':
      case 'xac':
        return 'Xac Bank';
      case 'most':
      case 'mostmoney':
        return 'Most Money';
      case 'nibank':
      case 'ulaanbaatarbank':
        return 'NIB Bank';
      case 'ckbank':
      case 'chinggisnbank':
        return 'Chinggis Khaan Bank';
      case 'capitronbank':
      case 'capitron':
        return 'Capitron Bank';
      case 'bogdbank':
      case 'bogd':
        return 'Bogd Bank';
      case 'candypay':
      case 'candy':
        return 'Candy Pay';
      default:
        return 'Banking App';
    }
  }

  Future<void> _launchBankingApp(String deepLink, String appName) async {
    try {
      final uri = Uri.parse(deepLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnackBar('Opened $appName', false);
      } else {
        _showSnackBar('$appName not installed', true);
      }
    } catch (error) {
      print('Error launching $appName: $error');
      _showSnackBar('Invalid link format for $appName', true);
    }
  }

  void _showSnackBar(String message, bool isError) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPaymentStatusBottomSheet(Map<String, dynamic> bank) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => PaymentStatusBottomSheet(
        bankName: bank['mongolianName'] ?? bank['name'],
        amount: _enteredAmount,
        invoiceId: _currentInvoiceId,
        orderId: _currentOrderId,
        accessToken: _currentAccessToken,
        onPaymentCompleted: () {
          // Payment completed successfully
          _handlePaymentSuccess();
        },
        onCancel: () {
          // Payment cancelled, refresh balance
          _loadCurrentBalance();
        },
      ),
    );
  }

  void _handlePaymentSuccess() {
    // Show success message and return to previous screen
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment completed successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Return to previous screen with success result
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _manualPaymentStatusCheck() async {
    // Delegate to lifecycle payment service for consistent status checking
    if (_lifecyclePaymentService.isTrackingPayment) {
      setState(() => _isLoading = true);
      try {
        await _lifecyclePaymentService.forceStatusCheck();
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      _showSnackBar('No active payment to check', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Хэтэвч цэнэглэх',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // Manual payment status check icon
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: _currentInvoiceId != null
                  ? const Color(0xFF10B981)
                  : Colors.grey[400],
            ),
            tooltip: _currentInvoiceId != null
                ? 'Check Payment Status'
                : 'No active payment',
            onPressed: _currentInvoiceId != null
                ? _manualPaymentStatusCheck
                : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Current balance status section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _currentPaymentStatus == 'paid'
                    ? [const Color(0xFF10B981), const Color(0xFF06B6D4)]
                    : _currentPaymentStatus == 'partial'
                    ? [const Color(0xFFF59E0B), const Color(0xFFEF4444)]
                    : [const Color(0xFF6B7280), const Color(0xFF4B5563)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _currentPaymentStatus == 'paid'
                      ? const Color(0xFF10B981).withOpacity(0.3)
                      : _currentPaymentStatus == 'partial'
                      ? const Color(0xFFF59E0B).withOpacity(0.3)
                      : const Color(0xFF6B7280).withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _currentPaymentStatus == 'paid'
                        ? Icons.check_circle_rounded
                        : _currentPaymentStatus == 'partial'
                        ? Icons.payments_rounded
                        : Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentPaymentStatus == 'paid'
                            ? 'Balance Fully Paid'
                            : _currentPaymentStatus == 'partial'
                            ? 'Partial Payment Made'
                            : 'Outstanding Balance',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₮${_currentBalance.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.foodItems != null && widget.foodItems!.isNotEmpty)
                        Text(
                          '${widget.foodItems!.length} food item${widget.foodItems!.length > 1 ? 's' : ''} selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                      else if (_currentPaymentStatus == 'partial')
                        const Text(
                          'You can make another payment',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Amount input section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Enter Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (_currentBalance > 0)
                      TextButton(
                        onPressed: _setMaxAmount,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          backgroundColor: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.1),
                          foregroundColor: const Color(0xFF10B981),
                        ),
                        child: Text(
                          'Max: ₮${_currentBalance.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    // Prevent multiple decimal points
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.split('.').length > 2) {
                        return oldValue;
                      }
                      return newValue;
                    }),
                  ],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter amount to pay',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                    prefixText: '₮ ',
                    prefixStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    suffixIcon: _currentBalance > 0 && _enteredAmount > 0
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _amountController.clear();
                              _onAmountChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _validationError != null
                            ? Colors.red
                            : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _validationError != null
                            ? Colors.red
                            : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _validationError != null
                            ? Colors.red
                            : const Color(0xFF10B981),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    errorText: _validationError,
                    errorStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onChanged: _onAmountChanged,
                ),
                // Payment Amount Status
                if (_enteredAmount > 0 && _validationError == null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount to pay: ${MoneyFormatService.formatWithSymbol(_enteredAmount.round())}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_currentBalance > _enteredAmount)
                        Text(
                          'Remaining: ₮${(_currentBalance - _enteredAmount).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ],
                // Balance Information
                if (_currentBalance <= 0 &&
                    _currentPaymentStatus != 'paid') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange[700],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'No remaining balance. All payments have been completed.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Payment status message
          if (_currentPaymentStatus == 'paid')
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your balance is fully paid! No further payments needed.',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Banks list section - only show after amount is entered
          if (_showBankOptions && _currentPaymentStatus != 'paid') ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Bank',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your preferred bank to complete the payment',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          BeautifulCircularProgress(
                            size: 90,
                            strokeWidth: 5,
                            gradientColors: const [
                              Color(0xFF10B981),
                              Color(0xFF06B6D4),
                              Color(0xFF3B82F6),
                              Color(0xFF1E40AF),
                            ],
                            backgroundColor: const Color(0x1A10B981),
                            centerGlowColor: const Color(0xFF10B981),
                            centerGlowSize: 35,
                            animationDuration: const Duration(seconds: 2),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Loading Banks...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _availableBanks.isEmpty
                  ? const Center(
                      child: Text(
                        'No banking apps available',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _availableBanks.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey[200]),
                      itemBuilder: (context, index) {
                        final bank = _availableBanks[index];
                        return _buildBankTile(bank);
                      },
                    ),
            ),
          ] else ...[
            // Show guidance when no amount is entered
            if (!_showBankOptions && _currentPaymentStatus != 'paid')
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 50,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Enter Payment Amount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Please enter the amount you want to pay\nto see available banking options',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Show "no more payments needed" for fully paid
            if (_currentPaymentStatus == 'paid')
              const Expanded(child: SizedBox.shrink()),
          ],
        ],
      ),
    );
  }

  Widget _buildBankTile(Map<String, dynamic> bank) {
    final isProcessing =
        _isProcessingPayment && _selectedBank?['name'] == bank['name'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isProcessing ? const Color(0xFF10B981) : Colors.grey[200]!,
            width: isProcessing ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.asset(
                bank['icon'],
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey[100],
                    child: Icon(
                      Icons.account_balance,
                      color: Colors.grey[400],
                      size: 28,
                    ),
                  );
                },
              ),
              if (isProcessing)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      title: Text(
        bank['mongolianName'],
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isProcessing ? const Color(0xFF10B981) : Colors.black87,
        ),
      ),
      trailing: isProcessing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            )
          : Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
      onTap: (_isValidAmount && !_isProcessingPayment)
          ? () => _processPayment(bank)
          : null,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _lifecyclePaymentService.dispose();
    super.dispose();
  }
}
