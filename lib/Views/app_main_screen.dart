import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class AppMainScreen extends StatefulWidget {
  const AppMainScreen({Key? key}) : super(key: key);

  @override
  State<AppMainScreen> createState() => _AppMainScreenState();
}

class _AppMainScreenState extends State<AppMainScreen> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconSize: 28,
        currentIndex: selectedIndex,
        selectedItemColor: kprimaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          color: kprimaryColor,
          fontWeight: FontWeight.w600,
        ),
        items: const [
          BottomNavigationBarItem(icon: Icon(Iconsax.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Iconsax.heart), label: "Favorite"),
          BottomNavigationBarItem(icon: Icon(Iconsax.calendar), label: "Meal Plan"),
          BottomNavigationBarItem(icon: Icon(Iconsax.setting), label: "Setting"),
        ],
        onTap: (index) {
          setState(() => selectedIndex = index);
        },
      ),
      body: selectedIndex == 0
          ? const MyAppHomeScreen()
          : Center(child: Text("Page index: $selectedIndex")),
    );
  }
}

class MyAppHomeScreen extends StatefulWidget {
  const MyAppHomeScreen({Key? key}) : super(key: key);

  @override
  State<MyAppHomeScreen> createState() => _MyAppHomeScreenState();
}

class _MyAppHomeScreenState extends State<MyAppHomeScreen> {
  String selectedCategory = "All";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headerParts(),
            const SizedBox(height: 20),
            mySearchBar(),
            const SizedBox(height: 20),
            const BannerToExplore(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "Categories",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            // Catégories (ligne horizontale scrollable)
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('categories').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 40,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final categories = <String>["All"];
                if (snapshot.hasData) {
                  for (final d in snapshot.data!.docs) {
                    final name = (d['name'] ?? '').toString();
                    if (name.isNotEmpty) categories.add(name);
                  }
                }
                return categoryButtons(categories);
              },
            ),

            const SizedBox(height: 20),

            // Le grid remplit l'espace restant
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: selectedCategory == "All"
                    ? _firestore.collection('recipes').snapshots()
                    : _firestore
                        .collection('recipes')
                        .where('category', isEqualTo: selectedCategory)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No recipes found"));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final recipe = snapshot.data!.docs[index];
                      final img = (recipe['image'] ?? '').toString();
                      final name = (recipe['name'] ?? '').toString();
                      final desc = (recipe['description'] ?? '').toString();

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                child: img.isNotEmpty
                                    ? Image.network(img, fit: BoxFit.cover)
                                    : Container(
                                        color: Colors.grey[200],
                                        child: const Center(child: Icon(Icons.image_not_supported)),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    desc,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
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

  Padding headerParts() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "What are you\ncooking today?",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            style: IconButton.styleFrom(
              fixedSize: const Size(55, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            icon: const Icon(Iconsax.notification),
          ),
        ],
      ),
    );
  }

  Widget mySearchBar() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: const TextField(
        decoration: InputDecoration(
          hintText: "Search any recipes",
          hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
          prefixIcon: Icon(Iconsax.search_normal, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget categoryButtons(List<String> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => selectedCategory = category),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? kprimaryColor : Colors.grey[200],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class BannerToExplore extends StatelessWidget {
  const BannerToExplore({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 170,
      decoration: BoxDecoration(
        color: const Color(0xFF71B77A),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 32,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Cook the best\nrecipes at home",
                  style: TextStyle(
                    height: 1.1,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    "Explore",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF71B77A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: -20,
            child: Image.asset(
              "assets/images/chef_PNG190.png",
              width: 180,
            ),
          ),
        ],
      ),
    );
  }
}
