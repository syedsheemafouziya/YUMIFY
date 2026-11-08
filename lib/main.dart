import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => RecipeStore()..loadRecipes(),
      child: const YumifyApp(),
    ),
  );
}

// ---------------- RECIPE MODEL ----------------

class Recipe {
  final String id;
  final String name;
  final String category;
  final String description;
  final List<String> ingredients;
  final List<String> steps;
  final bool isFavourite;
  final bool isFamilyRecipe;

  Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.ingredients,
    required this.steps,
    this.isFavourite = false,
    this.isFamilyRecipe = false,
  });

  Recipe copyWith({
    bool? isFavourite,
    bool? isFamilyRecipe,
  }) {
    return Recipe(
      id: id,
      name: name,
      category: category,
      description: description,
      ingredients: ingredients,
      steps: steps,
      isFavourite: isFavourite ?? this.isFavourite,
      isFamilyRecipe: isFamilyRecipe ?? this.isFamilyRecipe,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'ingredients': ingredients,
    'steps': steps,
    'isFavourite': isFavourite,
    'isFamilyRecipe': isFamilyRecipe,
  };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      ingredients: List<String>.from(json['ingredients']),
      steps: List<String>.from(json['steps']),
      isFavourite: json['isFavourite'] ?? false,
      isFamilyRecipe: json['isFamilyRecipe'] ?? false,
    );
  }
}

// ---------------- PROVIDER / STORAGE ----------------

class RecipeStore extends ChangeNotifier {
  static const String storageKey = 'yumify_recipes';

  List<Recipe> _recipes = [];
  bool isLoading = true;
  String? errorMessage;

  List<Recipe> get recipes => List.unmodifiable(_recipes);

  List<Recipe> get favourites =>
      _recipes.where((recipe) => recipe.isFavourite).toList();

  List<Recipe> get familyRecipes =>
      _recipes.where((recipe) => recipe.isFamilyRecipe).toList();

  Future<void> loadRecipes() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);

      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);

        _recipes = decoded
            .map((item) => Recipe.fromJson(
          Map<String, dynamic>.from(item),
        ))
            .toList();
      }
    } catch (e) {
      errorMessage = 'Could not load saved recipes.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _recipes.map((recipe) => recipe.toJson()).toList(),
    );
    await prefs.setString(storageKey, encoded);
  }

  Future<void> addRecipe(Recipe recipe) async {
    _recipes.insert(0, recipe);
    await _saveRecipes();
    notifyListeners();
  }

  Future<void> toggleFavourite(String id) async {
    final index = _recipes.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final recipe = _recipes[index];
    _recipes[index] = recipe.copyWith(
      isFavourite: !recipe.isFavourite,
    );

    notifyListeners();
    await _saveRecipes();
  }

  Future<void> toggleFamilyRecipe(String id) async {
    final index = _recipes.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final recipe = _recipes[index];
    _recipes[index] = recipe.copyWith(
      isFamilyRecipe: !recipe.isFamilyRecipe,
    );

    notifyListeners();
    await _saveRecipes();
  }

  Future<void> retry() => loadRecipes();
}

// ---------------- MAIN APP ----------------

class YumifyApp extends StatelessWidget {
  const YumifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RecipeStore>(
      create: (_) => RecipeStore()..loadRecipes(),
      child: MaterialApp(
        title: 'YUMIFY',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF7043),
          ),
          scaffoldBackgroundColor: const Color(0xFFFFFBF7),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFFFBF7),
            centerTitle: false,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

// ---------------- BOTTOM NAVIGATION ----------------

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  final List<Widget> screens = const [
    HomeScreen(),
    AddRecipeScreen(),
    FavouritesScreen(),
    FamilyCookbookScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: screens[selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favourites',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Family Book',
          ),
        ],
      ),
    );
  }
}

