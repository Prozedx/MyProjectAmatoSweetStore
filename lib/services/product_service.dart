import 'package:cloud_firestore/cloud_firestore.dart';

class ProductService {
  final CollectionReference products = FirebaseFirestore.instance.collection(
    'products',
  );

  // GET PRODUCTS
  Stream<QuerySnapshot> getProducts() {
    return products.orderBy('createdAt', descending: true).snapshots();
  }

  // ADD PRODUCT
  Future<void> addProduct({
    required String name,
    required dynamic categories, // String or List<String>
    required String description,
    required double price,
    required int stock,
    required String imageUrl,
  }) async {
    // Normalize categories to List<String>
    final List<String> catList = categories is List
        ? List<String>.from(categories)
        : [categories.toString()];

    await products.add({
      'name': name,
      'categories': catList,
      'category': catList.isNotEmpty
          ? catList.first
          : '', // Keep for backward compatibility
      'description': description,
      'price': price,
      'stock': stock,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // UPDATE PRODUCT
  Future<void> updateProduct({
    required String productId,
    required String name,
    required dynamic categories, // String or List<String>
    required String description,
    required double price,
    required int stock,
    required String imageUrl,
  }) async {
    // Normalize categories to List<String>
    final List<String> catList = categories is List
        ? List<String>.from(categories)
        : [categories.toString()];

    await products.doc(productId).update({
      'name': name,
      'categories': catList,
      'category': catList.isNotEmpty
          ? catList.first
          : '', // Keep for backward compatibility
      'description': description,
      'price': price,
      'stock': stock,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _syncFavoritesForProduct(
        productId: productId,
        name: name,
        categories: catList,
        description: description,
        price: price,
        stock: stock,
        imageUrl: imageUrl,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        rethrow;
      }
      // Permissions may prevent updating nested cart/favorite item documents.
      // We keep the main product update, but avoid failing the whole operation.
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
    final favorites = await FirebaseFirestore.instance
        .collectionGroup('items')
        .where('productId', isEqualTo: productId)
        .get();

    for (final doc in favorites.docs) {
      await doc.reference.update({
        'name': name,
        'categories': categories,
        'category': categories.isNotEmpty
            ? categories.first
            : '', // Keep for backward compatibility
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
      final oldCategories =
          (productData['categories'] as List?)
              ?.whereType<dynamic>()
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList() ??
          [];

      final updatedCategories = oldCategories
          .where((value) => value != trimmed)
          .toList()
          .cast<String>();

      await products.doc(doc.id).update({
        'categories': updatedCategories,
        'category': updatedCategories.isNotEmpty ? updatedCategories.first : '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update favorites copies for the same product too.
      final favoriteItems = await FirebaseFirestore.instance
          .collectionGroup('items')
          .where('productId', isEqualTo: doc.id)
          .get();

      for (final favoriteDoc in favoriteItems.docs) {
        await favoriteDoc.reference.update({
          'categories': updatedCategories,
          'category': updatedCategories.isNotEmpty
              ? updatedCategories.first
              : '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // DELETE PRODUCT
  Future<void> deleteProduct(String productId) async {
    await products.doc(productId).delete();
  }

  // SYNC STOCK TO FAVORITES (called after stock changes from orders)
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
      // Log but don't fail the operation
      print('Error syncing stock to favorites: $e');
    }
  }
}
