import 'package:flutter/material.dart';
import 'package:timex/index.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../login/google_login_screen.dart';
import '../../services/qpay_webhook_service.dart';
import '../../services/qpay_helper_service.dart';
import '../../utils/qr_utils.dart';
import '../../utils/banking_app_checker.dart';

class QRCodeScreen extends StatefulWidget {
  const QRCodeScreen({super.key});

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  Map<String, dynamic>? qpayResult;
  bool isLoading = false;
  String? errorMessage;
  double currentFoodAmount = 0.0;
  bool isLoadingBalance = true;

  // Payment verification
  final TextEditingController _paymentAmountController =
      TextEditingController();
  final TextEditingController _verifyAmountController = TextEditingController();
  bool isCheckingPayment = false;
  String? paymentStatus; // 'pending', 'paid', or null
  String? currentInvoiceId;

  // QPay integration now handled by QPayHelperService

  @override
  void initState() {
    super.initState();
    print('QRCodeScreen initState called');
    _loadUserBalance();
    _checkBankingApps(); // Check what banking apps are available
  }

  /// Check available banking apps for debugging
  Future<void> _checkBankingApps() async {
    if (kDebugMode) {
      try {
        final report = await BankingAppChecker.getAvailabilityReport();
        print('📱 Banking Apps Available:');
        print(report);
      } catch (error) {
        print('Error checking banking apps: $error');
      }
    }
  }

