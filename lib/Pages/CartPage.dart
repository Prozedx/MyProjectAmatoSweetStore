import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:main_amato/Pages/my_orders_page.dart';
import 'package:main_amato/services/product_service.dart';
import 'package:main_amato/services/auth_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<String> selectedItems = {};

  Future<void> removeItem(String itemId) async {
    final user = AuthService().currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('carts')
        .doc(user.uid)
        .collection('items')
        .doc(itemId)
        .delete();
  }

  Future<void> updateQuantity(String itemId, int newQuantity) async {
    final user = AuthService().currentUser;
    if (user == null) return;

    if (newQuantity <= 0) {
      await removeItem(itemId);
      return;
    }

    await FirebaseFirestore.instance
        .collection('carts')
        .doc(user.uid)
        .collection('items')
        .doc(itemId)
        .update({
          'quantity': newQuantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> checkout(
    BuildContext context,
    List<QueryDocumentSnapshot> allItems,
  ) async {
    final selectedDocs = allItems
        .where((doc) => selectedItems.contains(doc.id))
        .toList();
    if (selectedDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select items to order')),
      );
      return;
    }
    final user = AuthService().currentUser;
    if (user == null) return;

    // Show loading dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final firestore = FirebaseFirestore.instance;
      final customerDoc = await firestore
          .collection('customers')
          .doc(user.uid)
          .get();
      final customer = customerDoc.data() ?? {};

      final List<Map<String, dynamic>> orderItems = [];

      await firestore.runTransaction((transaction) async {
        double total = 0;
        final List<Map<String, dynamic>> cartItems = [];

        for (final itemDoc in selectedDocs) {
          final item = itemDoc.data() as Map<String, dynamic>;

          final productId = item['productId']?.toString();
          if (productId == null || productId.isEmpty) {
            throw Exception('Invalid cart item');
          }

          final quantity = item['quantity'] is int
              ? item['quantity'] as int
              : int.tryParse(item['quantity']?.toString() ?? '') ?? 1;

          cartItems.add({
            'productId': productId,
            'quantity': quantity,
            'name': item['name'],
            'price': item['price'],
            'imageUrl': item['imageUrl'],
            'cartId': itemDoc.id,
          });
        }

        final Map<String, DocumentSnapshot> productSnapshots = {};

        for (final item in cartItems) {
          final productRef = firestore
              .collection('products')
              .doc(item['productId']);
          final productSnap = await transaction.get(productRef);
          productSnapshots[item['productId'] as String] = productSnap;
        }

        for (final item in cartItems) {
          final productId = item['productId'] as String;
          final productSnap = productSnapshots[productId]!;

          if (!productSnap.exists) {
            throw Exception('${item['name']} no longer exists');
          }

          final productData = productSnap.data() as Map<String, dynamic>;
          final currentStockRaw = productData['stock'];
          final currentStock = currentStockRaw is int
              ? currentStockRaw
              : int.tryParse(currentStockRaw?.toString() ?? '') ?? 0;

          final quantity = item['quantity'] as int;
          if (currentStock < quantity) {
            throw Exception('${item['name']} does not have enough stock');
          }

          final price = double.tryParse(item['price']?.toString() ?? '') ?? 0;
          total += price * quantity;

          final productRef = firestore.collection('products').doc(productId);
          transaction.update(productRef, {
            'stock': currentStock - quantity,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          orderItems.add({
            'productId': productId,
            'name': item['name'],
            'price': price,
            'quantity': quantity,
            'imageUrl': item['imageUrl'],
          });
        }

        final orderRef = firestore.collection('orders').doc();

        transaction.set(orderRef, {
          'userId': user.uid,
          'customerName': customer['username'] ?? 'Customer',
          'customerEmail': user.email ?? customer['email'] ?? '',
          'phone': customer['phone'] ?? '',
          'address': {
            'street': customer['street'] ?? '',
            'barangay': customer['barangay'] ?? '',
            'municipality': customer['municipality'] ?? '',
            'province': customer['province'] ?? '',
          },
          'items': orderItems,
          'total': total,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        for (final itemDoc in selectedDocs) {
          final cartRef = firestore
              .collection('carts')
              .doc(user.uid)
              .collection('items')
              .doc(itemDoc.id);

          transaction.delete(cartRef);
        }
      });

      // Sync stock updates to favorites for all affected products
      for (final item in orderItems) {
        final productId = item['productId'] as String;
        final productSnap = await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .get();

        if (productSnap.exists) {
          final stock = productSnap.data()?['stock'] ?? 0;
          await ProductService.syncStockToFavorites(productId, stock as int);
        }
      }

      if (!context.mounted) return;

      setState(() {
        selectedItems.clear();
      });

      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Checkout successful')));

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyOrdersPage()),
      );
    } catch (e) {
      if (!context.mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    }
  }

  Future<void> _refreshCart() async {
    // This triggers a refresh of the StreamBuilder by rebuilding
    // The StreamBuilder will re-listen to the stream
    setState(() {});

    // Add a small delay for UX feedback
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Widget _buildCartBody(User? user) {
    if (user == null) {
      return const Center(
        child: Text(
          'Please login first',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshCart,
      color: const Color(0xFFF267AF),
      backgroundColor: Colors.white,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('carts')
            .doc(user.uid)
            .collection('items')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading cart: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _refreshCart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data?.docs ?? [];

          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Your cart is empty',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }

          double total = 0;

          for (final doc in items) {
            if (selectedItems.contains(doc.id)) {
              final data = doc.data() as Map<String, dynamic>;
              final price = double.tryParse(data['price'].toString()) ?? 0;
              final qty = data['quantity'] ?? 1;
              total += price * qty;
            }
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final doc = items[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final quantity = data['quantity'] ?? 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selectedItems.contains(doc.id),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedItems.add(doc.id);
                                } else {
                                  selectedItems.remove(doc.id);
                                }
                              });
                            },
                            activeColor: const Color(0xFFF267AF),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              data['imageUrl'] ?? '',
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 70,
                                  height: 70,
                                  color: const Color(0xFFFFC1C1),
                                  child: const Icon(Icons.image),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text('₱${data['price']}'),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          updateQuantity(doc.id, quantity - 1),
                                      icon: const Icon(Icons.remove, size: 16),
                                    ),
                                    Text('Qty: $quantity'),
                                    IconButton(
                                      onPressed: () =>
                                          updateQuantity(doc.id, quantity + 1),
                                      icon: const Icon(Icons.add, size: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Remove Item'),
                                  content: const Text(
                                    'Are you sure you want to remove this item from the cart?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        removeItem(doc.id);
                                      },
                                      child: const Text(
                                        'Remove',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.delete,
                              color: Color(0xFFF267AF),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 80,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.lexend(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₱${total.toStringAsFixed(2)}',
                          style: GoogleFonts.lexend(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF267AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: selectedItems.isNotEmpty
                            ? () => checkout(context, items)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedItems.isNotEmpty
                              ? const Color(0xFFF267AF)
                              : Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('ORDER/BUY'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF267AF)),
        title: Text(
          'My Cart',
          style: GoogleFonts.lexend(
            color: const Color(0xFFF267AF),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFFE5B4), Color(0xFFF267AF)],
          ),
        ),
        child: _buildCartBody(user),
      ),
    );
  }
}
