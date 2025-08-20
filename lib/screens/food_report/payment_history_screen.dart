// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../../services/qpay_helper_service.dart';
// import '../../services/money_format.dart';
// import '../../theme/app_theme.dart';
// import '../../utils/logger.dart';

// class PaymentHistoryScreen extends StatefulWidget {
//   const PaymentHistoryScreen({super.key});

//   @override
//   State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
// }

// class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
//   final ScrollController _scrollController = ScrollController();

//   List<Map<String, dynamic>> _localPayments = [];
//   List<Map<String, dynamic>> _qpayPayments = [];
//   List<Map<String, dynamic>> _combinedPayments = [];

//   bool _isLoading = true;
//   bool _isLoadingQPay = false;
//   bool _hasQPayError = false;
//   String? _errorMessage;

//   DocumentSnapshot? _lastDocument;
//   bool _hasMoreData = true;

//   String _selectedFilter = 'all'; // all, payment, topup, refund
//   DateTimeRange? _selectedDateRange;

//   @override
//   void initState() {
//     super.initState();
//     _scrollController.addListener(_handleScroll);
//   }

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     super.dispose();
//   }

//   void _handleScroll() {
//     if (_scrollController.position.pixels >=
//         _scrollController.position.maxScrollExtent - 200) {
//       if (!_isLoading && _hasMoreData) {
//         _loadMoreLocalPayments();
//       }
//     }
//   }

//   Future<void> _loadMoreLocalPayments() async {
//     if (!_hasMoreData || _lastDocument == null) return;

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       final userId = FirebaseAuth.instance.currentUser?.uid;
//       if (userId == null) return;

//       final querySnapshot = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(userId)
//           .collection('historyOfPayment')
//           .orderBy('timestamp', descending: true)
//           .startAfterDocument(_lastDocument!)
//           .limit(10)
//           .get();

//       final newPayments = querySnapshot.docs
//           .map((doc) => _convertFirestoreDocToPayment(doc))
//           .toList();

//       setState(() {
//         _localPayments.addAll(newPayments);

//         if (querySnapshot.docs.isNotEmpty) {
//           _lastDocument = querySnapshot.docs.last;
//           _hasMoreData = querySnapshot.docs.length >= 10;
//         } else {
//           _hasMoreData = false;
//         }