// ---------------- HOME SCREEN ----------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String searchText = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();

    final filteredRecipes = store.recipes.where((recipe) {
      return recipe.name.toLowerCase().contains(searchText.toLowerCase()) ||
          recipe.category.toLowerCase().contains(searchText.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'YUMIFY 🍲',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Reload recipes',
            onPressed: () => store.retry(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What would you like to cook?',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              onChanged: (value) {
                setState(() => searchText = value);
              },
              decoration: const InputDecoration(
                hintText: 'Search recipes...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Recipes',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: store.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : store.errorMessage != null
                  ? ErrorView(
                message: store.errorMessage!,
                onRetry: () => store.retry(),
              )
                  : filteredRecipes.isEmpty
                  ? EmptyView(
                message: searchText.isEmpty
                    ? 'No recipes yet. Add your first recipe!'
                    : 'No matching recipes found.',
              )
                  : ListView.builder(
                itemCount: filteredRecipes.length,
                itemBuilder: (context, index) {
                  return RecipeCard(
                    recipe: filteredRecipes[index],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- RECIPE CARD ----------------

class RecipeCard extends StatelessWidget {
  final Recipe recipe;

  const RecipeCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final store = context.read<RecipeStore>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.restaurant, size: 27),
        ),
        title: Text(
          recipe.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(recipe.category),
        trailing: IconButton(
          onPressed: () => store.toggleFavourite(recipe.id),
          icon: Icon(
            recipe.isFavourite ? Icons.favorite : Icons.favorite_border,
            color: recipe.isFavourite ? Colors.red : null,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
            ),
          );
        },
      ),
    );
  }
}

// ---------------- RECIPE DETAILS ----------------

class RecipeDetailScreen extends StatelessWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();

    final matches = store.recipes.where((r) => r.id == recipeId);

    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe')),
        body: const EmptyView(message: 'Recipe not found.'),
      );
    }

    final recipe = matches.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Recipe Details')),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.restaurant_menu, size: 75),
            const SizedBox(height: 12),
            Text(
              recipe.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            Center(child: Chip(label: Text(recipe.category))),
            const SizedBox(height: 12),
            Text(recipe.description),
            const SizedBox(height: 20),
            const Text(
              'Ingredients',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ...recipe.ingredients.map(
                  (item) => ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(item),
              ),
            ),
            const Divider(),
            const Text(
              'Preparation Steps',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...recipe.steps.asMap().entries.map(
                  (entry) => ListTile(
                leading: CircleAvatar(
                  child: Text('${entry.key + 1}'),
                ),
                title: Text(entry.value),
              ),
            ),
            const SizedBox(height: 15),
            FilledButton.icon(
              onPressed: () => store.toggleFamilyRecipe(recipe.id),
              icon: const Icon(Icons.menu_book),
              label: Text(
                recipe.isFamilyRecipe
                    ? 'Remove from Family Cookbook'
                    : 'Save to Family Cookbook',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- ADD RECIPE SCREEN ----------------

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final ingredientsController = TextEditingController();
  final stepsController = TextEditingController();

  String category = 'Breakfast';
  bool isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    ingredientsController.dispose();
    stepsController.dispose();
    super.dispose();
  }

  Future<void> saveRecipe() async {
    if (isSaving) return;

    if (!formKey.currentState!.validate()) return;

    final ingredients = ingredientsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final steps = stepsController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (ingredients.isEmpty || steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter ingredients and preparation steps.'),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final recipe = Recipe(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        category: category,
        description: descriptionController.text.trim(),
        ingredients: ingredients,
        steps: steps,
      );

      await context.read<RecipeStore>().addRecipe(recipe);

      if (!mounted) return;

      nameController.clear();
      descriptionController.clear();
      ingredientsController.clear();
      stepsController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe saved successfully!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save recipe. Try again.')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  String? requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Your Recipe')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextFormField(
              controller: nameController,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Recipe Name',
                prefixIcon: Icon(Icons.restaurant),
              ),
              validator: requiredField,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                'Breakfast',
                'Lunch',
                'Dinner',
                'Snacks',
                'Dessert',
                'Drinks',
              ].map((value) {
                return DropdownMenuItem(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => category = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descriptionController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
              validator: requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ingredientsController,
              maxLength: 2000,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ingredients',
                hintText: 'Enter ingredients separated by commas',
                alignLabelWithHint: true,
              ),
              validator: requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: stepsController,
              maxLength: 4000,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Preparation Steps',
                hintText: 'Write each step on a new line',
                alignLabelWithHint: true,
              ),
              validator: requiredField,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isSaving ? null : saveRecipe,
              icon: isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.save),
              label: Text(isSaving ? 'Saving...' : 'Save Recipe'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- FAVOURITES SCREEN ----------------

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Favourites ❤️')),
      body: store.favourites.isEmpty
          ? const EmptyView(
        message: 'No favourites yet. Tap the heart on a recipe!',
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: store.favourites.length,
        itemBuilder: (context, index) {
          return RecipeCard(recipe: store.favourites[index]);
        },
      ),
    );
  }
}

// ---------------- FAMILY COOKBOOK SCREEN ----------------

class FamilyCookbookScreen extends StatelessWidget {
const FamilyCookbookScreen({super.key});

@override
Widget build(BuildContext context) {
final store = context.watch<RecipeStore>();

return Scaffold(
appBar: AppBar(title: const Text('Family Cookbook 📖')),
body: store.familyRecipes.isEmpty
? const EmptyView(
message:
'Your family recipes will live here. Save a recipe to your cookbook!',
)
    : ListView.builder(
  padding: const EdgeInsets.all(16),
  itemCount: store.familyRecipes.length,
  itemBuilder: (context, index) {
    return RecipeCard(recipe: store.familyRecipes[index]);
  },
),
);
}
}
// ---------------- EMPTY AND ERROR STATES ----------------

class EmptyView extends StatelessWidget {
  final String message;

  const EmptyView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 65,
              color: Colors.grey,
            ),
            const SizedBox(height: 15),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 55),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}