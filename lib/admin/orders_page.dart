import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String selectedStatus = 'all';

  Future<void> updateStatus(String orderId, String status) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

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

  Stream<QuerySnapshot> getOrdersStream() {
    final orders = FirebaseFirestore.instance.collection('orders');

    if (selectedStatus == 'all') {
      return orders.orderBy('createdAt', descending: true).snapshots();
    }

    return orders.where('status', isEqualTo: selectedStatus).snapshots();
  }

  Widget filterChip(String label, String value) {
    final isSelected = selectedStatus == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedStatus = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.lexend(
            color: isSelected ? const Color(0xFFF267AF) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget orderTimeline(String status) {
    if (status == 'cancelled') {
      return const Text(
        'Order Cancelled',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      );
    }

    final steps = ['pending', 'intransit', 'delivered'];
    final labels = ['Pending', 'In Transit', 'Delivered'];

    int activeIndex = steps.indexOf(status);
    if (activeIndex < 0) activeIndex = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length, (index) {
        final isActive = index <= activeIndex;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                isActive ? Icons.check_circle : Icons.circle_outlined,
                color: isActive ? const Color(0xFFF267AF) : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                labels[index],
                style: TextStyle(
                  color: isActive ? const Color(0xFFF267AF) : Colors.grey,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget orderCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final customerName = data['customerName'] ?? 'Customer';
    final email = data['customerEmail'] ?? '';
    final total = data['total'] ?? 0;
    final status = data['status'] ?? 'pending';
    final phone = data['phone'] ?? '';
    final address = data['address'] as Map<String, dynamic>? ?? {};
    final items = data['items'] as List<dynamic>? ?? [];
    final createdAt = data['createdAt'] as Timestamp?;
    final orderDate = createdAt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toDate())
        : 'No date';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  customerName.toString(),
                  style: GoogleFonts.lexend(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          orderTimeline(status.toString()),

          Text(
            orderDate,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 10),

          Text(
            email.toString(),
            style: GoogleFonts.lexend(color: Colors.white70, fontSize: 12),
          ),

          const SizedBox(height: 6),

          Text(
            'Phone: $phone',
            style: GoogleFonts.lexend(color: Colors.white70, fontSize: 12),
          ),

          const SizedBox(height: 6),

          Text(
            '${address['street'] ?? ''}, ${address['barangay'] ?? ''}, ${address['municipality'] ?? ''}, ${address['province'] ?? ''}',
            style: GoogleFonts.lexend(color: Colors.white70, fontSize: 12),
          ),

          const SizedBox(height: 12),

          Text(
            'Items',
            style: GoogleFonts.lexend(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 6),

          if (items.isEmpty)
            Text(
              'No items listed',
              style: GoogleFonts.lexend(color: Colors.white70, fontSize: 12),
            )
          else
            ...items.map((item) {
              final product = item as Map<String, dynamic>;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${product['quantity']}x ${product['name']} - ₱${product['price']}',
                  style: GoogleFonts.lexend(color: Colors.white, fontSize: 12),
                ),
              );
            }),

          const SizedBox(height: 12),

          Text(
            'Total: ₱$total',
            style: GoogleFonts.lexend(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            initialValue: status.toString(),
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.85),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'intransit', child: Text('In Transit')),
              DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
            onChanged: (value) async {
              if (value == null) return;

              await updateStatus(doc.id, value);

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order status updated')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Orders',
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                filterChip('All', 'all'),
                filterChip('Pending', 'pending'),
                filterChip('In Transit', 'intransit'),
                filterChip('Delivered', 'delivered'),
                filterChip('Cancelled', 'cancelled'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading orders',
                      style: GoogleFonts.lexend(color: Colors.white),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final orders = snapshot.data!.docs;

                // Sort by createdAt descending
                orders.sort((a, b) {
                  final aTime =
                      (a.data() as Map<String, dynamic>)['createdAt']
                          as Timestamp?;
                  final bTime =
                      (b.data() as Map<String, dynamic>)['createdAt']
                          as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime); // Descending order
                });

                if (orders.isEmpty) {
                  return Center(
                    child: Text(
                      'No $selectedStatus orders',
                      style: GoogleFonts.lexend(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return orderCard(context, orders[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
