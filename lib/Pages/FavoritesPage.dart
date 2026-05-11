import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ProductDetailsPage.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final Set<String> _syncedFavorites = {};

  Future<void> _syncFavoriteStockIfNeeded(
    DocumentSnapshot favoriteDoc,
    int currentStock,
  ) async {
    final docId = favoriteDoc.id;
    final data = favoriteDoc.data() as Map<String, dynamic>;
    final oldStock = data['stock'] is int
        ? data['stock'] as int
        : int.tryParse(data['stock']?.toString() ?? '') ?? currentStock;

    if (oldStock == currentStock || _syncedFavorites.contains(docId)) {
      return;
    }

    _syncedFavorites.add(docId);

    try {
      await favoriteDoc.reference.update({
        'stock': currentStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ignore sync failures; favorites will still display current stock.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF267AF)),
        title: Text(
          'My Favorites',
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
            colors: [Color(0xFFFFD0B6), Color(0xFFFF79AE)],
          ),
        ),
        child: SafeArea(
          child: user == null
              ? const Center(
                  child: Text(
                    'Please login first',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('favorites')
                      .doc(user.uid)
                      .collection('items')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    final favorites = snapshot.data?.docs ?? [];

                    if (favorites.isEmpty) {
                      return const Center(
                        child: Text(
                          'No favorites yet',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final doc = favorites[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final productId = data['productId']?.toString() ?? '';
                        final favoriteStock = data['stock'] is int
                            ? data['stock'] as int
                            : int.tryParse(data['stock']?.toString() ?? '') ??
                                  0;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('products')
                              .doc(productId)
                              .get(),
                          builder: (context, productSnapshot) {
                            // If product no longer exists, don't display it
                            if (productSnapshot.connectionState ==
                                    ConnectionState.done &&
                                !productSnapshot.data!.exists) {
                              // Remove from favorites if product was deleted
                              doc.reference.delete();
                              return const SizedBox.shrink();
                            }

                            var displayStock = favoriteStock;
                            if (productSnapshot.connectionState ==
                                ConnectionState.done) {
                              final productData = productSnapshot.data?.data();
                              if (productData is Map<String, dynamic>) {
                                final currentStock = productData['stock'] is int
                                    ? productData['stock'] as int
                                    : int.tryParse(
                                            productData['stock']?.toString() ??
                                                '',
                                          ) ??
                                          favoriteStock;

                                if (currentStock != favoriteStock) {
                                  _syncFavoriteStockIfNeeded(doc, currentStock);
                                  displayStock = currentStock;
                                }
                              }
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color.fromRGBO(0, 0, 0, 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      data['imageUrl'] ?? '',
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              width: 80,
                                              height: 80,
                                              color: const Color(0xFFFFC1C1),
                                              child: const Icon(Icons.image),
                                            );
                                          },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProductDetailsPage(
                                              productId: data['productId'],
                                              imageUrl: data['imageUrl'] ?? '',
                                              title: data['name'] ?? '',
                                              description:
                                                  data['description'] ?? '',
                                              price: data['price'] ?? 0,
                                              stock: displayStock,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['name'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            '₱${data['price']}',
                                            style: const TextStyle(
                                              color: Color(0xFFF267AF),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text('Stock: $displayStock'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      await FirebaseFirestore.instance
                                          .collection('favorites')
                                          .doc(user.uid)
                                          .collection('items')
                                          .doc(doc.id)
                                          .delete();
                                    },
                                    icon: const Icon(
                                      Icons.favorite,
                                      color: Color(0xFFFFA5D0),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}
