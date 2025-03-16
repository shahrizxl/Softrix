import 'package:flutter/material.dart';
import 'package:Tradezy/pages/article.dart';
import 'package:Tradezy/pages/consts.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

class Newspage extends StatefulWidget {
  const Newspage({super.key});

  @override
  State<Newspage> createState() => NewspageState();
}

class NewspageState extends State<Newspage> {
  final Dio dio = Dio();
  List<Article> articles = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _getNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("News"),
      ),
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  return ListTile(
                    onTap: () {
                      _launchUrl(Uri.parse(article.url ?? ""));
                    },
                    leading: Image.network(
                      article.urlToImage ?? PLACEHOLDER_IMAGE_LINK,
                      height: 250,
                      width: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          PLACEHOLDER_IMAGE_LINK,
                          height: 250,
                          width: 100,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                    title: Text(
                      article.title ?? "No Title",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      article.publishedAt ?? "No Date",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              );
  }

  Future<void> _getNews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await dio.get(
          'https://newsapi.org/v2/top-headlines?country=us&category=business&apiKey=${NEWS_API_KEY}');
      if (response.statusCode == 200) {
        final articleJson = response.data["articles"] as List;
        setState(() {
          List<Article> newsArticle = articleJson
              .map((a) => Article.fromJson(a))
              .toList()
              .where((a) => a.title != "[Removed]")
              .toList();
          articles = newsArticle;
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
    if (!await launchUrl(url)) {
      setState(() {
        _errorMessage = 'Could not launch $url';
      });
      throw Exception('Could not launch $url');
    }
  }
}