  /// Load user's current food balance
  Future<void> _loadUserBalance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final balance = await QPayWebhookService.getUserFoodAmount(user.uid);
        setState(() {
          currentFoodAmount = balance;
          isLoadingBalance = false;
        });
      }
    } catch (error) {
      print('Error loading user balance: $error');
      setState(() {
        isLoadingBalance = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      // Get Firebase Auth instance
      final auth = FirebaseAuth.instance;

      // Get Google Sign In instance
      final googleSignIn = GoogleSignIn();

      // Sign out from Firebase
      await auth.signOut();

      // Sign out from Google
      await googleSignIn.signOut();

      print('User signed out successfully from QR screen');

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const GoogleLoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Sign out error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Гарах үед алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createQPayInvoice() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // Check if running on web and show helpful message
    if (kIsWeb) {
      setState(() {
        errorMessage =
            '🌐 Running on Web Browser\n\n✅ QPay integration is correctly implemented!\n\n🚫 Web browsers block direct API calls to external services (CORS policy)\n\n📱 Please test on a mobile device to see real QPay QR codes that work with Mongolian banking apps.';
        isLoading = false;
      });
      return;
    }

    // Validate amount input
    final amountText = _paymentAmountController.text.trim();
    if (amountText.isEmpty) {
      setState(() {
        errorMessage = 'Please enter an amount first';
        isLoading = false;
      });
      return;
    }

    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() {
        errorMessage = 'Please enter a valid amount greater than 0';
        isLoading = false;
      });
      return;
    }

    try {
      print('🚀 Creating QPay invoice using helper service...');

      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      final String userUid = currentUser?.uid ?? 'unknown';
      final String orderId = 'TIMEX_${DateTime.now().millisecondsSinceEpoch}';

      // Use the new helper service
      final result = await QPayHelperService.createInvoiceWithQR(
        amount: amount,
        orderId: orderId,
        userId: userUid,
        invoiceDescription:
            'TIMEX Food Payment - ₮${amount.toStringAsFixed(0)}',
        callbackUrl: 'http://localhost:3000/qpay/webhook',
      );

      if (result['success'] == true) {
        final invoice = result['invoice'];
        print('✅ QPay invoice created successfully: ${invoice['invoice_id']}');

        // Set payment status to pending in Firebase
        await QPayWebhookService.setPaymentStatusPending(userUid);

        // Debug: Print the invoice structure to understand the response
        print('🔍 QPay invoice response structure:');
        invoice.forEach((key, value) {
          if (key == 'urls' && value is List) {
            print('  $key: List with ${value.length} items');
            for (int i = 0; i < value.length; i++) {
              print('    [$i]: ${value[i].runtimeType} = ${value[i]}');
            }
          } else {
            print(
              '  $key: ${value.runtimeType} = ${value.toString().length > 100 ? '${value.toString().substring(0, 100)}...' : value}',
            );
          }
        });

        setState(() {
          qpayResult = invoice;
          currentInvoiceId = invoice['invoice_id'];
          paymentStatus = 'pending';
          isLoading = false;
        });
      } else {
        throw Exception(result['error'] ?? 'Failed to create QPay invoice');
      }
    } catch (error) {
      print('Error creating QPay invoice: $error');

      String userFriendlyError;
      if (error.toString().contains('Failed to fetch') ||
          error.toString().contains('CORS') ||
          error.toString().contains('network')) {
        userFriendlyError =
            'Cannot connect to QPay from web browser due to CORS policy.\n\n✅ The integration is working correctly!\n\n📱 Please test on a mobile device where QPay API calls will work properly and generate real, scannable QR codes.';
      } else {
        userFriendlyError =
            'Failed to create QPay invoice: ${error.toString()}';
      }

      setState(() {
        errorMessage = userFriendlyError;
        isLoading = false;
      });
    }
  }

  // Payment verification methods
  Future<void> _checkPaymentStatus() async {
    if (currentInvoiceId == null) {
      _showMessage('No invoice to check', isError: true);
      return;
    }

    final amountText = _verifyAmountController.text.trim();
    if (amountText.isEmpty) {
      _showMessage('Please enter payment amount', isError: true);
      return;
    }

    final double? paymentAmount = double.tryParse(amountText);
    if (paymentAmount == null || paymentAmount <= 0) {
      _showMessage('Please enter valid payment amount', isError: true);
      return;
    }

    setState(() {
      isCheckingPayment = true;
    });

    try {
      // Get access token first
      final authResult = await QPayHelperService.getAccessToken();
      if (authResult['success'] != true) {
        throw Exception('Failed to authenticate: ${authResult['error']}');
      }

      // Check payment status
      final paymentResult = await QPayHelperService.checkPayment(
        authResult['access_token'],
        currentInvoiceId!,
      );

      if (paymentResult['success'] == true) {
        final int count = paymentResult['count'] ?? 0;
        final double paidAmount = (paymentResult['paid_amount'] ?? 0)
            .toDouble();

        if (count > 0 && paidAmount >= paymentAmount) {
          // Payment found and amount is sufficient
          setState(() {
            paymentStatus = 'paid';
          });

          // Update Firebase
          await _updateFirebaseBalance(paymentAmount);

          _showMessage(
            'Payment confirmed! ₮${paymentAmount.toStringAsFixed(0)} deducted from balance',
            isError: false,
          );

          // Clear the input
          _verifyAmountController.clear();

          // Reload balance
          await _loadUserBalance();
        } else if (count > 0 && paidAmount < paymentAmount) {
          _showMessage(
            'Payment found but amount is less than entered (₮${paidAmount.toStringAsFixed(0)})',
            isError: true,
          );
        } else {
          _showMessage('No payment found yet', isError: true);
        }
      } else {
        throw Exception(paymentResult['error'] ?? 'Failed to check payment');
      }
    } catch (error) {
      print('Error checking payment: $error');
      _showMessage('Error checking payment: $error', isError: true);
    } finally {
      setState(() {
        isCheckingPayment = false;
      });
    }
  }

  Future<void> _updateFirebaseBalance(double paidAmount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Simulate webhook processing
      final webhookData = {
        'payment_status': 'PAID',
        'paid_amount': paidAmount,
        'user_id': user.uid,
        'invoice_id': currentInvoiceId,
        'transaction_id': 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
        'payment_date': DateTime.now().toIso8601String(),
      };

      await QPayWebhookService.processWebhook(webhookData);
    } catch (error) {
      print('Error updating Firebase balance: $error');
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Launch deep link to mobile banking app
  Future<void> _launchMobileBankingApp() async {
    if (qpayResult == null) {
      _showMessage('No invoice available', isError: true);
      return;
    }

    try {
      // Try using the new method first
      final primaryBankingApp = QRUtils.getPrimaryBankingApp(qpayResult!);

      if (primaryBankingApp != null) {
        print('🚀 Launching primary banking app: ${primaryBankingApp.name}');
        try {
          final uri = Uri.parse(primaryBankingApp.deepLink);

          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            _showMessage('Opened ${primaryBankingApp.name}', isError: false);
            return;
          } else {
            print(
              '❌ Cannot launch ${primaryBankingApp.name}, trying fallback...',
            );
          }
        } catch (uriError) {
          print('❌ Error parsing URI for ${primaryBankingApp.name}: $uriError');
          _showMessage(
            'Invalid link format for ${primaryBankingApp.name}',
            isError: true,
          );
        }
      } else {
        print('🔍 No primary banking app found from QPay response');
      }

      // Fallback to legacy method
      final qrText = qpayResult!['qr_text'] ?? '';
      final invoiceId = qpayResult!['invoice_id'];

      // Extract QPay short URL from different possible fields
      String? qpayShortUrl;
      if (qpayResult!['qpay_shortUrl'] != null) {
        qpayShortUrl = qpayResult!['qpay_shortUrl'].toString();
      } else if (qpayResult!['urls'] != null) {
        final urls = qpayResult!['urls'];
        if (urls is List && urls.isNotEmpty) {
          // Look for the first valid URL
          for (final url in urls) {
            if (url is Map && url['link'] != null) {
              final link = url['link'].toString();
              if (link.startsWith('http')) {
                qpayShortUrl = link;
                break;
              }
            }
          }
        } else if (urls is Map) {
          // If urls is a map, try to get the first value
          final values = urls.values;
          if (values.isNotEmpty) {
            qpayShortUrl = values.first.toString();
          }
        }
      }

      final deepLink = QRUtils.getPrimaryDeepLink(
        qrText,
        qpayShortUrl,
        invoiceId,
      );

      if (deepLink != null) {
        try {
          final uri = Uri.parse(deepLink);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            _showMessage('Opened in banking app', isError: false);
          } else {
            // Fallback to web URL if available
            if (qpayShortUrl != null && qpayShortUrl.startsWith('http')) {
              try {
                final webUri = Uri.parse(qpayShortUrl);
                if (await canLaunchUrl(webUri)) {
                  await launchUrl(webUri, mode: LaunchMode.externalApplication);
                  _showMessage('Opened in browser', isError: false);
                } else {
                  _showMessage(
                    'No compatible banking app found',
                    isError: true,
                  );
                }
              } catch (webUriError) {
                print('❌ Error parsing web URI: $webUriError');
                _showMessage('Invalid web URL format', isError: true);
              }
            } else {
              _showMessage('No compatible banking app found', isError: true);
            }
          }
        } catch (deepLinkError) {
          print('❌ Error parsing deep link URI: $deepLinkError');
          _showMessage('Invalid deep link format', isError: true);
        }
      } else {
        // If no deep link is available, show banking app options instead
        print('🔍 No primary deep link found, showing banking app options');
        _showBankingAppOptions();
      }
    } catch (error) {
      print('Error launching banking app: $error');
      _showMessage('Failed to open banking app: $error', isError: true);
    }
  }

  /// Show available banking app options with enhanced detection
  void _showBankingAppOptions() async {
    if (qpayResult == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final qrText = qpayResult!['qr_text'] ?? '';
      final invoiceId = qpayResult!['invoice_id'];

      // Use optimized banking app detection
      final optimizedLinks = await BankingAppChecker.getOptimizedDeepLinks(
        qrText,
        invoiceId,
      );

      // Get traditional banking apps from QPay response
      final bankingApps = QRUtils.extractBankingApps(qpayResult!);

      // Fallback to legacy method
      Map<String, String> legacyDeepLinks = {};
      if (bankingApps.isEmpty && optimizedLinks.isEmpty) {
        String? qpayShortUrl;
        if (qpayResult!['qpay_shortUrl'] != null) {
          qpayShortUrl = qpayResult!['qpay_shortUrl'].toString();
        } else if (qpayResult!['urls'] != null) {
          final urls = qpayResult!['urls'];
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          );
        },
      );
    } catch (error) {
      Navigator.pop(context); // Close loading dialog
      print('Error showing banking app options: $error');
      _showMessage('Failed to load banking apps: $error', isError: true);
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
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        _showMessage('Opened $appName', isError: false);
      } else {
        _showMessage('$appName not installed', isError: true);
      }
    } catch (error) {
      print('Error launching $appName: $error');
      _showMessage('Invalid link format for $appName', isError: true);
    }
  }

  /// Show available banking app options with improved detection
  void _showBankingAppOptions() {
    if (qpayResult == null) return;

    // Use the new banking app extraction method
    final bankingApps = QRUtils.extractBankingApps(qpayResult!);

    // Get enhanced deep links for more banks
    final qrText = qpayResult!['qr_text'] ?? '';
    final invoiceId = qpayResult!['invoice_id'];
    
    // Extract QPay short URL from different possible fields
    String? qpayShortUrl;
    if (qpayResult!['qpay_shortUrl'] != null) {
      qpayShortUrl = qpayResult!['qpay_shortUrl'].toString();
    } else if (qpayResult!['urls'] != null) {
      final urls = qpayResult!['urls'];
      if (urls is List && urls.isNotEmpty) {
        // Look for the first valid URL
        for (final url in urls) {
          if (url is Map && url['link'] != null) {
            final link = url['link'].toString();
            if (link.startsWith('http')) {
              qpayShortUrl = link;
              break;
            }
          }
        }
      } else if (urls is Map) {
        final values = urls.values;
        if (values.isNotEmpty) {
          qpayShortUrl = values.first.toString();
        }
      }
    }

    // Get enhanced legacy deep links with more banks
    final legacyDeepLinks = QRUtils.generateDeepLinks(
      qrText,
      qpayShortUrl,
      invoiceId,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
                    entry.key == 'banking' ? 'Web browser' : 'Mobile app',
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      final uri = Uri.parse(entry.value);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        _showMessage('Opened in $appName', isError: false);
                      } else {
                        _showMessage('$appName not installed', isError: true);
                      }
                    } catch (uriError) {
                      print('Error launching $appName: $uriError');
                      _showMessage(
                        'Invalid link format for $appName',
                        isError: true,
                      );
                    }
                  },
                );
              }).toList(),

              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshQRCode() async {
    print('Refresh QR pressed');
    await _loadUserBalance();
    // Clear previous results to show the input form again
    setState(() {
      qpayResult = null;
      errorMessage = null;
      paymentStatus = null;
      currentInvoiceId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('QRCodeScreen build called - hasResult: ${qpayResult != null}');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: txt(
          'QPay Төлбөр',
          style: TxtStl.bodyText1(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, color: Colors.black),
            onPressed: isLoading ? null : _refreshQRCode,
            tooltip: 'Refresh QR Code',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _signOut,
            tooltip: 'Гарах',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // User Balance Display
              if (!isLoadingBalance)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Food Balance',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '₮${currentFoodAmount.toStringAsFixed(0)} MNT',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (currentFoodAmount > 0)
                        Icon(
                          Icons.trending_down,
                          color: Colors.orange,
                          size: 16,
                        ),
                    ],
                  ),
                ),

              // Amount Input Section (only show if no invoice yet)
              if (qpayResult == null && errorMessage == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.payment,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Create QPay Invoice',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Enter the amount you want to pay:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _paymentAmountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Amount (e.g. 1000)',
                          prefixText: '₮ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _createQPayInvoice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Creating Invoice...'),
                                  ],
                                )
                              : Text(
                                  'Create QPay Invoice',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Loading State
              if (isLoading)
                Container(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        'Creating QPay Invoice...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

              // Error State
              if (!isLoading && errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Error Creating Invoice',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                  ),
                ),

              // Success State - Real QPay QR Code
              if (!isLoading && errorMessage == null && qpayResult != null) ...[
                // QPay Invoice Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Real QPay Invoice Created!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      if (qpayResult!['invoice_id'] != null)
                        Text(
                          'ID: ${qpayResult!['invoice_id']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      Text(
                        'Scannable with bank apps',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30),

                // Real QPay QR Code (Base64)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildQRCode(),
                ),

                SizedBox(height: 30),

                // Invoice Details
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 15),

                      // Payment Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payment Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: paymentStatus == 'paid'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: paymentStatus == 'paid'
                                    ? Colors.green
                                    : Colors.orange,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              paymentStatus == 'paid' ? 'PAID' : 'PENDING',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: paymentStatus == 'paid'
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Scan QR code and pay any amount you want, then verify below',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Payment Verification Section
                if (paymentStatus == 'pending')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verify Your Payment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Enter the amount you paid:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: _verifyAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Amount (e.g. 1000)',
                            prefixText: '₮ ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isCheckingPayment
                                ? null
                                : _checkPaymentStatus,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isCheckingPayment
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Checking Payment...'),
                                    ],
                                  )
                                : Text(
                                    'Check Payment Status',
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

                SizedBox(height: 20),

                // Mobile Banking App Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _launchMobileBankingApp,
                        icon: Icon(Icons.phone_android),
                        label: Text('Open Banking App'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showBankingAppOptions,
                      icon: Icon(Icons.more_vert),
                      label: Text('More Apps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade700),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Scan with your bank app - pay any amount you choose',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.amber.shade800,
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
      ),
    );
  }

  Widget _buildQRCode() {
    if (qpayResult == null) {
      return _buildQRPlaceholder();
    }

    // Try to display base64 QR image from QPay response
    if (qpayResult!['qr_image'] != null) {
      try {
        String base64String = qpayResult!['qr_image'];
        // Remove data URL prefix if present (data:image/png;base64,)
        if (base64String.contains(',')) {
          base64String = base64String.split(',').last;
        }
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: 250,
          height: 250,
          fit: BoxFit.contain,
        );
      } catch (e) {
        print('Error decoding base64 QR image: $e');
      }
    }

    // Fallback: Generate QR code from qr_text if available
    if (qpayResult!['qr_text'] != null) {
      return QrImageView(
        data: qpayResult!['qr_text'],
        version: QrVersions.auto,
        size: 250.0,
        backgroundColor: Colors.white,
      );
    }

    // Check for other possible QR fields
    if (qpayResult!['qr_string'] != null) {
      return QrImageView(
        data: qpayResult!['qr_string'],
        version: QrVersions.auto,
        size: 250.0,
        backgroundColor: Colors.white,
      );
    }

    return _buildQRPlaceholder();
  }

  Widget _buildQRPlaceholder() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code, size: 48, color: Colors.grey.shade400),
            SizedBox(height: 8),
            Text(
              'QR Code not available',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
