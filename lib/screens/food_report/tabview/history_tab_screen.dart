import 'package:flutter/material.dart';
import '../widgets/paginated_payment_history_widget.dart';

class HistoryTabScreen extends StatelessWidget {
  const HistoryTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: PaginatedPaymentHistoryWidget(),
    );
  }
}
