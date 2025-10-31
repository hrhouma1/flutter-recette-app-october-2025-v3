# Quiz StreamBuilder - Partie 2 (Questions 16-25)

## Section C: Questions Pratiques et Avancées

### Question 16: Débogage
**Ce code produit une erreur. Pourquoi?**

```dart
class BuggyWidget extends StatelessWidget {
  Stream<int> createStream() {
    return Stream.periodic(Duration(seconds: 1), (i) => i);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: createStream(),
      builder: (context, snapshot) {
        return Text('${snapshot.data}');
      },
    );
  }
}
```

A) Le Stream n'est pas fermé  
B) Un nouveau Stream est créé à chaque rebuild  
C) snapshot.data peut être null  
D) B et C sont corrects  

<details>
<summary>Réponse</summary>

**D) B et C sont corrects**

**Problème 1**: Nouveau Stream à chaque rebuild
```dart
// ❌ MAUVAIS: createStream() appelé à chaque build()
stream: createStream(),
```
Chaque fois que le widget se reconstruit (changement de theme, navigation, etc.), un NOUVEAU Stream est créé, l'ancien est abandonné mais continue à consommer des ressources.

**Problème 2**: snapshot.data peut être null
```dart
return Text('${snapshot.data}');  // Affiche "null" au départ
```

**SOLUTION COMPLÈTE**:
```dart
class FixedWidget extends StatefulWidget {
  @override
  _FixedWidgetState createState() => _FixedWidgetState();
}

class _FixedWidgetState extends State<FixedWidget> {
  late final Stream<int> _stream;  // ✓ Stream persistant
  
  @override
  void initState() {
    super.initState();
    _stream = Stream.periodic(Duration(seconds: 1), (i) => i);
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream,  // ✓ Même Stream réutilisé
      initialData: 0,   // ✓ Valeur par défaut
      builder: (context, snapshot) {
        // ✓ Gestion des états
        if (snapshot.hasError) return Text('Erreur');
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        return Text('${snapshot.data}');  // ✓ Sûr maintenant
      },
    );
  }
}
```

**Impact de l'erreur**:
- Performance dégradée (memory leaks)
- Comportement imprévisible
- Données perdues lors des rebuilds
</details>

---

### Question 17: Optimisation
**Quelle approche est la plus performante pour afficher une grande liste Firestore?**

A) Charger toute la collection d'un coup  
B) Utiliser .limit() et pagination  
C) Utiliser shrinkWrap: true  
D) Charger en Future puis convertir en Stream  

<details>
<summary>Réponse</summary>

**B) Utiliser .limit() et pagination**

**Explication**: Pour une grande collection, charger TOUS les documents est inefficace en termes de:
- Bande passante
- Mémoire
- Temps de chargement
- Coût Firebase (lectures facturées)

**MAUVAIS** - Tout charger:
```dart
// ❌ Charge 10,000 documents même si on en affiche 20!
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('recipes')
    .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    final docs = snapshot.data!.docs;  // 10,000 documents en mémoire!
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) => RecipeCard(docs[index]),
    );
  },
)
```

**BON** - Pagination simple:
```dart
// ✓ Charge seulement 20 documents
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('recipes')
    .orderBy('createdAt', descending: true)
    .limit(20),  // ✓ Limite les résultats
    .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    final docs = snapshot.data!.docs;  // Seulement 20 documents
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) => RecipeCard(docs[index]),
    );
  },
)
```

