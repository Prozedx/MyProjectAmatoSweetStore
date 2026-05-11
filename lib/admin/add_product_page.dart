import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:main_amato/services/auth_service.dart';

import '../services/category_service.dart';
import '../services/cloudinary_service.dart';
import '../services/product_service.dart';
import 'package:flutter/services.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final nameController = TextEditingController();

  final descriptionController = TextEditingController();

  final priceController = TextEditingController();

  final stockController = TextEditingController();

  Set<String> selectedCategories = {};

  List<String> categoryOptions = [];
  final newCategoryController = TextEditingController();
  bool isAddingCategory = false;

  final picker = ImagePicker();

  final productService = ProductService();

  final cloudinaryService = CloudinaryService();

  File? selectedImage;

  bool isLoading = false;

  Future<void> pickImage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        selectedImage = File(picked.path);
      });
    }
  }

  Future<void> saveProduct() async {
    if (nameController.text.isEmpty ||
        selectedCategories.isEmpty ||
        descriptionController.text.isEmpty ||
        priceController.text.isEmpty ||
        stockController.text.isEmpty ||
        selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    final currentUser = AuthService().currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again to add products.')),
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      final imageUrl = await cloudinaryService.uploadImage(selectedImage!);

      await productService.addProduct(
        name: nameController.text.trim(),
        categories: selectedCategories.toList(),
        description: descriptionController.text.trim(),
        price: double.parse(priceController.text.trim()),
        stock: int.parse(stockController.text.trim()),
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product added')));

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      final message = e.code == 'permission-denied'
          ? 'You do not have permission to add products.'
          : 'Error: ${e.message ?? e.code}';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget input({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color.fromRGBO(255, 255, 255, 0.75),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Future<void> _addCategory(String category) async {
    if (category.isEmpty) {
      return;
    }

    try {
      print('Adding category: $category');
      await CategoryService.add(category);
      print('Category added successfully: $category');

      final fetchedCategories = await CategoryService.fetchAllCategories();
      print('Fetched categories: $fetchedCategories');

      if (!mounted) return;
      setState(() {
        categoryOptions = fetchedCategories;
        selectedCategories.add(category);
        isAddingCategory = false;
        newCategoryController.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Category "$category" added')));
    } catch (e) {
      print('Error in _addCategory: $e');
      rethrow;
    }
  }

  Future<void> promptAddCategory() async {
    setState(() {
      isAddingCategory = true;
    });
  }

  Future<void> _confirmRemoveCategory(String category) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete category?'),
              content: Text(
                'Remove "$category" from categories? This will also deselect it for the product.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    final removed = await CategoryService.remove(category);
    if (removed) {
      await productService.removeCategoryFromProducts(category);
      final fetchedCategories = await CategoryService.fetchAllCategories();
      if (!mounted) return;
      setState(() {
        categoryOptions = fetchedCategories;
        selectedCategories.remove(category);
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot remove default category "$category".')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCategoryOptions();
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    stockController.dispose();
    newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategoryOptions() async {
    final fetchedCategories = await CategoryService.fetchAllCategories();
    if (!mounted) return;
    setState(() {
      categoryOptions = fetchedCategories;
    });
  }

  Widget categorySelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.75),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories (Select One or More)',
            style: GoogleFonts.lexend(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...categoryOptions.map((category) {
                final isSelected = selectedCategories.contains(category);
                return InputChip(
                  label: Text(
                    category,
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFFF267AF),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFF267AF),
                  backgroundColor: Colors.white,
                  deleteIcon: const Icon(Icons.close, size: 18),
                  deleteIconColor: isSelected
                      ? Colors.white
                      : const Color(0xFFF267AF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFF267AF)),
                  ),
                  onSelected: (_) {
                    setState(() {
                      if (isSelected) {
                        selectedCategories.remove(category);
                      } else {
                        selectedCategories.add(category);
                      }
                    });
                  },
                  onDeleted: () => _confirmRemoveCategory(category),
                );
              }),
              if (isAddingCategory)
                Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF267AF)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          controller: newCategoryController,
                          decoration: InputDecoration(
                            hintText: 'New category',
                            hintStyle: GoogleFonts.lexend(fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          style: GoogleFonts.lexend(fontSize: 12),
                          onSubmitted: (value) async {
                            final trimmed = value.trim();
                            if (trimmed.isNotEmpty) {
                              await _addCategory(trimmed);
                            }
                          },
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          final trimmed = newCategoryController.text.trim();
                          if (trimmed.isNotEmpty) {
                            _addCategory(trimmed).catchError((error) {
                              print('Error adding category: $error');
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error adding category: $error',
                                  ),
                                ),
                              );
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.check,
                            color: const Color(0xFFF267AF),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isAddingCategory = false;
                            newCategoryController.clear();
                          });
                        },
                        child: const Icon(
                          Icons.close,
                          color: Color(0xFFF267AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ActionChip(
                label: Text(
                  'Add more${AuthService().currentUser?.displayName != null ? ' (${AuthService().currentUser!.displayName})' : ''}',
                  style: GoogleFonts.lexend(fontSize: 12),
                ),
                backgroundColor: Colors.white,
                labelStyle: const TextStyle(color: Color(0xFFF267AF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFF267AF)),
                ),
                onPressed: promptAddCategory,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,

        iconTheme: const IconThemeData(color: Colors.white),

        title: Text(
          'Add Product${AuthService().currentUser?.displayName != null ? ' (${AuthService().currentUser!.displayName})' : ''}',
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontWeight: FontWeight.bold,
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

        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),

          child: Column(
            children: [
              GestureDetector(
                onTap: pickImage,

                child: Container(
                  width: double.infinity,
                  height: 220,

                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.18),

                    borderRadius: BorderRadius.circular(28),

                    border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.25),
                    ),
                  ),

                  child: selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(28),

                          child: Image.file(selectedImage!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [
                            const Icon(
                              Icons.add_photo_alternate,
                              color: Colors.white,
                              size: 60,
                            ),

                            const SizedBox(height: 10),

                            Text(
                              'Tap to Select Product Image',
                              style: GoogleFonts.lexend(color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),

              input(controller: nameController, hint: 'Product Name'),

              categorySelector(),

              input(
                controller: descriptionController,
                hint: 'Description',
                maxLines: 4,
              ),

              input(
                controller: priceController,
                hint: 'Price',
                keyboardType: TextInputType.number,
              ),

              input(
                controller: stockController,
                hint: 'Stock',
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFFFFE5B4), Color(0xFFF267AF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFF267AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    onPressed: isLoading ? null : saveProduct,
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: Color(0xFFF267AF),
                          )
                        : Text(
                            'SAVE PRODUCT',
                            style: GoogleFonts.lexend(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}
