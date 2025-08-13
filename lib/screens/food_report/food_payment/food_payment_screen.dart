import 'package:flutter/material.dart';

class FoodPaymentScreen extends StatefulWidget {
  const FoodPaymentScreen({super.key});

  @override
  State<FoodPaymentScreen> createState() => _FoodPaymentScreenState();
}

class _FoodPaymentScreenState extends State<FoodPaymentScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Хоолны төлбөр'),
      ),
      body: Center(
        child: Text(
          'Энд хоолны төлбөрийн дэлгэрэнгүй мэдээлэл гарна.',
        ),
      ),
    );
  }
}