**MEILLEUR** - Pagination avec "Load More":
```dart
class PaginatedList extends StatefulWidget {
  @override
  _PaginatedListState createState() => _PaginatedListState();
}

class _PaginatedListState extends State<PaginatedList> {
  static const int pageSize = 20;
  DocumentSnapshot? lastDocument;
  bool hasMore = true;
  
  Stream<QuerySnapshot> _getStream() {
    var query = FirebaseFirestore.instance
      .collection('recipes')
      .orderBy('createdAt', descending: true)
      .limit(pageSize);
    
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument!);
    }
    
    return query.snapshots();
  }
  
  void _loadMore() {
    // Logique pour charger plus
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final docs = snapshot.data!.docs;
        
        return ListView.builder(
          itemCount: docs.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == docs.length) {
              return ElevatedButton(
                onPressed: _loadMore,
                child: Text('Charger plus'),
              );
            }
            return RecipeCard(docs[index]);
          },
        );
      },
    );
  }
}
```

**Comparaison de performance**:
- Sans limit: 10,000 lectures Firestore, ~2MB données, 5s chargement
- Avec limit(20): 20 lectures Firestore, ~5KB données, 0.3s chargement
- **Gain: 500x moins de lectures, 400x moins de données!**
</details>

---

### Question 18: Architecture
**Où devrait-on créer le Stream dans une application bien architecturée?**

A) Dans le build() du widget  
B) Dans une classe Repository séparée  
C) Directement dans StreamBuilder  
D) Dans initState() toujours  

<details>
<summary>Réponse</summary>

**B) Dans une classe Repository séparée**

**Explication**: Suivre le principe de séparation des responsabilités (Clean Architecture).

**Architecture recommandée**:

```
┌─────────────────────────────────┐
│        UI Layer (Widgets)        │
│      StreamBuilder affiche       │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│    Business Logic Layer          │
│    (Bloc/Provider/Cubit)         │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│      Data Layer (Repository)     │
│    Création et gestion Streams   │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│       Data Sources               │
│   Firebase, API, Local DB        │
└─────────────────────────────────┘
```

**MAUVAIS** - Tout dans le widget:
```dart
class RecipesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance  // ❌ Logique métier dans l'UI
        .collection('recipes')
        .where('category', isEqualTo: 'Dessert')
        .orderBy('rating', descending: true)
        .snapshots(),
      builder: (context, snapshot) { ... },
    );
  }
}
```

**BON** - Architecture séparée:

**1. Repository (Data Layer)**:
```dart
class RecipeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Méthode qui retourne un Stream
  Stream<List<Recipe>> getRecipesByCategory(String category) {
    return _firestore
      .collection('recipes')
      .where('category', isEqualTo: category)
      .orderBy('rating', descending: true)
      .snapshots()
      .map((snapshot) {
        // Transformer QuerySnapshot en List<Recipe>
        return snapshot.docs.map((doc) {
          return Recipe.fromFirestore(doc);
        }).toList();
      });
  }
  
  Stream<List<Recipe>> searchRecipes(String query) {
    return _firestore
      .collection('recipes')
      .where('name', isGreaterThanOrEqualTo: query)
      .where('name', isLessThanOrEqualTo: query + '\uf8ff')
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => Recipe.fromFirestore(doc))
        .toList());
  }
  
  Future<void> addRecipe(Recipe recipe) async {
    await _firestore.collection('recipes').add(recipe.toMap());
  }
}
```

**2. Business Logic (optionnel, avec Provider/Bloc)**:
```dart
class RecipeProvider extends ChangeNotifier {
  final RecipeRepository _repository = RecipeRepository();
  String _selectedCategory = 'Tous';
  
  String get selectedCategory => _selectedCategory;
  
  Stream<List<Recipe>> get recipesStream {
    if (_selectedCategory == 'Tous') {
      return _repository.getAllRecipes();
    }
    return _repository.getRecipesByCategory(_selectedCategory);
  }
  
  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }
}
```

**3. UI Layer (Widget)**:
```dart
class RecipesList extends StatelessWidget {
  final RecipeRepository repository = RecipeRepository();
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Recipe>>(
      stream: repository.getRecipesByCategory('Dessert'),  // ✓ Propre
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final recipes = snapshot.data!;
        return ListView.builder(
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            return RecipeCard(recipe: recipes[index]);
          },
        );
      },
    );
  }
}
```

