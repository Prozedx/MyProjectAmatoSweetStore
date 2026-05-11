import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'add_product_page.dart';
import 'edit_product_page.dart';
import '../services/product_service.dart';

class ManageProductsPage extends StatefulWidget {
  const ManageProductsPage({super.key});

  @override
  State<ManageProductsPage> createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> {
  final ProductService productService = ProductService();

  String searchQuery = '';
  String filter = 'all';

  List<String> getCleanCategories(Map<String, dynamic> data) {
    final categoryMap = <String, String>{};

    String normalize(String input) {
      var s = input.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
      s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      return s;
    }

    final categoriesRaw = data['categories'];

    if (categoriesRaw is List) {
      for (final cat in categoriesRaw) {
        String? value;

        if (cat is String) {
          value = cat.trim();
        } else if (cat is Map && cat['name'] != null) {
          value = cat['name']?.toString().trim();
        } else {
          // Fallback to string conversion for unexpected types
          value = cat?.toString().trim();
        }

        if (value != null && value.isNotEmpty) {
          final normalized = normalize(value);
          if (normalized.isNotEmpty) {
            categoryMap[normalized.toLowerCase()] = normalized;
          }
        }
      }
    }

    final categoryRaw = data['category'];

    if (categoryRaw is String && categoryRaw.trim().isNotEmpty) {
      final value = normalize(categoryRaw);

      if (value.isNotEmpty && !categoryMap.containsKey(value.toLowerCase())) {
        categoryMap[value.toLowerCase()] = value;
      }
    }

    final result = categoryMap.values.toList();

    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return result;
  }

  List<QueryDocumentSnapshot> applyFilters(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      final name = data['name']?.toString().toLowerCase() ?? '';

      final categories = getCleanCategories(
        data,
      ).map((category) => category.toLowerCase()).join(' ');

      final stockRaw = data['stock'] ?? 0;

      final stock = stockRaw is int
          ? stockRaw
          : int.tryParse(stockRaw.toString()) ?? 0;

      final matchesSearch =
          name.contains(searchQuery) || categories.contains(searchQuery);

      bool matchesFilter = true;

      if (filter == 'low') {
        matchesFilter = stock > 0 && stock <= 5;
      }

      if (filter == 'out') {
        matchesFilter = stock <= 0;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Color stockColor(int stock) {
    if (stock <= 0) return Colors.red;

    if (stock <= 5) return Colors.orange;

    return Colors.green;
  }

  Future<void> deleteProduct(String productId) async {
    await productService.deleteProduct(productId);

    final favorites = await FirebaseFirestore.instance
        .collection('favorites')
        .where('productId', isEqualTo: productId)
        .get();

    for (final doc in favorites.docs) {
      await doc.reference.delete();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Product deleted')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Manage Products',
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom + 85,
          right: 16,
        ),
        child: Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFFE5B4), Color(0xFFF267AF)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Material(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              child: InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddProductPage()),
                  );
                },
                child: const Center(
                  child: Icon(Icons.add, color: Color(0xFFF267AF), size: 28),
                ),
              ),
            ),
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      filterButton(label: 'All', value: 'all'),

                      const SizedBox(width: 8),

                      filterButton(label: 'Low Stock', value: 'low'),

                      const SizedBox(width: 8),

                      filterButton(label: 'Out', value: 'out'),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Error loading products',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  final products = applyFilters(docs);

                  if (products.isEmpty) {
                    return const Center(
                      child: Text(
                        'No products found',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final doc = products[index];

                      final data = doc.data() as Map<String, dynamic>;

                      final imageUrl = data['imageUrl']?.toString() ?? '';

                      final name = data['name']?.toString() ?? '';

                      final categoryDisplay = getCleanCategories(
                        data,
                      ).join(', ');

                      final price = data['price'] ?? 0;

                      final stockRaw = data['stock'] ?? 0;

                      final stock = stockRaw is int
                          ? stockRaw
                          : int.tryParse(stockRaw.toString()) ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return placeholderImage();
                                          },
                                    )
                                  : placeholderImage(),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    categoryDisplay,
                                    style: const TextStyle(color: Colors.grey),
                                  ),

                                  const SizedBox(height: 6),

                                  Text(
                                    '₱$price',
                                    style: const TextStyle(
                                      color: Color(0xFFF267AF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: stockColor(
                                        stock,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Text(
                                      'Stock: $stock',
                                      style: TextStyle(
                                        color: stockColor(stock),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Color(0xFFF267AF),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditProductPage(
                                          productId: doc.id,
                                          productData: data,
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('Delete Product'),
                                          content: const Text(
                                            'Are you sure you want to delete this product?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),

                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (confirm == true) {
                                      deleteProduct(doc.id);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget filterButton({required String label, required String value}) {
    final active = filter == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            filter = value;
          });
        },
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFFF267AF) : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget placeholderImage() {
    return Container(
      width: 90,
      height: 90,
      color: const Color(0xFFFFC1C1),
      child: const Icon(Icons.image, color: Colors.white),
    );
  }
}
