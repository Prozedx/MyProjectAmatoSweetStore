import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:main_amato/services/auth_service.dart';

import 'product_details_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Set<String>
  _syncedFavorites; // Track which favorites have been synced in this build

  @override
  void initState() {
    super.initState();
    _syncedFavorites = {};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Clear synced set when navigating back to this page
    _syncedFavorites.clear();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Widget _imagePlaceholder({double size = 80}) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFFFC1C1),
      child: const Icon(Icons.image, color: Color(0xFFF267AF)),
    );
  }

  Future<void> _removeFavorite(DocumentReference reference) async {
    try {
      await reference.delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove favorite: $e')));
    }
  }

  Future<void> _syncFavoriteStock({
    required DocumentReference favoriteRef,
    required int favoriteStock,
    required int productStock,
    required String favoriteId,
  }) async {
    // Only sync if stocks differ AND we haven't synced this favorite yet in this build
    if (favoriteStock == productStock ||
        _syncedFavorites.contains(favoriteId)) {
      return;
    }

    _syncedFavorites.add(
      favoriteId,
    ); // Mark as synced to prevent duplicate calls

    try {
      await favoriteRef.update({
        'stock': productStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ignore sync failure. UI still shows live product stock.
      _syncedFavorites.remove(
        favoriteId,
      ); // Remove from synced set to retry next build
    }
  }

  Future<void> _refreshFavorites() async {
    setState(() {
      _syncedFavorites.clear();
    });
    await Future.delayed(const Duration(milliseconds: 500));
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
              : RefreshIndicator(
                  onRefresh: _refreshFavorites,
                  color: const Color(0xFFF267AF),
                  backgroundColor: Colors.white,
                  child: StreamBuilder<QuerySnapshot>(
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

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load favorites: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
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
                          final data =
                              doc.data() as Map<String, dynamic>? ?? {};
                          final productId = data['productId']?.toString() ?? '';
                          final favoriteStock = _toInt(data['stock']);

                          if (productId.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('products')
                                .doc(productId)
                                .snapshots(),
                            builder: (context, productSnapshot) {
                              if (productSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFF267AF),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Loading product...'),
                                    ],
                                  ),
                                );
                              }

                              if (productSnapshot.hasError) {
                                return const SizedBox.shrink();
                              }

                              if (productSnapshot.data == null ||
                                  !productSnapshot.data!.exists) {
                                Future.microtask(
                                  () => _removeFavorite(doc.reference),
                                );
                                return const SizedBox.shrink();
                              }

                              final productData =
                                  productSnapshot.data!.data()
                                      as Map<String, dynamic>? ??
                                  {};

                              final displayStock = _toInt(
                                productData['stock'],
                                fallback: favoriteStock,
                              );

                              _syncFavoriteStock(
                                favoriteRef: doc.reference,
                                favoriteStock: favoriteStock,
                                productStock: displayStock,
                                favoriteId: doc.id,
                              );

                              final imageUrl =
                                  (productData['imageUrl'] ??
                                          data['imageUrl'] ??
                                          '')
                                      .toString();
                              final name =
                                  (productData['name'] ??
                                          data['name'] ??
                                          'Unnamed Product')
                                      .toString();
                              final description =
                                  (productData['description'] ??
                                          data['description'] ??
                                          '')
                                      .toString();
                              final price = _toDouble(
                                productData['price'] ?? data['price'],
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color.fromRGBO(0, 0, 0, 0.1),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: imageUrl.isEmpty
                                          ? _imagePlaceholder()
                                          : Image.network(
                                              imageUrl,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              loadingBuilder:
                                                  (
                                                    context,
                                                    child,
                                                    loadingProgress,
                                                  ) {
                                                    if (loadingProgress ==
                                                        null) {
                                                      return child;
                                                    }
                                                    return _imagePlaceholder();
                                                  },
                                              errorBuilder: (_, _, _) {
                                                return _imagePlaceholder();
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
                                              builder: (_) =>
                                                  ProductDetailsPage(
                                                    productId: productId,
                                                    imageUrl: imageUrl,
                                                    title: name,
                                                    description: description,
                                                    price: price,
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
                                              name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              '₱${price.toStringAsFixed(2)}',
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
                                      onPressed: () =>
                                          _removeFavorite(doc.reference),
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
      ),
    );
  }
}
