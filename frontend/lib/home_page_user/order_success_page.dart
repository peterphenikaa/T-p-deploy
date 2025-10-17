import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'cart_provider.dart';
import 'home_pages.dart';
import 'order_tracking_page.dart';

class OrderSuccessPage extends StatelessWidget {
  final String orderId;
  final double totalAmount;

  const OrderSuccessPage({
    Key? key,
    required this.orderId,
    required this.totalAmount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              _buildSuccessIllustration(),
              const SizedBox(height: 40),

              _buildCongratulationsText(),
              const SizedBox(height: 16),
              _buildSuccessMessage(),
              const SizedBox(height: 40),

              _buildOrderDetailsCard(),
              const SizedBox(height: 40),

              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIllustration() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.orange[50],
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background food patterns
          Positioned(
            top: 20,
            left: 20,
            child: Icon(
              Icons.restaurant,
              size: 30,
              color: Colors.orange[200],
            ),
          ),
          Positioned(
            top: 30,
            right: 30,
            child: Icon(
              Icons.local_pizza,
              size: 25,
              color: Colors.orange[200],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 30,
            child: Icon(
              Icons.fastfood,
              size: 28,
              color: Colors.orange[200],
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Icon(
              Icons.cake,
              size: 26,
              color: Colors.orange[200],
            ),
          ),

          // Main success icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.check,
              size: 50,
              color: Colors.white,
            ),
          ),

          // Confetti effects
          ...List.generate(8, (index) {
            final angle = (index * 45.0) * (pi / 180);
            final radius = 90.0;
            final x = radius * cos(angle);
            final y = radius * sin(angle);

            return Positioned(
              left: 100 + x,
              top: 100 + y,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _getConfettiColor(index),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCongratulationsText() {
    return Column(
      children: [
        Text(
          'Chúc mừng!',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Bạn đã đặt hàng thành công!',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.green[600],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Đơn hàng của bạn đang được xử lý. Chúng tôi sẽ giao hàng trong thời gian sớm nhất!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Mã đơn hàng:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '#$orderId',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Tổng tiền:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '₫${totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Thời gian dự kiến:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '20-30 phút',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              _showTrackOrderDialog(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 3,
            ),
            child: const Text(
              'THEO DÕI ĐƠN HÀNG',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Continue Shopping Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              // Clear cart and go to home
              Provider.of<CartProvider>(context, listen: false).clearCart();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => HomePage()),
                (route) => false,
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              side: const BorderSide(color: Colors.orange, width: 2),
            ),
            child: const Text(
              'TIẾP TỤC MUA SẮM',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTrackOrderDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderTrackingPage(orderId: orderId),
      ),
    );
  }

  Widget _buildTrackingStep(String title, bool isCompleted, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: isCompleted ? Colors.green : Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isCompleted ? Colors.green[700] : Colors.grey[600],
                fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isCompleted)
            Icon(
              Icons.check,
              color: Colors.green,
              size: 16,
            ),
        ],
      ),
    );
  }

  Color _getConfettiColor(int index) {
    final colors = [
      Colors.purple,
      Colors.pink,
      Colors.blue,
      Colors.yellow,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }
}
