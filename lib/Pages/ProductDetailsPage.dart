import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:main_amato/services/product_service.dart';

class ProductDetailsPage extends StatefulWidget {
  final String productId;
  final String imageUrl;
  final String title;
  final String description;
  final dynamic price;
  final int stock;

  const ProductDetailsPage({
    super.key,
    required this.productId,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.price,
    required this.stock,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  int quantity = 1;
  bool isLoading = false;

  double get price => double.tryParse(widget.price.toString()) ?? 0;
  double get total => price * quantity;

  void increaseQuantity() {
    if (quantity < widget.stock) {
      setState(() => quantity++);
    }
  }

  void decreaseQuantity() {
    if (quantity > 1) {
      setState(() => quantity--);
    }
  }

  Future<void> addToCart() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    try {
      final cartRef = FirebaseFirestore.instance
          .collection('carts')
          .doc(user.uid)
          .collection('items')
          .doc(widget.productId);

      final cartDoc = await cartRef.get();

      if (cartDoc.exists) {
        final currentQty = cartDoc.data()?['quantity'] ?? 0;
        final newQty = currentQty + quantity;

        if (newQty > widget.stock) {
          if (!mounted) return;

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Not enough stock')));
          return;
        }

        await cartRef.update({
          'quantity': newQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await cartRef.set({
          'productId': widget.productId,
          'name': widget.title,
          'price': price,
          'quantity': quantity,
          'imageUrl': widget.imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to cart')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add to cart failed: $e')));
    }
  }

  Future<void> buyNow() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    try {
      setState(() => isLoading = true);

      final firestore = FirebaseFirestore.instance;

      final customerDoc = await firestore
          .collection('customers')
          .doc(user.uid)
          .get();

      final customer = customerDoc.data() ?? {};

      await firestore.runTransaction((transaction) async {
        final productRef = firestore
            .collection('products')
            .doc(widget.productId);

        final productSnap = await transaction.get(productRef);

        if (!productSnap.exists) {
          throw Exception('Product no longer exists');
        }

        final productData = productSnap.data() as Map<String, dynamic>;
        final currentStock = productData['stock'] ?? 0;

        if (currentStock < quantity) {
          throw Exception('Not enough stock available');
        }

        transaction.update(productRef, {
          'stock': currentStock - quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });

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
          'items': [
            {
              'productId': widget.productId,
              'name': widget.title,
              'price': price,
              'quantity': quantity,
              'imageUrl': widget.imageUrl,
            },
          ],
          'total': total,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Sync stock update to favorites
      final productSnap = await firestore
          .collection('products')
          .doc(widget.productId)
          .get();

      if (productSnap.exists) {
        final stock = productSnap.data()?['stock'] ?? 0;
        await ProductService.syncStockToFavorites(
          widget.productId,
          stock as int,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Order failed: $e')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> toggleFavorite(bool isFavorite) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    final favRef = FirebaseFirestore.instance
        .collection('favorites')
        .doc(user.uid)
        .collection('items')
        .doc(widget.productId);

    if (isFavorite) {
      await favRef.delete();
    } else {
      await favRef.set({
        'productId': widget.productId,
        'name': widget.title,
        'imageUrl': widget.imageUrl,
        'price': price,
        'stock': widget.stock,
        'description': widget.description,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> canReviewProduct() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    final orders = await FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'delivered')
        .get();

    for (final order in orders.docs) {
      final data = order.data();
      final items = data['items'] as List<dynamic>? ?? [];

      for (final item in items) {
        final product = item as Map<String, dynamic>;

        if (product['productId'] == widget.productId) {
          return true;
        }
      }
    }

    return false;
  }

  Future<void> showReviewDialog() async {
    final canReview = await canReviewProduct();

    if (!canReview) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can review only after this product is delivered.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;
    if (!mounted) return;

    int rating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Write a Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: () {
                          setDialogState(() {
                            rating = index + 1;
                          });
                        },
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Write your comment...',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final customerDoc = await FirebaseFirestore.instance
                        .collection('customers')
                        .doc(user.uid)
                        .get();

                    final customer = customerDoc.data() ?? {};

                    await FirebaseFirestore.instance
                        .collection('reviews')
                        .doc('${widget.productId}_${user.uid}')
                        .set({
                          'productId': widget.productId,
                          'userId': user.uid,
                          'username': customer['username'] ?? 'Customer',
                          'rating': rating,
                          'comment': commentController.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                    if (!context.mounted) return;

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Review submitted')),
                    );
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget reviewsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('productId', isEqualTo: widget.productId)
          .snapshots(),
      builder: (context, snapshot) {
        final reviews = snapshot.data?.docs ?? [];

        if (reviews.isEmpty) {
          return Text(
            'No reviews yet',
            style: GoogleFonts.lexend(color: Colors.white70),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: reviews.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final rating = data['rating'] ?? 0;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color.fromRGBO(255, 255, 255, 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['username'] ?? 'Customer',
                    style: GoogleFonts.lexend(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 18,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['comment'] ?? '',
                    style: GoogleFonts.lexend(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget quantityButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: const Color(0xFFF267AF), size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasStock = widget.stock > 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFFD0B6), Color(0xFFFF79AE)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  // Product Image with rounded bottom corners
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 400,
                          width: double.infinity,
                          child: widget.imageUrl.isNotEmpty
                              ? Image.network(
                                  widget.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) {
                                    return const Center(
                                      child: Icon(
                                        Icons.image,
                                        color: Colors.white,
                                        size: 80,
                                      ),
                                    );
                                  },
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.white,
                                    size: 80,
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 50,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [Color(0xFFFFFFFF), Color(0xFFFF8080)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds),
                              child: Text(
                                '甘党',
                                style: GoogleFonts.lexendZetta(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    const Shadow(
                                      color: Color.fromRGBO(0, 0, 0, 0.5),
                                      offset: Offset(2, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Product Details Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFF8CAF), Color(0xFFFF79AE)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '"${widget.title}"',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.lexend(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '₱${price.toStringAsFixed(0)}',
                              style: GoogleFonts.lexend(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.description.isEmpty
                              ? 'No description available.'
                              : widget.description,
                          style: GoogleFonts.lexend(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasStock
                              ? 'Available Stock: ${widget.stock}'
                              : 'Out of Stock',
                          style: GoogleFonts.lexend(
                            color: hasStock
                                ? Colors.white
                                : Colors.red.shade100,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: showReviewDialog,
                            icon: const Icon(Icons.rate_review),
                            label: Text(
                              'Write Review',
                              style: GoogleFonts.lexend(),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'REVIEWS',
                          style: GoogleFonts.lexend(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        reviewsSection(),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            'PORTION',
                            style: GoogleFonts.lexend(
                              color: Colors.white70,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (hasStock)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              quantityButton(
                                icon: Icons.remove,
                                onTap: decreaseQuantity,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                quantity.toString(),
                                style: GoogleFonts.lexend(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 14),
                              quantityButton(
                                icon: Icons.add,
                                onTap: increaseQuantity,
                              ),
                            ],
                          ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseAuth.instance.currentUser == null
                                ? null
                                : FirebaseFirestore.instance
                                      .collection('favorites')
                                      .doc(
                                        FirebaseAuth.instance.currentUser!.uid,
                                      )
                                      .collection('items')
                                      .doc(widget.productId)
                                      .snapshots(),
                            builder: (context, snapshot) {
                              final isFavorite = snapshot.data?.exists ?? false;

                              return GestureDetector(
                                onTap: () => toggleFavorite(isFavorite),
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: const BoxDecoration(
                                    color: Color.fromRGBO(255, 255, 255, 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isFavorite
                                        ? const Color(0xFFFFA5D0)
                                        : Colors.white,
                                    size: 30,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 58,
                                child: ElevatedButton(
                                  onPressed: hasStock && !isLoading
                                      ? buyNow
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFE5B4),
                                    foregroundColor: const Color(0xFFF267AF),
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    isLoading
                                        ? 'Processing...'
                                        : hasStock
                                        ? 'Buy now'
                                        : 'Out of Stock',
                                    style: GoogleFonts.lexend(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 58,
                                child: ElevatedButton(
                                  onPressed: hasStock ? addToCart : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFFF267AF),
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                        color: Color(0xFFFFE5B4),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Add To Cart',
                                    style: GoogleFonts.lexend(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Back Button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color.fromRGBO(0, 0, 0, 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
