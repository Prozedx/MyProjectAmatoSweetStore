import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:main_amato/services/product_service.dart';
import 'package:main_amato/services/auth_service.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  String selectedStatus = 'pending';

  Color statusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'intransit':
        return Colors.orange;
      default:
        return const Color(0xFFF267AF);
    }
  }

  Widget statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor(status).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: statusColor(status)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.lexend(
          color: statusColor(status),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget statusFilterButtons() {
    final statuses = ['pending', 'intransit', 'delivered', 'cancelled'];
    final labels = ['Pending', 'In Transit', 'Delivered', 'Cancelled'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(statuses.length, (index) {
        final status = statuses[index];
        final isActive = selectedStatus == status;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 8,
              right: index == statuses.length - 1 ? 0 : 0,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFFFFE5B4), Color(0xFFF267AF)],
                      )
                    : null,
                color: isActive ? null : Colors.white70,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? Colors.white : Colors.transparent,
                  width: isActive ? 2 : 0,
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedStatus = status;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: isActive ? Colors.white : Colors.black54,
                  elevation: isActive ? 4 : 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  labels[index],
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _refreshOrders() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _showCancelConfirmation({
    required BuildContext context,
    required String orderId,
    required Map<String, dynamic> data,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      await cancelOrder(context: context, orderId: orderId, data: data);
    }
  }

  Future<void> cancelOrder({
    required BuildContext context,
    required String orderId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final items = data['items'] as List<dynamic>? ?? [];

      // READ PHASE: Fetch all product data before transaction
      final productUpdates = <String, Map<String, dynamic>>{};
      for (final item in items) {
        final product = item as Map<String, dynamic>;
        final productId = product['productId'] as String;
        final productRef = firestore.collection('products').doc(productId);

        final productSnap = await productRef.get();
        if (productSnap.exists) {
          final productData = productSnap.data() as Map<String, dynamic>;
          final currentStock = productData['stock'] ?? 0;
          final quantity = product['quantity'] ?? 1;

          productUpdates[productId] = {
            'stock': currentStock + quantity,
            'updatedAt': FieldValue.serverTimestamp(),
          };
        }
      }

      // WRITE PHASE: Enter transaction with all reads complete
      await firestore.runTransaction((transaction) async {
        final orderRef = firestore.collection('orders').doc(orderId);

        // Apply all product updates
        for (final productId in productUpdates.keys) {
          final productRef = firestore.collection('products').doc(productId);
          transaction.update(productRef, productUpdates[productId]!);
        }

        // Update order status
        transaction.update(orderRef, {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Sync stock updates to favorites for all affected products
      for (final productId in productUpdates.keys) {
        final newStock = productUpdates[productId]!['stock'] as int?;
        if (newStock != null) {
          await ProductService.syncStockToFavorites(productId, newStock);
        }
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order cancelled')));
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
    }
  }

  Widget orderCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final status = data['status']?.toString() ?? 'pending';
    final total = data['total'] ?? 0;
    final createdAt = data['createdAt'] as Timestamp?;

    final orderDate = createdAt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toDate())
        : 'No date';
    final items = data['items'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFFF267AF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Order',
                  style: GoogleFonts.lexend(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              statusBadge(status),
              const SizedBox(height: 10),

              Text(
                orderDate,
                style: GoogleFonts.lexend(color: Colors.black54, fontSize: 11),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'Items',
            style: GoogleFonts.lexend(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 6),

          if (items.isEmpty)
            Text(
              'No items listed',
              style: GoogleFonts.lexend(color: Colors.black54),
            )
          else
            ...items.map((item) {
              final product = item as Map<String, dynamic>;

              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${product['quantity']}x ${product['name']} - ₱${product['price']}',
                  style: GoogleFonts.lexend(
                    color: Colors.black87,
                    fontSize: 12,
                  ),
                ),
              );
            }),

          const SizedBox(height: 12),

          Text(
            'Total: ₱$total',
            style: GoogleFonts.lexend(
              color: const Color(0xFFF267AF),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 14),

          if (status == 'pending')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showCancelConfirmation(
                  context: context,
                  orderId: doc.id,
                  data: data,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('CANCEL ORDER'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFFF267AF)),
        title: Text(
          'My Orders',
          style: GoogleFonts.lexend(
            color: const Color(0xFFF267AF),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFFE5B4), Color(0xFFF267AF)],
          ),
        ),
        child: user == null
            ? const Center(
                child: Text(
                  'Please login first',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : RefreshIndicator(
                onRefresh: _refreshOrders,
                color: const Color(0xFFF267AF),
                backgroundColor: Colors.white,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .where('userId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading orders: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _refreshOrders,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    final orders = snapshot.data?.docs ?? [];
                    final filteredOrders = orders.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status']?.toString() ?? 'pending';
                      return status == selectedStatus;
                    }).toList();

                    if (filteredOrders.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          statusFilterButtons(),
                          const SizedBox(height: 18),
                          Center(
                            child: Text(
                              'No ${selectedStatus == 'intransit'
                                  ? 'In Transit'
                                  : selectedStatus == 'delivered'
                                  ? 'Delivered'
                                  : 'Pending'} orders yet',
                              style: GoogleFonts.lexend(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        statusFilterButtons(),
                        const SizedBox(height: 18),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredOrders.length,
                            itemBuilder: (context, index) {
                              return orderCard(context, filteredOrders[index]);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}