//         _combineAndSortPayments();
//         _isLoading = false;
//       });
//     } catch (error) {
//       AppLogger.error('Error loading more local payments: $error');
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   Map<String, dynamic> _convertFirestoreDocToPayment(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return {
//       'id': doc.id,
//       'amount': data['amount'] ?? 0,
//       'type': data['type'] ?? 'payment',
//       'description': data['description'] ?? '',
//       'timestamp': data['timestamp'],
//       'date': data['date'] ?? DateTime.now().toIso8601String(),
//       'transactionId': data['transactionId'] ?? doc.id,
//       'status': data['status'] ?? 'completed',
//       'paymentMethod': data['paymentMethod'] ?? 'local',
//       'source': 'local', // Mark as local payment
//     };
//   }

//   Map<String, dynamic> _convertQPayPaymentToLocal(
//     Map<String, dynamic> qpayPayment,
//   ) {
//     return {
//       'id':
//           qpayPayment['payment_id']?.toString() ??
//           qpayPayment['invoice_id']?.toString() ??
//           '',
//       'amount': (qpayPayment['paid_amount'] ?? qpayPayment['amount'] ?? 0)
//           .toDouble()
//           .toInt(),
//       'type': 'payment',
//       'description': qpayPayment['description'] ?? 'QPay төлбөр',
//       'timestamp': qpayPayment['created_date'] != null
//           ? Timestamp.fromDate(DateTime.parse(qpayPayment['created_date']))
//           : Timestamp.now(),
//       'date': qpayPayment['created_date'] ?? DateTime.now().toIso8601String(),
//       'transactionId':
//           qpayPayment['transaction_id']?.toString() ??
//           qpayPayment['invoice_id']?.toString() ??
//           '',
//       'status': _mapQPayStatus(
//         qpayPayment['payment_status'] ?? qpayPayment['status'],
//       ),
//       'paymentMethod': 'qpay',
//       'source': 'qpay', // Mark as QPay payment
//       'invoiceId': qpayPayment['invoice_id']?.toString(),
//       'bankName': qpayPayment['bank_name']?.toString(),
//     };
//   }

//   String _mapQPayStatus(dynamic status) {
//     final statusStr = status?.toString()?.toLowerCase() ?? '';
//     switch (statusStr) {
//       case 'paid':
//       case 'success':
//       case 'completed':
//         return 'completed';
//       case 'pending':
//       case 'created':
//         return 'pending';
//       case 'cancelled':
//       case 'failed':
//         return 'failed';
//       default:
//         return 'pending';
//     }
//   }

//   void _combineAndSortPayments() {
//     _combinedPayments = [..._localPayments, ..._qpayPayments];

//     // Sort by timestamp (most recent first)
//     _combinedPayments.sort((a, b) {
//       final aTime = a['timestamp'] is Timestamp
//           ? (a['timestamp'] as Timestamp).millisecondsSinceEpoch
//           : DateTime.parse(a['date']).millisecondsSinceEpoch;
//       final bTime = b['timestamp'] is Timestamp
//           ? (b['timestamp'] as Timestamp).millisecondsSinceEpoch
//           : DateTime.parse(b['date']).millisecondsSinceEpoch;
//       return bTime.compareTo(aTime);
//     });

//     // Apply filters
//     _applyFilters();
//   }

//   void _applyFilters() {
//     var filtered = _combinedPayments.where((payment) {
//       // Type filter
//       if (_selectedFilter != 'all' && payment['type'] != _selectedFilter) {
//         return false;
//       }

//       // Date range filter
//       if (_selectedDateRange != null) {
//         final paymentDate = payment['timestamp'] is Timestamp
//             ? (payment['timestamp'] as Timestamp).toDate()
//             : DateTime.parse(payment['date']);

//         if (paymentDate.isBefore(_selectedDateRange!.start) ||
//             paymentDate.isAfter(_selectedDateRange!.end)) {
//           return false;
//         }
//       }

//       return true;
//     }).toList();

//     setState(() {
//       _combinedPayments = filtered;
//     });
//   }

//   Future<void> _showFilterDialog() async {
//     await showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => Container(
//         padding: EdgeInsets.only(
//           bottom: MediaQuery.of(context).viewInsets.bottom,
//         ),
//         child: Container(
//           padding: const EdgeInsets.all(24),
//           decoration: const BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Шүүлтүүр',
//                 style: Theme.of(
//                   context,
//                 ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 24),

//               Text(
//                 'Төлбөрийн төрөл',
//                 style: Theme.of(context).textTheme.titleMedium,
//               ),
//               const SizedBox(height: 8),
//               Wrap(
//                 spacing: 8,
//                 children: [
//                   _buildFilterChip('Бүгд', 'all'),
//                   _buildFilterChip('Төлбөр', 'payment'),
//                   _buildFilterChip('Цэнэглэх', 'topup'),
//                   _buildFilterChip('Буцаалт', 'refund'),
//                 ],
//               ),
//               const SizedBox(height: 24),

//               Row(
//                 children: [
//                   Expanded(
//                     child: ElevatedButton(
//                       onPressed: () {
//                         Navigator.pop(context);
//                         _combineAndSortPayments();
//                       },
//                       child: const Text('Хайх'),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   TextButton(
//                     onPressed: () {
//                       setState(() {
//                         _selectedFilter = 'all';
//                         _selectedDateRange = null;
//                       });
//                       Navigator.pop(context);
//                       _combineAndSortPayments();
//                     },
//                     child: const Text('Цэвэрлэх'),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildFilterChip(String label, String value) {
//     final isSelected = _selectedFilter == value;
//     return FilterChip(
//       label: Text(label),
//       selected: isSelected,
//       onSelected: (selected) {
//         setState(() {
//           _selectedFilter = value;
//         });
//       },
//       selectedColor: AppTheme.primaryLight.withOpacity(0.2),
//       checkmarkColor: AppTheme.primaryLight,
//     );
//   }

//   Widget _buildBody() {
//     if (_isLoading && _combinedPayments.isEmpty) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     if (_combinedPayments.isEmpty) {
//       return _buildEmptyState();
//     }

//     return Column(
//       children: [
//         // QPay status indicator
//         if (_hasQPayError)
//           Container(
//             width: double.infinity,
//             margin: const EdgeInsets.all(16),
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: AppTheme.warningLight.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: AppTheme.warningLight.withOpacity(0.3)),
//             ),
//             child: Row(
//               children: [
//                 Icon(
//                   Icons.warning_amber,
//                   color: AppTheme.warningLight,
//                   size: 20,
//                 ),
//                 const SizedBox(width: 8),
//                 const Expanded(
//                   child: Text(
//                     'QPay төлбөрүүдийг ачаалж чадсангүй. Зөвхөн локал төлбөрүүд харагдаж байна.',
//                     style: TextStyle(fontSize: 12),
//                   ),
//                 ),
//               ],
//             ),
//           )
//         else if (_isLoadingQPay)
//           Container(
//             width: double.infinity,
//             margin: const EdgeInsets.all(16),
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: AppTheme.primaryLight.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: const Row(
//               children: [
//                 SizedBox(
//                   width: 16,
//                   height: 16,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 ),
//                 SizedBox(width: 8),
//                 Text(
//                   'QPay төлбөрүүдийг ачаалж байна...',
//                   style: TextStyle(fontSize: 12),
//                 ),
//               ],
//             ),
//           ),

//         // Payment list
//         Expanded(
//           child: ListView.builder(
//             controller: _scrollController,
//             padding: const EdgeInsets.all(16),
//             itemCount: _combinedPayments.length + (_hasMoreData ? 1 : 0),
//             itemBuilder: (context, index) {
//               if (index >= _combinedPayments.length) {
//                 return const Center(
//                   child: Padding(
//                     padding: EdgeInsets.all(16),
//                     child: CircularProgressIndicator(),
//                   ),
//                 );
//               }

//               final payment = _combinedPayments[index];
//               return _buildPaymentCard(payment);
//             },
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
//           const SizedBox(height: 16),
//           Text(
//             'Төлбөрийн түүх байхгүй байна',
//             style: Theme.of(
//               context,
//             ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Таны төлбөрүүд энд харагдах болно',
//             style: Theme.of(
//               context,
//             ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPaymentCard(Map<String, dynamic> payment) {
//     final amount = payment['amount'] as int;
//     final type = payment['type'] as String;
//     final description = payment['description'] as String;
//     final status = payment['status'] as String;
//     final source = payment['source'] as String;
//     final paymentMethod = payment['paymentMethod'] as String;

//     final timestamp = payment['timestamp'];
//     final date = timestamp is Timestamp
//         ? timestamp.toDate()
//         : DateTime.parse(payment['date']);

//     // Determine colors and icons based on type and status
//     Color statusColor = AppTheme.successLight;
//     Color typeColor = AppTheme.primaryLight;
//     IconData typeIcon = Icons.payment;
//     String typeText = 'Төлбөр';

//     switch (type) {
//       case 'payment':
//         typeColor = AppTheme.primaryLight;
//         typeIcon = Icons.payment;
//         typeText = 'Төлбөр';
//         break;
//       case 'topup':
//         typeColor = AppTheme.successLight;
//         typeIcon = Icons.add_circle_outline;
//         typeText = 'Цэнэглэх';
//         break;
//       case 'refund':
//         typeColor = AppTheme.warningLight;
//         typeIcon = Icons.keyboard_return;
//         typeText = 'Буцаалт';
//         break;
//     }

//     switch (status) {
//       case 'completed':
//         statusColor = AppTheme.successLight;
//         break;
//       case 'pending':
//         statusColor = AppTheme.warningLight;
//         break;
//       case 'failed':
//         statusColor = AppTheme.errorLight;
//         break;
//     }

//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.withOpacity(0.2)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   width: 40,
//                   height: 40,
//                   decoration: BoxDecoration(
//                     color: typeColor.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Icon(typeIcon, color: typeColor, size: 20),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               description.isNotEmpty ? description : typeText,
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 8,
//                               vertical: 4,
//                             ),
//                             decoration: BoxDecoration(
//                               color: statusColor.withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(12),
//                               border: Border.all(
//                                 color: statusColor.withOpacity(0.3),
//                               ),
//                             ),
//                             child: Text(
//                               _getStatusText(status),
//                               style: TextStyle(
//                                 color: statusColor,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 4),
//                       Row(
//                         children: [
//                           Text(
//                             MoneyFormatService.formatWithSymbol(amount),
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                               color: type == 'topup' || type == 'refund'
//                                   ? AppTheme.successLight
//                                   : AppTheme.primaryLight,
//                             ),
//                           ),
//                           const Spacer(),
//                           Text(
//                             _formatDate(date),
//                             style: TextStyle(
//                               color: Colors.grey[600],
//                               fontSize: 12,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 12),

//             // Additional payment details
//             Row(
//               children: [
//                 _buildDetailChip(
//                   _getPaymentMethodText(paymentMethod),
//                   Icons.account_balance_wallet,
//                 ),
//                 if (source == 'qpay') ...[
//                   const SizedBox(width: 8),
//                   _buildDetailChip('QPay', Icons.qr_code_scanner),
//                 ],
//                 if (payment['bankName'] != null) ...[
//                   const SizedBox(width: 8),
//                   _buildDetailChip(
//                     payment['bankName'].toString(),
//                     Icons.account_balance,
//                   ),
//                 ],
//               ],
//             ),

//             if (payment['transactionId'] != null)
//               Padding(
//                 padding: const EdgeInsets.only(top: 8),
//                 child: Text(
//                   'Гүйлгээний ID: ${payment['transactionId']}',
//                   style: TextStyle(color: Colors.grey[500], fontSize: 11),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDetailChip(String label, IconData icon) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: Colors.grey.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 12, color: Colors.grey[600]),
//           const SizedBox(width: 4),
//           Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
//         ],
//       ),
//     );
//   }

//   String _getStatusText(String status) {
//     switch (status) {
//       case 'completed':
//         return 'Амжилттай';
//       case 'pending':
//         return 'Хүлээгдэж буй';
//       case 'failed':
//         return 'Амжилтгүй';
//       default:
//         return 'Тодорхойгүй';
//     }
//   }

//   String _getPaymentMethodText(String method) {
//     switch (method) {
//       case 'qpay':
//         return 'QPay';
//       case 'card':
//         return 'Карт';
//       case 'bank_transfer':
//         return 'Банкны шилжүүлэг';
//       case 'cash':
//         return 'Бэлэн мөнгө';
//       case 'local':
//         return 'Локал';
//       default:
//         return method;
//     }
//   }

//   String _formatDate(DateTime date) {
//     final now = DateTime.now();
//     final difference = now.difference(date);

//     if (difference.inDays == 0) {
//       return 'Өнөөдөр ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
//     } else if (difference.inDays == 1) {
//       return 'Өчигдөр ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
//     } else if (difference.inDays < 7) {
//       return '${difference.inDays} өдрийн өмнө';
//     } else {
//       return '${date.month}/${date.day}';
//     }
//   }
// }
