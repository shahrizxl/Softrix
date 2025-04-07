import 'package:flutter/material.dart';
import 'package:Tradezy/pages/article.dart';
import 'package:Tradezy/pages/consts.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:Tradezy/pages/bottomnav.dart';

class Newspage extends StatefulWidget {
  const Newspage({super.key});

  @override
  State<Newspage> createState() => NewspageState();
}

class NewspageState extends State<Newspage> with SingleTickerProviderStateMixin {
  final Dio dio = Dio();
  List<Article> articles = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  List<Article> _filteredArticles = [];
  bool _isSearching = false;
  late TabController _tabController;
  final List<String> _categories = ['Business', 'Technology', 'Finance', 'Markets'];
  String _currentCategory = 'Business';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _getNews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentCategory = _categories[_tabController.index];
      });
      _getNews();
    }
  }

  void _filterArticles(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredArticles = articles;
        _isSearching = false;
      } else {
        _isSearching = true;
        _filteredArticles = articles
            .where((article) =>
        article.title?.toLowerCase().contains(query.toLowerCase()) ?? false)
            .toList();
      }
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'No date';
    try {
      final DateTime date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    //FontWeight: FontWeight.bold, // Example of font update
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Financial News',
          style: TextStyle(
            color: Color(0xFF2D3436),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3436)),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const BottomNav()),
            );
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterArticles,
                  decoration: InputDecoration(
                    hintText: 'Search news...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF29ABE2)), // Changed color
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF29ABE2)), // Changed color
                      onPressed: () {
                        _searchController.clear();
                        _filterArticles('');
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF29ABE2).withOpacity(0.05), // Changed color
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFF29ABE2), // Changed color
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF29ABE2), // Changed color
                indicatorSize: TabBarIndicatorSize.label,
                tabs: _categories.map((category) => Tab(text: category)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final displayArticles = _isSearching ? _filteredArticles : articles;

    if (displayArticles.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: const Color(0xFF29ABE2), // Changed color
      onRefresh: () async {
        setState(() {
          _isRefreshing = true;
        });
        await _getNews();
        setState(() {
          _isRefreshing = false;
        });
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Found ${displayArticles.length} results for "${_searchController.text}"',
                style: const TextStyle(
                  color: Color(0xFF2D3436),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Featured article (first article with larger card)
          if (displayArticles.isNotEmpty && !_isSearching)
            _buildFeaturedArticleCard(displayArticles[0]),

          // Rest of the articles
          ...displayArticles.skip(_isSearching ? 0 : 1).map((article) => _buildArticleCard(article)),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Placeholder image - 120x120 pixels
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF29ABE2).withOpacity(0.1), // Changed color
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'images/news_loading.png', // This is a placeholder - you'll replace this
                width: 80,
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading news loading image: $error');
                  return const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF29ABE2)), // Changed color
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading financial news...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Placeholder image - 120x120 pixels
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'images/news_error.png', // This is a placeholder - you'll replace this
                width: 80,
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading news error image: $error');
                  return const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _getNews,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF29ABE2), // Changed color
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Placeholder image - 150x150 pixels
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFF29ABE2).withOpacity(0.1), // Changed color
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'images/empty_news.png', // This is a placeholder - you'll replace this
                width: 100,
                height: 100,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading empty news image: $error');
                  return const Icon(
                    Icons.newspaper,
                    size: 80,
                    color: Color(0xFF29ABE2), // Changed color
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isSearching ? 'No results found' : 'No news available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSearching
                ? 'Try a different search term'
                : 'Check back later for updates',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: TextButton(
                onPressed: () {
                  _searchController.clear();
                  _filterArticles('');
                },
                child: const Text(
                  'Clear Search',
                  style: TextStyle(
                    color: Color(0xFF29ABE2), // Changed color
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedArticleCard(Article article) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        onTap: () => _launchUrl(Uri.parse(article.url ?? "")),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    Image.network(
                      article.urlToImage ?? PLACEHOLDER_IMAGE_LINK,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Image.asset(
                              'images/news_placeholder.png', // This is a placeholder - you'll replace this
                              width: 80,
                              height: 80,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading news placeholder image: $error');
                                return const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                  color: Colors.grey,
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    // Glassmorphism effect (subtle)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF29ABE2).withOpacity(0.1), // Changed color
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'FEATURED',
                      style: TextStyle(
                        color: const Color(0xFF29ABE2), // Changed color
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.title ?? 'No Title',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.description ?? 'No description available',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Color(0xFF29ABE2), // Changed color
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(article.publishedAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        article.source?.name ?? 'Unknown Source',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF29ABE2), // Changed color
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(Article article) {
    return Container(
      decoration: BoxDecoration( // Adding Glassmorphism-like effect on the Card
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _launchUrl(Uri.parse(article.url ?? "")),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: SizedBox(
                width: 120, // 120x120 pixels
                height: 120,
                child: Image.network(
                  article.urlToImage ?? PLACEHOLDER_IMAGE_LINK,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Image.asset(
                          'images/news_placeholder.png', // This is a placeholder - you'll replace this
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading news placeholder image: $error');
                            return const Icon(
                              Icons.image_not_supported,
                              size: 30,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title ?? 'No Title',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.source?.name ?? 'Unknown Source',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF29ABE2), // Changed color
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Color(0xFF29ABE2), // Changed color
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(article.publishedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _getNews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Convert category to lowercase for the API
      final category = _currentCategory.toLowerCase();

      final response = await dio.get(
          'https://newsapi.org/v2/top-headlines?country=us&category=$category&apiKey=${NEWS_API_KEY}');

      if (response.statusCode == 200) {
        final articleJson = response.data["articles"] as List;
        setState(() {
          List<Article> newsArticle = articleJson
              .map((a) => Article.fromJson(a))
              .toList()
              .where((a) => a.title != "[Removed]")
              .toList();
          articles = newsArticle;
          _filteredArticles = articles;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load news: Status code ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load news: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(Uri url) async {
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not launch $url: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open the article: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}