**Avantages de cette architecture**:
- ✓ Code réutilisable (repository utilisé par plusieurs widgets)
- ✓ Testable (facile de mocker le repository)
- ✓ Maintenable (changement de Firebase vers autre DB = modifier seulement repository)
- ✓ Séparation des responsabilités
- ✓ Widget léger et focalisé sur l'UI
</details>

---

### Question 19: Cas Réel
**Vous créez un chat. Comment gérer l'affichage des messages en temps réel?**

```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('messages')
    .orderBy('timestamp', descending: true)
    .snapshots(),
  builder: (context, snapshot) {
    // Votre code ici
  },
)
```

**Que devez-vous faire dans le builder?**

<details>
<summary>Réponse Complète</summary>

**Solution Complète pour un Chat en Temps Réel**:

```dart
class ChatScreen extends StatefulWidget {
  final String chatId;
  
  const ChatScreen({required this.chatId});
  
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: Column(
        children: [
          // Zone des messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .collection('messages')
                .orderBy('timestamp', descending: true)  // Plus récents en premier
                .limit(50)  // Limiter pour performance
                .snapshots(),
              builder: (context, snapshot) {
                // 1. Gérer le chargement
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }
                
                // 2. Gérer les erreurs
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text('Erreur de connexion'),
                        ElevatedButton(
                          onPressed: () => setState(() {}),  // Retry
                          child: Text('Réessayer'),
                        ),
                      ],
                    ),
                  );
                }
                
                // 3. Gérer l'absence de messages
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Aucun message',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                        Text('Commencez la conversation!'),
                      ],
                    ),
                  );
                }
                
                // 4. Afficher les messages
                final messages = snapshot.data!.docs;
                
                // Scroller vers le bas pour nouveaux messages
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
                
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,  // Nouveaux messages en bas
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final messageData = messageDoc.data() as Map<String, dynamic>;
                    
                    // Extraction sécurisée des données
                    final text = messageData['text'] as String? ?? '';
                    final senderId = messageData['senderId'] as String? ?? '';
                    final senderName = messageData['senderName'] as String? ?? 'Anonyme';
                    final timestamp = messageData['timestamp'] as Timestamp?;
                    
                    // Détecter si c'est notre message
                    final isMe = senderId == getCurrentUserId();
                    
                    return MessageBubble(
                      text: text,
                      senderName: senderName,
                      timestamp: timestamp?.toDate(),
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          
          // Zone de saisie
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Écrivez un message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    // Effacer le champ immédiatement
    _textController.clear();
    
    // Envoyer à Firestore
    try {
      await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
          'text': text,
          'senderId': getCurrentUserId(),
          'senderName': getCurrentUserName(),
          'timestamp': FieldValue.serverTimestamp(),
        });
    } catch (e) {
      // Gérer l'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'envoi: $e')),
      );
    }
  }
  
  String getCurrentUserId() {
    // Votre logique
    return 'user123';
  }
  
  String getCurrentUserName() {
    // Votre logique
    return 'John Doe';
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }
}

// Widget pour afficher un message
class MessageBubble extends StatelessWidget {
  final String text;
  final String senderName;
  final DateTime? timestamp;
  final bool isMe;
  
  const MessageBubble({
    required this.text,
    required this.senderName,
    this.timestamp,
    required this.isMe,
  });
  
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(
                senderName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 4),
            ],
            Text(text),
            if (timestamp != null) ...[
              SizedBox(height: 4),
              Text(
                '${timestamp!.hour}:${timestamp!.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

**Points clés de cette implémentation**:
1. ✓ Gestion des 4 états (loading, error, empty, data)
2. ✓ Limitation à 50 messages (performance)
3. ✓ Auto-scroll vers nouveaux messages
4. ✓ UI différente pour messages envoyés/reçus
5. ✓ Affichage du timestamp
6. ✓ Gestion des erreurs d'envoi
7. ✓ Dispose des controllers
8. ✓ Extraction sécurisée des données (avec ??)
</details>

---

### Question 20: Performance
**Comment optimiser ce code qui affiche 1000 recettes?**

```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance.collection('recipes').snapshots(),
  builder: (context, snapshot) {
    final docs = snapshot.data?.docs ?? [];
    return ListView(
      children: docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return RecipeCard(
          name: data['name'],
          image: data['imageUrl'],
          rating: data['rating'],
        );
      }).toList(),
    );
  },
)
```

**Identifiez 4 problèmes et proposez des solutions.**

<details>
<summary>Réponse Détaillée</summary>

**Problèmes identifiés**:

**1. Pas de gestion d'états** ❌
```dart
// Manque: vérifications hasError, connectionState, hasData
final docs = snapshot.data?.docs ?? [];  // Masque les problèmes
```

**2. Charge TOUTE la collection** ❌
```dart
// 1000 documents = 1000 lectures Firestore = coût élevé
.collection('recipes').snapshots()
```

**3. ListView non virtualisée** ❌
```dart
// Crée 1000 widgets d'un coup au lieu de virtualiser
ListView(
  children: docs.map(...).toList(),  // Tous les widgets créés
)
```

**4. Pas de const/optimisations** ❌
```dart
// Chaque RecipeCard recréé à chaque nouvelle donnée
return RecipeCard(...);
```

---

**CODE OPTIMISÉ**:

```dart
class OptimizedRecipesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('recipes')
        .orderBy('createdAt', descending: true)
        .limit(50)  // ✓ FIX 2: Limiter les résultats
        .snapshots(),
      builder: (context, snapshot) {
        // ✓ FIX 1: Gestion complète des états
        if (snapshot.hasError) {
          return Center(
            child: ErrorDisplay(error: snapshot.error.toString()),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Chargement des recettes...'),
              ],
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: EmptyState(message: 'Aucune recette disponible'),
          );
        }
        
        final docs = snapshot.data!.docs;
        
        // ✓ FIX 3: ListView.builder pour virtualisation
        return ListView.builder(
          itemCount: docs.length,
          // Recycler les widgets hors écran
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            // ✓ FIX 4: Utiliser key pour optimisation
            return RecipeCard(
              key: ValueKey(doc.id),  // Key unique
              name: data['name'] as String? ?? 'Sans nom',
              imageUrl: data['imageUrl'] as String?,
              rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
            );
          },
        );
      },
    );
  }
}

