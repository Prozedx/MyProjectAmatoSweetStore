import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final List<String> defaultCategories = [
    'JP Desserts',
    'Pastry',
    'Parfait',
  ];

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  static List<String> _cleanCategoryList(List rawList) {
    final Map<String, String> cleaned = {};

    for (final item in rawList) {
      final value = item.toString().trim();

      if (value.isEmpty) continue;

      cleaned[_normalize(value)] = value;
    }

    return cleaned.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  static Future<List<String>> fetchAllCategories() async {
    final Map<String, String> categories = {};

    for (final category in defaultCategories) {
      categories[_normalize(category)] = category;
    }

    final snapshot = await _firestore.collection('categories').get();

    for (final doc in snapshot.docs) {
      final name = doc.data()['name']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        categories[_normalize(name)] = name;
      }
    }

    final result = categories.values.toList();

    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return result;
  }

  static Future<void> add(String category) async {
    final trimmed = category.trim();

    if (trimmed.isEmpty) return;

    final lower = _normalize(trimmed);

    final docRef = _firestore.collection('categories').doc(lower);

    await docRef.set({
      'name': trimmed,
      'nameLower': lower,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> renameCategory({
    required String oldName,
    required String newName,
  }) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();

    if (oldTrimmed.isEmpty || newTrimmed.isEmpty) return;

    final oldLower = _normalize(oldTrimmed);
    final newLower = _normalize(newTrimmed);

    if (oldLower == newLower) return;

    final oldDocRef = _firestore.collection('categories').doc(oldLower);
    final newDocRef = _firestore.collection('categories').doc(newLower);

    final batch = _firestore.batch();

    batch.set(newDocRef, {
      'name': newTrimmed,
      'nameLower': newLower,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final allProducts = await _firestore.collection('products').get();

    for (final doc in allProducts.docs) {
      final data = doc.data();

      final rawCategories = data['categories'];
      final rawCategory = data['category'];

      final List<String> updatedCategories = [];

      if (rawCategories is List) {
        for (final item in rawCategories) {
          final value = item.toString().trim();

          if (value.isEmpty) continue;

          if (_normalize(value) == oldLower) {
            updatedCategories.add(newTrimmed);
          } else {
            updatedCategories.add(value);
          }
        }
      }

      if (rawCategory is String && rawCategory.trim().isNotEmpty) {
        final value = rawCategory.trim();

        if (_normalize(value) == oldLower) {
          updatedCategories.add(newTrimmed);
        } else {
          updatedCategories.add(value);
        }
      }

      final cleaned = _cleanCategoryList(updatedCategories);

      if (cleaned.isNotEmpty) {
        batch.update(doc.reference, {
          'categories': cleaned,
          'category': FieldValue.delete(),
        });
      } else if (data.containsKey('category')) {
        batch.update(doc.reference, {'category': FieldValue.delete()});
      }
    }

    batch.delete(oldDocRef);

    await batch.commit();
  }

  static Future<bool> remove(String category) async {
    final trimmed = category.trim();

    if (trimmed.isEmpty) return false;

    final lower = _normalize(trimmed);

    final isDefault = defaultCategories
        .map((category) => _normalize(category))
        .contains(lower);

    if (isDefault) {
      return false;
    }

    final batch = _firestore.batch();

    final categoryDoc = _firestore.collection('categories').doc(lower);
    batch.delete(categoryDoc);

    final allProducts = await _firestore.collection('products').get();

    for (final doc in allProducts.docs) {
      final data = doc.data();

      final rawCategories = data['categories'];
      final rawCategory = data['category'];

      final List<String> updatedCategories = [];

      if (rawCategories is List) {
        for (final item in rawCategories) {
          final value = item.toString().trim();

          if (value.isEmpty) continue;

          if (_normalize(value) != lower) {
            updatedCategories.add(value);
          }
        }
      }

      if (rawCategory is String && rawCategory.trim().isNotEmpty) {
        final value = rawCategory.trim();

        if (_normalize(value) != lower) {
          updatedCategories.add(value);
        }
      }

      final cleaned = _cleanCategoryList(updatedCategories);

      batch.update(doc.reference, {
        'categories': cleaned,
        'category': FieldValue.delete(),
      });
    }

    await batch.commit();

    return true;
  }
}
