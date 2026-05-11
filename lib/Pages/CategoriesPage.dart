import 'package:flutter/material.dart';
import 'package:main_amato/screens/MenuPageScreen.dart';
import 'package:main_amato/Pages/SettingPage.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFFE5B4), Color(0xFFF267AF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Categories',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: const [
                      Icon(Icons.search, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'SEARCH',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Japanese Desserts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _categoryGrid(),
                        const SizedBox(height: 18),
                        const Text(
                          'Filipino Desserts',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _filipinoGrid(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MenuPageScreen(initialIndex: 0),
                  ),
                );
              },
              child: const Icon(Icons.home, color: Colors.grey, size: 32),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MenuPageScreen(initialIndex: 1),
                  ),
                );
              },
              child: const Icon(
                Icons.favorite_border,
                color: Colors.grey,
                size: 32,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MenuPageScreen(initialIndex: 2),
                  ),
                );
              },
              child: const Icon(
                Icons.notifications_none,
                color: Colors.grey,
                size: 32,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
              child: const Icon(Icons.menu, color: Color(0xFFF267AF), size: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _categoryCard('Mochi and Rice Cakes', 'assets/images/MatchaMotchi.jpg'),
        _categoryCard('Pastries', 'assets/images/Dorayaki.jpg'),
        _categoryCard('Cold Desserts', 'assets/images/StrawberryDaifuku.jpg'),
        _categoryCard('Milk tea and drinks', 'assets/images/PinkMochi.jpg'),
        _categoryCard(
          'Japanese Jelly Desserts',
          'assets/images/RedBeanBuns.jpg',
        ),
      ],
    );
  }

  Widget _filipinoGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _categoryCard('Halo-Halo', 'assets/images/PinkMochi.jpg'),
        _categoryCard('Filipino Rice Cakes', 'assets/images/MatchaMotchi.jpg'),
        _categoryCard('Graham Cake Variations', 'assets/images/Dorayaki.jpg'),
      ],
    );
  }

  Widget _categoryCard(String label, String image) {
    return Container(
      width: 160,
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.asset(
              image,
              height: 80,
              width: 160,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
