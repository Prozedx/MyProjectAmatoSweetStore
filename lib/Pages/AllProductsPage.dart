import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'product_details_page.dart';

class AllProductsPage extends StatelessWidget {
  const AllProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF79AE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF267AF)),
        title: const Text(
          'All Products',
          style: TextStyle(
            color: Color(0xFFF267AF),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFFD0B6), Color(0xFFFF79AE)],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            final products = snapshot.data?.docs ?? [];

            if (products.isEmpty) {
              return const Center(
                child: Text(
                  'No products available',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.only(bottom: 30),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, index) {
                final doc = products[index];
                final data = doc.data() as Map<String, dynamic>;

                final imageUrl = data['imageUrl']?.toString() ?? '';
                final name = data['name']?.toString() ?? '';
                final description = data['description']?.toString() ?? '';
                final price = data['price'] ?? 0;
                final stockRaw = data['stock'] ?? 0;
                final stock = stockRaw is int
                    ? stockRaw
                    : int.tryParse(stockRaw.toString()) ?? 0;

                return GestureDetector(
                  onTap: stock <= 0
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailsPage(
                                productId: doc.id,
                                imageUrl: imageUrl,
                                title: name,
                                description: description,
                                price: price,
                                stock: stock,
                              ),
                            ),
                          );
                        },
                  child: Opacity(
                    opacity: stock <= 0 ? 0.55 : 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: const Color(0xFFFFC1C1),
                                      child: const Icon(
                                        Icons.image,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  stock <= 0
                                      ? 'Out of stock'
                                      : '₱$price | Stock: $stock',
                                  style: TextStyle(
                                    color: stock <= 0
                                        ? Colors.red
                                        : const Color(0xFFF267AF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
