import 'package:cloud_firestore/cloud_firestore.dart';

class ProductService {
  final CollectionReference products = FirebaseFirestore.instance.collection(
    'products',
  );

  Stream<QuerySnapshot> getProducts() {
    return products.orderBy('createdAt', descending: true).snapshots();
  }

  List<String> _cleanCategories(dynamic categories) {
    final Map<String, String> cleaned = {};

    if (categories is List) {
      for (final item in categories) {
        final value = item.toString().trim();

        if (value.isNotEmpty) {
          cleaned[value.toLowerCase()] = value;
        }
      }
    } else if (categories != null) {
      final value = categories.toString().trim();

      if (value.isNotEmpty) {
        cleaned[value.toLowerCase()] = value;
      }
    }

    return cleaned.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> addProduct({
    required String name,
    required dynamic categories,
    required String description,
    required double price,
    required int stock,
    required String imageUrl,
  }) async {
    final catList = _cleanCategories(categories);

    await products.add({
      'name': name.trim(),
      'categories': catList,
      'description': description.trim(),
      'price': price,
      'stock': stock,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required dynamic categories,
    required String description,
    required double price,
    required int stock,
    required String imageUrl,
  }) async {
    final catList = _cleanCategories(categories);

    await products.doc(productId).update({
      'name': name.trim(),
      'categories': catList,
      'category': FieldValue.delete(),
      'description': description.trim(),
      'price': price,
      'stock': stock,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _syncFavoritesForProduct(
        productId: productId,
        name: name.trim(),
        categories: catList,
        description: description.trim(),
        price: price,
        stock: stock,
        imageUrl: imageUrl,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        rethrow;
      }
    }
  }

  Future<void> _syncFavoritesForProduct({
    required String productId,
    required String name,
    required List<String> categories,
    required String description,
    required double price,
    required int stock,
    required String imageUrl,
  }) async {
    final favoriteItems = await FirebaseFirestore.instance
        .collectionGroup('items')
        .where('productId', isEqualTo: productId)
        .get();

    for (final doc in favoriteItems.docs) {
      await doc.reference.update({
        'name': name,
        'categories': categories,
        'category': FieldValue.delete(),
        'description': description,
        'price': price,
        'stock': stock,
        'imageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> removeCategoryFromProducts(String category) async {
    final trimmed = category.trim();

    if (trimmed.isEmpty) return;

    final querySnapshot = await products
        .where('categories', arrayContains: trimmed)
        .get();

    for (final doc in querySnapshot.docs) {
      final productData = doc.data() as Map<String, dynamic>;

      final oldCategories = _cleanCategories(productData['categories']);

      final updatedCategories = oldCategories
          .where((value) => value.toLowerCase() != trimmed.toLowerCase())
          .toList();

      await products.doc(doc.id).update({
        'categories': updatedCategories,
        'category': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final favoriteItems = await FirebaseFirestore.instance
          .collectionGroup('items')
          .where('productId', isEqualTo: doc.id)
          .get();

      for (final favoriteDoc in favoriteItems.docs) {
        await favoriteDoc.reference.update({
          'categories': updatedCategories,
          'category': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> deleteProduct(String productId) async {
    await products.doc(productId).delete();
  }

  static Future<void> syncStockToFavorites(
    String productId,
    int newStock,
  ) async {
    try {
      final favorites = await FirebaseFirestore.instance
          .collectionGroup('items')
          .where('productId', isEqualTo: productId)
          .get();

      for (final doc in favorites.docs) {
        await doc.reference.update({
          'stock': newStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error syncing stock to favorites: $e');
    }
  }
}
