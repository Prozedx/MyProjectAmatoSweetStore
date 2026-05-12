import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:main_amato/Pages/product_details_page.dart';
import 'package:main_amato/Pages/FavoritesPage.dart';
import 'package:main_amato/Pages/CategoriesPage.dart';
import 'package:main_amato/Pages/SettingPage.dart';
import 'package:main_amato/Pages/CartPage.dart';
import 'package:main_amato/Pages/AllProductsPage.dart';
import 'package:main_amato/services/auth_service.dart';

class MenuPageScreen extends StatefulWidget {
  const MenuPageScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MenuPageScreen> createState() => _MenuPageScreenState();
}

class _MenuPageScreenState extends State<MenuPageScreen> {
  late int _currentIndex;
  String selectedCategory = 'all';

  String searchQuery = '';

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _pages = [
      HomeContent(
        searchQuery: searchQuery,
        selectedCategory: selectedCategory,
        onCategoryChanged: (value) {
          setState(() {
            selectedCategory = value;
          });
        },
        onSearchChanged: (value) {
          setState(() {
            searchQuery = value.toLowerCase();
          });
        },
        onSearchTap: _openCategories,
        onMenuTap: _openCategories,
      ),

      const FavoritesPage(),

      const CartPage(),
    ];
  }

  void _openCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoriesPage()),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  Widget _navIcon({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFFFFE5B4), Color(0xFFF267AF)],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? Colors.white : Colors.transparent,
            width: active ? 2 : 0,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: active ? Colors.white : const Color(0xFFFF9A9A),
            size: 28,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _pages[0] = HomeContent(
      searchQuery: searchQuery,
      selectedCategory: selectedCategory,
      onCategoryChanged: (value) {
        setState(() {
          selectedCategory = value;
        });
      },
      onSearchChanged: (value) {
        setState(() {
          searchQuery = value.toLowerCase();
        });
      },
      onSearchTap: _openCategories,
      onMenuTap: _openCategories,
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFF79AE),
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        height: 66,
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navIcon(
              icon: Icons.home_outlined,
              active: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _navIcon(
              icon: Icons.favorite_border,
              active: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            _navIcon(
              icon: Icons.shopping_cart_outlined,
              active: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _navIcon(icon: Icons.menu, active: false, onTap: _openSettings),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchTap,
    required this.onMenuTap,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;
  final String selectedCategory;
  final Function(String) onCategoryChanged;

  static const Color bgTop = Color(0xFFFFD0B6);
  static const Color bgBottom = Color(0xFFFF79AE);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [bgTop, bgBottom],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Find your favorite\nsnacks and pastries!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  Image.asset(
                    'assets/images/sakuraImage.png',
                    height: 38,
                    errorBuilder: (_, _, _) => const SizedBox(),
                  ),

                  const SizedBox(width: 8),
                ],
              ),

              const SizedBox(height: 10),

              Container(
                height: 58,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.95),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: const InputDecoration(
                    hintStyle: TextStyle(fontSize: 20, color: Colors.grey),
                    hintText: 'Search products...',
                    prefixIcon: Icon(Icons.search, color: Color(0xFFFF9A9A)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(top: 14),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .snapshots(),
                builder: (context, productSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('categories')
                        .snapshots(),
                    builder: (context, categorySnapshot) {
                      final productDocs = productSnapshot.data?.docs ?? [];
                      final categoryDocs = categorySnapshot.data?.docs ?? [];
                      final categories = <String>{
                        'JP Desserts',
                        'Pastry',
                        'Parfait',
                      };

                      // Add categories from the 'categories' collection
                      for (final doc in categoryDocs) {
                        final data = doc.data() as Map<String, dynamic>?;
                        final name = data?['name']?.toString().trim();
                        if (name != null && name.isNotEmpty) {
                          categories.add(name);
                        }
                      }

                      // Add categories from products
                      for (final doc in productDocs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final categoryRaw = data['category'];
                        final category = categoryRaw?.toString().trim();
                        if (category != null && category.isNotEmpty) {
                          categories.add(category);
                        }
                        final categoriesRaw = data['categories'];
                        if (categoriesRaw is List) {
                          for (final item in categoriesRaw) {
                            final cat = item?.toString().trim();
                            if (cat != null && cat.isNotEmpty) {
                              categories.add(cat);
                            }
                          }
                        }
                      }

                      final categoryList = [
                        'all',
                        ...categories.toList()..sort(),
                      ];

                      return SizedBox(
                        height: 56,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: categoryList.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final category = categoryList[index];
                            final displayLabel = category == 'all'
                                ? 'ALL'
                                : category.toUpperCase();
                            final isSelected =
                                selectedCategory.toLowerCase() ==
                                category.toLowerCase();

                            return _pill(
                              displayLabel,
                              isSelected,
                              () => onCategoryChanged(category),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 18),

              StreamBuilder<QuerySnapshot>(
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

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Error loading products',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final products = snapshot.data?.docs ?? [];

                  final filteredProducts = products.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    final name = data['name']?.toString().toLowerCase() ?? '';

                    // Handle both 'category' and 'categories' fields
                    final categories = <String>[];
                    final categoryRaw = data['category'];
                    if (categoryRaw is String) {
                      categories.add(categoryRaw.toLowerCase());
                    }
                    final categoriesRaw = data['categories'];
                    if (categoriesRaw is List) {
                      for (final cat in categoriesRaw) {
                        final catStr = cat?.toString().toLowerCase();
                        if (catStr != null && catStr.isNotEmpty) {
                          categories.add(catStr);
                        }
                      }
                    }

                    final categorySearch = categories.join(' ');
                    final matchesSearch =
                        name.contains(searchQuery) ||
                        categorySearch.contains(searchQuery);

                    final matchesCategory =
                        selectedCategory == 'all' ||
                        categories.contains(selectedCategory.toLowerCase());

                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filteredProducts.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 50),
                      child: Center(
                        child: Text(
                          'No products found',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredProducts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 9,
                          mainAxisSpacing: 9,
                          childAspectRatio: 0.78,
                        ),
                    itemBuilder: (context, index) {
                      final doc = filteredProducts[index];

                      final data = doc.data() as Map<String, dynamic>;

                      final imageUrl = data['imageUrl']?.toString() ?? '';

                      final name = data['name']?.toString() ?? 'No name';

                      final description = data['description']?.toString() ?? '';

                      final price = data['price'] ?? 0;

                      final stockRaw = data['stock'] ?? 0;

                      final stock = stockRaw is int
                          ? stockRaw
                          : int.tryParse(stockRaw.toString()) ?? 0;

                      return _productCard(
                        productId: doc.id,
                        imageUrl: imageUrl,
                        name: name,
                        description: description,
                        price: price,
                        stock: stock,
                        onTap: () {
                          if (stock <= 0) return;

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
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AllProductsPage()),
                  );
                },
                child: _lookForMoreCard(),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _pill(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFFFFE5B4), Color(0xFFF267AF)],
                )
              : null,
          color: active ? null : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _productCard({
    required String productId,
    required String imageUrl,
    required String name,
    required String description,
    required dynamic price,
    required int stock,
    required VoidCallback onTap,
  }) {
    final outOfStock = stock <= 0;

    return Opacity(
      opacity: outOfStock ? 0.55 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(9),
                      ),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    child: Column(
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          outOfStock
                              ? 'Out of stock'
                              : '₱$price | Stock: $stock',
                          style: TextStyle(
                            color: outOfStock ? Colors.red : Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              top: 6,
              right: 6,
              child: FavoriteButton(
                productId: productId,
                name: name,
                imageUrl: imageUrl,
                price: price,
                stock: stock,
                description: description,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFFFC1C1),
      child: const Center(child: Icon(Icons.image, color: Colors.white)),
    );
  }

  static Widget _lookForMoreCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            Container(
              height: 140,
              width: double.infinity,
              color: const Color.fromRGBO(255, 255, 255, 0.4),
              child: Image.asset(
                'assets/images/RedBeanBuns.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: const Color.fromRGBO(255, 255, 255, 0.3)),
              ),
            ),

            Positioned.fill(
              child: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 25),
                color: const Color.fromRGBO(0, 0, 0, 0.15),
                child: const Text(
                  'LOOK FOR\nMORE!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.bold,
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

class FavoriteButton extends StatelessWidget {
  final String productId;
  final String name;
  final String imageUrl;
  final dynamic price;
  final int stock;
  final String description;

  const FavoriteButton({
    super.key,
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.stock,
    required this.description,
  });

  Future<void> toggleFavorite(bool isFavorite) async {
    final user = AuthService().currentUser;

    if (user == null) return;

    final favRef = FirebaseFirestore.instance
        .collection('favorites')
        .doc(user.uid)
        .collection('items')
        .doc(productId);

    if (isFavorite) {
      await favRef.delete();
    } else {
      await favRef.set({
        'productId': productId,
        'name': name,
        'imageUrl': imageUrl,
        'price': price,
        'stock': stock,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return const Icon(Icons.favorite_border, color: Colors.black, size: 25);
    }

    final favRef = FirebaseFirestore.instance
        .collection('favorites')
        .doc(user.uid)
        .collection('items')
        .doc(productId);

    return StreamBuilder<DocumentSnapshot>(
      stream: favRef.snapshots(),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data?.exists ?? false;

        return GestureDetector(
          onTap: () => toggleFavorite(isFavorite),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? const Color(0xFFFFA5D0) : Colors.black,
            size: 26,
          ),
        );
      },
    );
  }
}
