import 'package:flutter/material.dart';
import 'product_list_page.dart';

class AllCategoriesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {

    final List<String> allCategories = [
      "Tất cả danh mục",
      "Burger",
      "Pizza",
      "Sandwich",
      "Hot Dog",
      "Fast Food",
      "Salad",
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("Tất cả danh mục"),
      ),
      body: ListView.builder(
        itemCount: allCategories.length,
        itemBuilder: (context, index) {
          final category = allCategories[index];
          return ListTile(
            title: Text(category),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProductListPage(category: category)),
              );
            },
          );
        },
      ),
    );
  }
}
