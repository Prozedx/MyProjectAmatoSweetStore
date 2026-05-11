import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  Future<int> getTotalOrders() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .get();
    return snapshot.docs.length;
  }

  Future<int> getOrdersByStatus(String status) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: status)
        .get();

    return snapshot.docs.length;
  }

  Future<double> getTotalEarnings() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'delivered')
        .get();

    double total = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      total += (data['total'] ?? 0).toDouble();
    }

    return total;
  }

  Future<double> getLastWeekEarnings() async {
    final lastWeek = DateTime.now().subtract(const Duration(days: 7));

    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'delivered')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(lastWeek),
        )
        .get();

    double total = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      total += (data['total'] ?? 0).toDouble();
    }

    return total;
  }

  Future<int> getTotalProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .get();
    return snapshot.docs.length;
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.lexend(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.lexend(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget header() {
    return Column(
      children: [
        Image.asset('assets/images/sakuraImage.png', height: 70),
        const SizedBox(height: 8),
        Text(
          'AMATO ADMIN',
          style: GoogleFonts.lexendZetta(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Dashboard Overview',
          style: GoogleFonts.lexend(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget earningsCard() {
    return FutureBuilder<double>(
      future: getTotalEarnings(),
      builder: (context, snapshot) {
        final earnings = snapshot.data ?? 0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFC1C1), Color(0xFFFF8A8A)],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.payments, color: Colors.white, size: 42),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivered Earnings',
                      style: GoogleFonts.lexend(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₱${earnings.toStringAsFixed(2)}',
                      style: GoogleFonts.lexend(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget recentOrdersPreview() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        final orders = snapshot.data?.docs ?? [];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Orders',
                style: GoogleFonts.lexend(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 12),

              if (orders.isEmpty)
                Text(
                  'No recent orders yet',
                  style: GoogleFonts.lexend(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                )
              else
                ...orders.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            data['customerName'] ?? 'Customer',
                            style: GoogleFonts.lexend(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          status.toString().toUpperCase(),
                          style: GoogleFonts.lexend(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
          child: Column(
            children: [
              header(),

              const SizedBox(height: 25),

              earningsCard(),

              const SizedBox(height: 14),

              FutureBuilder<double>(
                future: getLastWeekEarnings(),
                builder: (context, snapshot) {
                  final earnings = snapshot.data ?? 0;

                  return statCard(
                    title: 'Last 7 Days Earnings',
                    value: '₱${earnings.toStringAsFixed(2)}',
                    icon: Icons.trending_up,
                  );
                },
              ),

              const SizedBox(height: 18),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.18,
                children: [
                  FutureBuilder<int>(
                    future: getTotalOrders(),
                    builder: (context, snapshot) {
                      return statCard(
                        title: 'Total Orders',
                        value: '${snapshot.data ?? 0}',
                        icon: Icons.shopping_bag,
                      );
                    },
                  ),
                  FutureBuilder<int>(
                    future: getOrdersByStatus('pending'),
                    builder: (context, snapshot) {
                      return statCard(
                        title: 'Pending',
                        value: '${snapshot.data ?? 0}',
                        icon: Icons.pending_actions,
                      );
                    },
                  ),
                  FutureBuilder<int>(
                    future: getOrdersByStatus('intransit'),
                    builder: (context, snapshot) {
                      return statCard(
                        title: 'In Transit',
                        value: '${snapshot.data ?? 0}',
                        icon: Icons.local_shipping,
                      );
                    },
                  ),
                  FutureBuilder<int>(
                    future: getOrdersByStatus('delivered'),
                    builder: (context, snapshot) {
                      return statCard(
                        title: 'Delivered',
                        value: '${snapshot.data ?? 0}',
                        icon: Icons.check_circle,
                      );
                    },
                  ),
                  FutureBuilder<int>(
                    future: getOrdersByStatus('cancelled'),
                    builder: (context, snapshot) {
                      return statCard(
                        title: 'Cancelled',
                        value: '${snapshot.data ?? 0}',
                        icon: Icons.cancel,
                      );
                    },
                  ),
                  FutureBuilder<int>(
                    future: getTotalProducts(),
                    builder: (context, snapshot) {
                      return statCard(
                        title: 'Products',
                        value: '${snapshot.data ?? 0}',
                        icon: Icons.inventory_2,
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 18),

              recentOrdersPreview(),
            ],
          ),
        ),
      ),
    );
  }
}