// Widget optimisé avec const
class RecipeCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double rating;
  
  const RecipeCard({
    Key? key,
    required this.name,
    this.imageUrl,
    required this.rating,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: imageUrl != null
          ? Image.network(
              imageUrl!,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              // Optimisation: cacher les images
              cacheWidth: 100,
              cacheHeight: 100,
            )
          : const Icon(Icons.restaurant, size: 50),
        title: Text(name),
        subtitle: Row(
          children: [
            const Icon(Icons.star, size: 16, color: Colors.amber),
            const SizedBox(width: 4),
            Text(rating.toStringAsFixed(1)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
      ),
    );
  }
}
```

---

**OPTIMISATIONS SUPPLÉMENTAIRES**:

**Pagination avec défilement infini**:
```dart
class InfiniteScrollRecipes extends StatefulWidget {
  @override
  _InfiniteScrollRecipesState createState() => _InfiniteScrollRecipesState();
}

class _InfiniteScrollRecipesState extends State<InfiniteScrollRecipes> {
  final ScrollController _scrollController = ScrollController();
  int _limit = 20;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      // Charger plus quand on atteint 80% du scroll
      setState(() {
        _limit += 20;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('recipes')
        .orderBy('createdAt', descending: true)
        .limit(_limit)  // Augmente progressivement
        .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final docs = snapshot.data!.docs;
        
        return ListView.builder(
          controller: _scrollController,
          itemCount: docs.length + 1,  // +1 pour loader
          itemBuilder: (context, index) {
            if (index == docs.length) {
              // Indicateur de chargement en bas
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            final doc = docs[index];
            return RecipeCard(
              key: ValueKey(doc.id),
              data: doc.data() as Map<String, dynamic>,
            );
          },
        );
      },
    );
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
```

**Mesures de performance**:

| Aspect | Avant | Après | Amélioration |
|--------|-------|-------|--------------|
| Lectures Firestore | 1000 | 50 | **95%** |
| Widgets créés | 1000 | ~10 visibles | **99%** |
| Temps chargement | 8s | 0.5s | **94%** |
| Mémoire utilisée | 50MB | 5MB | **90%** |
| Coût Firebase | $0.50 | $0.025 | **95%** |

**Checklist d'optimisation**:
- [x] Utiliser .limit() pour limiter les requêtes
- [x] ListView.builder au lieu de ListView avec children
- [x] Ajouter des ValueKey pour identification unique
- [x] Utiliser const pour widgets statiques
- [x] Implémenter pagination/infinite scroll
- [x] Cacher les images avec cacheWidth/cacheHeight
- [x] Gérer tous les états (loading, error, empty, data)
- [x] Disposer des controllers (scroll, text, etc.)
</details>

---

## Section D: Questions de Compréhension Avancée

### Question 21: Multiple Streams
**Comment combiner deux Streams pour afficher des données dépendantes?**

Exemple: Afficher les recettes d'un utilisateur ET son profil en même temps.

<details>
<summary>Réponse avec Code Complet</summary>

**Plusieurs approches possibles**:

**APPROCHE 1: StreamBuilder imbriqués** (simple mais verbose)

```dart
class UserRecipesScreen extends StatelessWidget {
  final String userId;
  
  const UserRecipesScreen({required this.userId});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profil et Recettes')),
      body: StreamBuilder<DocumentSnapshot>(
        // Stream 1: Profil utilisateur
        stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          
          return Column(
            children: [
              // Afficher le profil
              UserProfileHeader(
                name: userData['name'] ?? 'Anonyme',
                avatar: userData['avatar'],
              ),
              
              Divider(),
              
              // Stream 2: Recettes de l'utilisateur
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                    .collection('recipes')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
                  builder: (context, recipesSnapshot) {
                    if (!recipesSnapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    
                    final recipes = recipesSnapshot.data!.docs;
                    
                    if (recipes.isEmpty) {
                      return Center(
                        child: Text('${userData['name']} n\'a pas encore de recettes'),
                      );
                    }
                    
                    return ListView.builder(
                      itemCount: recipes.length,
                      itemBuilder: (context, index) {
                        final recipe = recipes[index].data() as Map<String, dynamic>;
                        return RecipeCard(recipe: recipe);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

---

**APPROCHE 2: Rx combineLatest** (avec rxdart package)

```dart
import 'package:rxdart/rxdart.dart';

class CombinedData {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> recipes;
  
  CombinedData(this.user, this.recipes);
}

class UserRecipesScreen extends StatelessWidget {
  final String userId;
  
  const UserRecipesScreen({required this.userId});
  
  Stream<CombinedData> _getCombinedStream() {
    final userStream = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => doc.data() as Map<String, dynamic>);
    
    final recipesStream = FirebaseFirestore.instance
      .collection('recipes')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snap) => snap.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList());
    
    // Combiner les deux streams
    return Rx.combineLatest2(
      userStream,
      recipesStream,
      (user, recipes) => CombinedData(user, recipes),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profil et Recettes')),
      body: StreamBuilder<CombinedData>(
        stream: _getCombinedStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          
          if (!snapshot.hasData) {
            return Center(child: Text('Pas de données'));
          }
          
          final data = snapshot.data!;
          
          return Column(
            children: [
              UserProfileHeader(
                name: data.user['name'] ?? 'Anonyme',
                avatar: data.user['avatar'],
                recipesCount: data.recipes.length,
              ),
              
              Divider(),
              
              Expanded(
                child: data.recipes.isEmpty
                  ? Center(child: Text('Aucune recette'))
                  : ListView.builder(
                      itemCount: data.recipes.length,
                      itemBuilder: (context, index) {
                        return RecipeCard(recipe: data.recipes[index]);
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

---

**APPROCHE 3: Repository Pattern** (Clean Architecture)

```dart
// Repository
class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Stream<UserWithRecipes> getUserWithRecipes(String userId) {
    final userStream = _firestore
      .collection('users')
      .doc(userId)
      .snapshots();
    
    final recipesStream = _firestore
      .collection('recipes')
      .where('userId', isEqualTo: userId)
      .snapshots();
    
    return Rx.combineLatest2(
      userStream,
      recipesStream,
      (userDoc, recipesSnap) {
        final user = User.fromFirestore(userDoc);
        final recipes = recipesSnap.docs
          .map((doc) => Recipe.fromFirestore(doc))
          .toList();
        
        return UserWithRecipes(user: user, recipes: recipes);
      },
    );
  }
}

// Model
class UserWithRecipes {
  final User user;
  final List<Recipe> recipes;
  
  UserWithRecipes({required this.user, required this.recipes});
}

// Widget
class UserRecipesScreen extends StatelessWidget {
  final String userId;
  final UserRepository repository = UserRepository();
  
  const UserRecipesScreen({required this.userId});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profil et Recettes')),
      body: StreamBuilder<UserWithRecipes>(
        stream: repository.getUserWithRecipes(userId),
        builder: (context, snapshot) {
          // Gestion des états...
          
          final data = snapshot.data!;
          
          return Column(
            children: [
              UserProfileCard(user: data.user),
              Expanded(
                child: RecipesList(recipes: data.recipes),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

---

**APPROCHE 4: StreamProvider** (avec Provider package)

```dart
// main.dart
MultiProvider(
  providers: [
    StreamProvider<User?>(
      create: (_) => userStream(userId),
      initialData: null,
    ),
    StreamProvider<List<Recipe>>(
      create: (_) => recipesStream(userId),
      initialData: [],
    ),
  ],
  child: UserRecipesScreen(),
)

// Widget
class UserRecipesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final recipes = context.watch<List<Recipe>>();
    
    if (user == null) {
      return Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
        UserProfileHeader(user: user),
        Expanded(
          child: RecipesList(recipes: recipes),
        ),
      ],
    );
  }
}
```

---

**Comparaison des approches**:

| Approche | Complexité | Testabilité | Performance | Recommandé pour |
|----------|-----------|-------------|-------------|-----------------|
| StreamBuilder imbriqués | Faible | Moyenne | Bonne | Projets simples |
| Rx combineLatest | Moyenne | Bonne | Très bonne | Projets moyens |
| Repository Pattern | Élevée | Excellente | Très bonne | Grands projets |
| StreamProvider | Moyenne | Très bonne | Excellente | Apps avec Provider |

**Recommandation**: Pour un projet professionnel, utilisez Repository Pattern + StreamProvider.
</details>

---

### Question 22-25: Cas Pratiques

Voir le fichier suivant pour les questions finales sur des scénarios réels d'application.

---

## Barème Partie 2
- Questions 16-20 (Pratiques): 6 points chacune = 30 points
- Question 21 (Avancée): 10 points

**Total Partie 2: 40 points**

**Total Global (Partie 1 + 2): 80 points**

---

## Niveaux de Compétence

- **70-80 points**: Expert StreamBuilder
- **55-69 points**: Compétent avancé
- **40-54 points**: Compétent intermédiaire
- **25-39 points**: Compétence de base
- **0-24 points**: Besoin de révision du cours

---

**Félicitations d'avoir complété le quiz StreamBuilder!**

