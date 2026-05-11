import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/category_service.dart';
import '../services/cloudinary_service.dart';
import '../services/product_service.dart';

class EditProductPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const EditProductPage({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final productService = ProductService();
  final cloudinaryService = CloudinaryService();
  final picker = ImagePicker();

  File? selectedImage;

  late TextEditingController nameController;
  Set<String> selectedCategories = {};
  late TextEditingController descriptionController;
  late TextEditingController priceController;
  late TextEditingController stockController;

  List<String> categoryOptions = [];
  final newCategoryController = TextEditingController();

  bool isAddingCategory = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.productData['name']?.toString() ?? '',
    );

    // Support both 'categories' (array) and 'category' (string) for backward compatibility
    final categoriesRaw = widget.productData['categories'];
    if (categoriesRaw is List) {
      selectedCategories = categoriesRaw
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet();
    } else if (widget.productData['category'] is String) {
      final cat = widget.productData['category']?.toString().trim() ?? '';
      if (cat.isNotEmpty) {
        selectedCategories.add(cat);
      }
    }

    _loadCategoryOptions();

    descriptionController = TextEditingController(
      text: widget.productData['description']?.toString() ?? '',
    );
    priceController = TextEditingController(
      text: widget.productData['price']?.toString() ?? '',
    );
    stockController = TextEditingController(
      text: widget.productData['stock']?.toString() ?? '',
    );
  }

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

  Future<void> updateProduct() async {
    if (nameController.text.isEmpty ||
        selectedCategories.isEmpty ||
        descriptionController.text.isEmpty ||
        priceController.text.isEmpty ||
        stockController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again to update products.'),
        ),
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      String imageUrl = widget.productData['imageUrl']?.toString() ?? '';

      if (selectedImage != null) {
        imageUrl = await cloudinaryService.uploadImage(selectedImage!);
      }

      await productService.updateProduct(
        productId: widget.productId,
        name: nameController.text.trim(),
        categories: selectedCategories.toList(),
        description: descriptionController.text.trim(),
        price: double.tryParse(priceController.text.trim()) ?? 0,
        stock: int.tryParse(stockController.text.trim()) ?? 0,
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product updated')));

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      final message = e.code == 'permission-denied'
          ? 'You do not have permission to update this product.'
          : 'Error: ${e.message ?? e.code}';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;

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
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.lexend(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
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
        ],
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

  Future<void> _loadCategoryOptions() async {
    final fetchedCategories = await CategoryService.fetchAllCategories();
    if (!mounted) return;
    setState(() {
      categoryOptions = fetchedCategories;
    });
  }

  Widget categorySelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
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
                  'Add more${FirebaseAuth.instance.currentUser?.displayName != null ? ' (${FirebaseAuth.instance.currentUser!.displayName})' : ''}',
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

  Widget imagePickerBox() {
    final oldImageUrl = widget.productData['imageUrl']?.toString() ?? '';

    return GestureDetector(
      onTap: pickImage,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.18),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.25)),
        ),
        child: selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.file(selectedImage!, fit: BoxFit.cover),
              )
            : oldImageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.network(
                  oldImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) {
                    return imagePlaceholder();
                  },
                ),
              )
            : imagePlaceholder(),
      ),
    );
  }

  Widget imagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_photo_alternate, color: Colors.white, size: 60),
        const SizedBox(height: 10),
        Text(
          'Tap to Update Product Image',
          style: GoogleFonts.lexend(color: Colors.white),
        ),
      ],
    );
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
          'Edit Product${FirebaseAuth.instance.currentUser?.displayName != null ? ' (${FirebaseAuth.instance.currentUser!.displayName})' : ''}',
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                imagePickerBox(),

                const SizedBox(height: 20),

                input(
                  label: 'Product Name',
                  controller: nameController,
                  hint: 'Enter product name',
                ),

                categorySelector(),

                input(
                  label: 'Description',
                  controller: descriptionController,
                  hint: 'Enter product description',
                  maxLines: 4,
                ),

                input(
                  label: 'Price',
                  controller: priceController,
                  hint: 'Enter product price',
                  keyboardType: TextInputType.number,
                ),

                input(
                  label: 'Stock',
                  controller: stockController,
                  hint: 'Enter stock count',
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFF267AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: isLoading ? null : updateProduct,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            'UPDATE PRODUCT',
                            style: GoogleFonts.lexend(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
