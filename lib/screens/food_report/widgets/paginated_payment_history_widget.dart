import 'package:flutter/material.dart';

class PaginatedPaymentHistoryWidget extends StatefulWidget {
  const PaginatedPaymentHistoryWidget({super.key});

  @override
  State<PaginatedPaymentHistoryWidget> createState() =>
      _PaginatedPaymentHistoryWidgetState();
}

class _PaginatedPaymentHistoryWidgetState
    extends State<PaginatedPaymentHistoryWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Төлбөрийн түүх байхгүй байна',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
