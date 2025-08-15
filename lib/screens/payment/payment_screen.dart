import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/money_format.dart';
import '../../services/qpay_helper_service.dart';
import '../../services/user_payment_service.dart';
import '../../utils/qr_utils.dart';
import '../../utils/banking_app_checker.dart';
import '../../widgets/beautiful_circular_progress.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class PaymentScreen extends StatefulWidget {
  final int? initialAmount;

  const PaymentScreen({super.key, this.initialAmount});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  double _enteredAmount = 0.0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _availableBanks = [];
  double _currentBalance = 0.0;
  double _originalFoodAmount = 0.0;
  String _currentPaymentStatus = 'none';
  bool _showBankOptions = false;
  bool _isProcessingPayment = false;
  String? _validationError;
  bool _isValidAmount = false;

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
        _originalFoodAmount = paymentInfo['originalFoodAmount'] ?? 0.0;
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
      _validationError = 'Amount cannot exceed remaining balance of ₮${_currentBalance.toStringAsFixed(0)}';
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
      
      debugPrint('📱 Available banks: ${availableBanks.map((b) => '${b['name']}${b['availabilityNote']}')}');
    } catch (e) {
      debugPrint('Error loading banks: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _currentInvoiceId;
  String? _currentOrderId;
  String? _currentAccessToken;
  Map<String, dynamic>? _selectedBank;
  Map<String, dynamic>? _qpayResult;

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
        enableSocialPay: true, // Enable SocialPay support
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

        // Try to launch with enhanced bank detection from QR screen
        await _launchMobileBankingApp(bank, qrText, invoiceId);

        // Show payment status bottom sheet immediately
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
  Future<void> _launchMobileBankingApp(Map<String, dynamic> bank, String qrText, String invoiceId) async {
    try {
      // Special handling for SocialPay first
      if (bank['name'] == 'SocialPay' || bank['mongolianName']?.contains('Сошиал') == true) {
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
        final mongolianName = bank['mongolianName']?.toString().toLowerCase() ?? '';
        
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
      print('🔄 Trying ${fallbackSchemes.length} fallback schemes for ${bank['name']}');
      
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
  bool _bankMatches(String qpayBankName, String selectedBankName, String mongolianName) {
    final qpayLower = qpayBankName.toLowerCase();
    final selectedLower = selectedBankName.toLowerCase();
    final mongolianLower = mongolianName.toLowerCase();
    
    // Direct name matches
    if (qpayLower.contains(selectedLower) || selectedLower.contains(qpayLower)) {
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
  List<String> _generateFallbackSchemes(Map<String, dynamic> bank, String qrText, String invoiceId) {
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
      builder: (context) => PaymentStatusBottomSheet(
        bankName: bank['mongolianName'],
        amount: _enteredAmount.round(),
        invoiceId: _currentInvoiceId,
        orderId: _currentOrderId,
        onCheckStatus: _checkPaymentStatus,
      ),
    );
  }

  Future<void> _checkPaymentStatus() async {
    if (_currentInvoiceId == null || _currentAccessToken == null) {
      _showSnackBar('No payment to check', true);
      return;
    }

    try {
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showSnackBar('User not logged in', true);
        return;
      }

      // Check payment status with QPay API
      final paymentResult = await QPayHelperService.checkPayment(
        _currentAccessToken!,
        _currentInvoiceId!,
      );

      if (paymentResult['success'] == true) {
        final int count = paymentResult['count'] ?? 0;

        if (count > 0) {
          // Payment found - extract payment details
          final List<dynamic> rows = paymentResult['rows'] ?? [];
          if (rows.isNotEmpty) {
            final payment = rows[0];
            // Handle both string and numeric payment amounts
            final dynamic rawAmount =
                payment['payment_amount'] ?? payment['paid_amount'] ?? 0.0;

            final double paidAmount = rawAmount is String
                ? double.tryParse(rawAmount) ?? 0.0
                : (rawAmount as num).toDouble();

            // Ensure user document exists before processing payment
            await UserPaymentService.ensureUserDocument(currentUser.uid);
            
            // Process payment with new partial payment logic
            final updateResult = await UserPaymentService.processPayment(
              userId: currentUser.uid,
              paidAmount: paidAmount,
              paymentMethod: 'QPay',
              invoiceId: _currentInvoiceId!,
              orderId: _currentOrderId,
            );

            if (updateResult['success'] == true) {
              final double originalAmount = updateResult['originalAmount'] ?? 0;
              final double newAmount = updateResult['newAmount'] ?? 0;
              final String paymentStatus = updateResult['status'] ?? 'unknown';

              // Refresh the balance display
              await _loadCurrentBalance();

              // Show success dialog with payment details and status
              _showPaymentCompletedDialog(
                paidAmount,
                originalAmount,
                newAmount,
                paymentStatus,
              );
            } else {
              // Log the error details for debugging
              final errorMessage = updateResult['error'] ?? 'Unknown error';
              debugPrint('❌ Balance update failed: $errorMessage');
              debugPrint('🔍 Full result: $updateResult');
              
              _showSnackBar(
                'Payment verified but failed to update balance: $errorMessage',
                true,
              );
            }
          } else {
            _showSnackBar('Payment data not found', true);
          }
        } else {
          // No payment found - update status to pending
          await UserPaymentService.updatePaymentStatus(
            userId: currentUser.uid,
            status: 'pending',
          );

          _showSnackBar('Payment is still pending...', true);
        }
      } else {
        throw Exception(
          paymentResult['error'] ?? 'Failed to check payment status',
        );
      }
    } catch (e) {
      print('Payment check error: $e');
      _showSnackBar('Failed to check payment status: $e', true);

      // Update status to pending on error
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await UserPaymentService.updatePaymentStatus(
            userId: currentUser.uid,
            status: 'pending',
          );
        }
      } catch (firestoreError) {
        print('Failed to update Firestore status: $firestoreError');
      }
    }
  }

  Future<void> _manualPaymentStatusCheck() async {
    if (_currentInvoiceId == null || _currentAccessToken == null) {
      // No active payment to check
      _showSnackBar('No active payment to check', true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _checkPaymentStatus();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPaymentCompletedDialog(
    double paidAmount,
    double originalAmount,
    double newAmount,
    String paymentStatus,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  paymentStatus == 'paid'
                      ? 'Payment Completed!'
                      : 'Payment Processed!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Status message
                Text(
                  paymentStatus == 'paid'
                      ? 'Your balance is now fully paid!'
                      : 'Your payment has been processed.',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Payment details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildPaymentDetailRow(
                        'Amount Paid',
                        '₮${paidAmount.toStringAsFixed(0)}',
                      ),
                      const SizedBox(height: 8),
                      _buildPaymentDetailRow(
                        'Previous Balance',
                        '₮${originalAmount.toStringAsFixed(0)}',
                      ),
                      const SizedBox(height: 8),
                      _buildPaymentDetailRow(
                        'New Balance',
                        '₮${newAmount.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Close bottom sheet
                      Navigator.of(context).pop(
                        true,
                      ); // Go back to previous screen with success result
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
                      if (_currentPaymentStatus == 'partial')
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        color: _validationError != null ? Colors.red : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _validationError != null ? Colors.red : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _validationError != null ? Colors.red : const Color(0xFF10B981),
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
                if (_currentBalance <= 0 && _currentPaymentStatus != 'paid') ...[
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
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
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
    super.dispose();
  }
}

class PaymentStatusBottomSheet extends StatefulWidget {
  final String bankName;
  final int amount;
  final String? invoiceId;
  final String? orderId;
  final VoidCallback onCheckStatus;

  const PaymentStatusBottomSheet({
    super.key,
    required this.bankName,
    required this.amount,
    this.invoiceId,
    this.orderId,
    required this.onCheckStatus,
  });

  @override
  State<PaymentStatusBottomSheet> createState() =>
      _PaymentStatusBottomSheetState();
}

class _PaymentStatusBottomSheetState extends State<PaymentStatusBottomSheet>
    with TickerProviderStateMixin {
  bool _isChecking = false;
  late AnimationController _animationController;
  StreamSubscription<DocumentSnapshot>? _userDocumentListener;
  String _currentPaymentStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Start animation immediately
    _animationController.repeat();

    // Start listening to payment status changes
    _startListeningToPaymentStatus();
  }

  void _startListeningToPaymentStatus() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _userDocumentListener = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots()
          .listen(
            (documentSnapshot) {
              if (documentSnapshot.exists && mounted) {
                final data = documentSnapshot.data()!;
                final String newStatus = data['qpayStatus'] ?? 'pending';

                if (newStatus != _currentPaymentStatus && mounted) {
                  setState(() {
                    _currentPaymentStatus = newStatus;
                  });

                  // If payment is completed, show success (only for full payment)
                  if (newStatus == 'paid' && mounted) {
                    final dynamic rawPaidAmount =
                        data['lastPaymentAmount'] ?? 0.0;
                    final double paidAmount = rawPaidAmount is String
                        ? double.tryParse(rawPaidAmount) ?? 0.0
                        : (rawPaidAmount as num).toDouble();

                    // Close the bottom sheet and show success
                    Navigator.of(context).pop();
                    _showPaymentCompletedFromListener(
                      paidAmount,
                      0.0, // newBalance is 0 for fully paid
                      newStatus,
                    );
                  }
                }
              }
            },
            onError: (error) {
              print('Firebase listener error: $error');
            },
          );
    }
  }

  void _showPaymentCompletedFromListener(
    double paidAmount,
    double newBalance,
    String paymentStatus,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Payment details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildPaymentDetailRowSimple(
                        'Amount Paid',
                        '₮${paidAmount.toStringAsFixed(0)}',
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons - always show standard Done button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(
                        true,
                      ); // Go back to previous screen with success result
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentDetailRowSimple(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _userDocumentListener?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            spreadRadius: 5,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 32),

            // Beautiful animated loading circle with enhanced design
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer rotating progress ring (only when checking)
                      if (_isChecking)
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF10B981).withOpacity(0.3),
                            ),
                            backgroundColor: Colors.grey.withOpacity(0.1),
                          ),
                        ),

                      // Middle pulsing ring
                      if (_isChecking)
                        Container(
                          width:
                              120 +
                              (10 *
                                  (0.5 +
                                      0.5 * (1 - _animationController.value))),
                          height:
                              120 +
                              (10 *
                                  (0.5 +
                                      0.5 * (1 - _animationController.value))),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color(0xFF10B981).withOpacity(
                                0.1 + (0.2 * (1 - _animationController.value)),
                              ),
                              width: 2,
                            ),
                          ),
                        ),

                      // Main circle with gradient and beautiful progress indicator
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isChecking
                                ? [
                                    const Color(0xFF10B981),
                                    const Color(0xFF06B6D4),
                                    const Color(0xFF3B82F6),
                                  ]
                                : [
                                    const Color(0xFF10B981).withOpacity(0.8),
                                    const Color(0xFF06B6D4).withOpacity(0.9),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF10B981).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: _isChecking
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Beautiful circular progress indicator for checking state
                                  BeautifulCircularProgress(
                                    size: 75,
                                    strokeWidth: 5,
                                    gradientColors: const [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFF1F5F9),
                                      Color(0xFFE2E8F0),
                                      Color(0xFFCBD5E1),
                                    ],
                                    backgroundColor: Colors.transparent,
                                    centerGlowColor: Colors.white,
                                    centerGlowSize: 30,
                                    animationDuration: const Duration(
                                      milliseconds: 1500,
                                    ),
                                  ),
                                  // Inner pulsing dot with enhanced animation
                                  AnimatedBuilder(
                                    animation: _animationController,
                                    builder: (context, child) {
                                      return Container(
                                        width:
                                            18 +
                                            (8 *
                                                (0.5 +
                                                    0.5 *
                                                        (1 -
                                                            _animationController
                                                                .value))),
                                        height:
                                            18 +
                                            (8 *
                                                (0.5 +
                                                    0.5 *
                                                        (1 -
                                                            _animationController
                                                                .value))),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(
                                            0.7 +
                                                (0.3 *
                                                    (1 -
                                                        _animationController
                                                            .value)),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                              blurRadius: 15,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Beautiful animated progress indicator for idle state
                                  BeautifulCircularProgress(
                                    size: 70,
                                    strokeWidth: 4,
                                    gradientColors: const [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFF8FAFC),
                                      Color(0xFFE2E8F0),
                                    ],
                                    backgroundColor: Colors.transparent,
                                    centerGlowColor: Colors.white,
                                    centerGlowSize: 25,
                                    animationDuration: const Duration(
                                      seconds: 3,
                                    ),
                                  ),
                                  // Center icon with enhanced styling
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.95),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.6),
                                          blurRadius: 12,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 18,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      // Animated orbiting dots (only when checking)
                      if (_isChecking) ...[
                        for (int i = 0; i < 8; i++)
                          Transform.rotate(
                            angle:
                                (_animationController.value * 2 * 3.14159) +
                                (i * 3.14159 / 4),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                margin: const EdgeInsets.only(top: 12),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF10B981).withOpacity(
                                        0.3 +
                                            (0.7 *
                                                ((i / 8) +
                                                    _animationController
                                                        .value) %
                                                1),
                                      ),
                                      Color(0xFF3B82F6).withOpacity(
                                        0.6 +
                                            (0.4 *
                                                ((i / 8) +
                                                    _animationController
                                                        .value) %
                                                1),
                                      ),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF10B981).withOpacity(0.3),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // Title with gradient text effect
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
              ).createShader(bounds),
              child: Text(
                _isChecking
                    ? 'Checking Payment...'
                    : _currentPaymentStatus == 'paid'
                    ? 'Payment Completed!'
                    : 'Payment Pending',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // Description with better typography
            Text(
              _isChecking
                  ? 'Please wait while we verify your payment status'
                  : _currentPaymentStatus == 'paid'
                  ? 'Your payment has been successfully processed!'
                  : 'Please check if your payment was completed in ${widget.bankName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 12),

            // Amount info with stunning successful green and blue theme styling
            if (widget.amount > 0) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF10B981).withOpacity(0.08), // Emerald
                      const Color(0xFF3B82F6).withOpacity(0.12), // Blue
                      const Color(0xFF06B6D4).withOpacity(0.08), // Cyan
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.9),
                      blurRadius: 15,
                      spreadRadius: -8,
                      offset: const Offset(0, -4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      blurRadius: 32,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Beautiful animated icon container with green-blue gradient
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF10B981), // Emerald-500
                            Color(0xFF06B6D4), // Cyan-500
                            Color(0xFF3B82F6), // Blue-500
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 0,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 18),

                    // Amount text with enhanced green-blue typography
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Payment Amount',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(
                                0xFF059669,
                              ).withOpacity(0.85), // Emerald-600
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFF047857), // Emerald-700
                                Color(0xFF10B981), // Emerald-500
                                Color(0xFF06B6D4), // Cyan-500
                                Color(0xFF3B82F6), // Blue-500
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              '₮${widget.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Decorative elements with green-blue theme
                    const SizedBox(width: 16),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(
                              0xFF10B981,
                            ).withOpacity(0.15), // Emerald
                            const Color(0xFF3B82F6).withOpacity(0.10), // Blue
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: const Color(
                          0xFF059669,
                        ).withOpacity(0.7), // Emerald-600
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],

            // Check Payment Status Button with gradient
            Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _isChecking
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                boxShadow: _isChecking
                    ? null
                    : [
                        BoxShadow(
                          color: Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ElevatedButton(
                onPressed: _isChecking ? null : _handleCheckPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isChecking
                      ? Colors.grey[200]
                      : Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isChecking
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.grey[600]!,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Checking...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Check Payment Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: _isChecking
                    ? null
                    : () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    color: _isChecking ? Colors.grey : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCheckPayment() async {
    setState(() => _isChecking = true);

    try {
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Small delay for UX
      widget.onCheckStatus();
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }
}
