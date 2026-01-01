import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// SearchResult model to encapsulate Tavily search results
class SearchResult {
  final String answer;
  final List<SearchSource> sources;
  final bool hasResults;

  SearchResult({
    required this.answer,
    required this.sources,
    required this.hasResults,
  });

  factory SearchResult.empty() {
    return SearchResult(answer: '', sources: [], hasResults: false);
  }

  /// Format the result for consumption by the LLM
  String toFormattedString() {
    if (!hasResults) {
      return 'No verified information found for this query.';
    }

    final buffer = StringBuffer();
    buffer.writeln('=== WEB SEARCH RESULTS ===');
    buffer.writeln();

    if (answer.isNotEmpty) {
      buffer.writeln('📋 SUMMARY:');
      buffer.writeln(answer);
      buffer.writeln();
    }

    if (sources.isNotEmpty) {
      buffer.writeln('📚 SOURCES:');
      for (int i = 0; i < sources.length && i < 5; i++) {
        final source = sources[i];
        buffer.writeln('${i + 1}. ${source.title}');
        buffer.writeln('   URL: ${source.url}');
        if (source.snippet.isNotEmpty) {
          buffer.writeln('   Excerpt: ${source.snippet}');
        }
        buffer.writeln();
      }
    }

    buffer.writeln('=== END OF SEARCH RESULTS ===');
    return buffer.toString();
  }
}

/// Individual source from search results
class SearchSource {
  final String title;
  final String url;
  final String snippet;
  final double score;

  SearchSource({
    required this.title,
    required this.url,
    required this.snippet,
    required this.score,
  });

  factory SearchSource.fromJson(Map<String, dynamic> json) {
    return SearchSource(
      title: json['title'] ?? 'Unknown Title',
      url: json['url'] ?? '',
      snippet: json['content'] ?? json['snippet'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
    );
  }
}

/// SearchService - Handles web searches using Tavily API
///
/// Tavily is an AI-focused search API that provides:
/// - Advanced search with fact-checking
/// - Direct answers to queries
/// - Cited sources for verification
class SearchService {
  static const String _tavilyEndpoint = 'https://api.tavily.com/search';

  /// Performs an advanced web search using Tavily API
  ///
  /// [query] - The search query string
  ///
  /// Returns a [SearchResult] containing the answer and sources
  Future<SearchResult> search(String query) async {
    final apiKey = dotenv.env['TAVILY_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('SearchService Error: TAVILY_API_KEY is missing.');
      return SearchResult.empty();
    }

    if (query.trim().isEmpty) {
      debugPrint('SearchService Error: Empty query provided.');
      return SearchResult.empty();
    }

    try {
      final requestBody = {
        'api_key': apiKey,
        'query': query,
        'search_depth': 'advanced', // Advanced search for fact-checking
        'include_answer': true, // Get a synthesized answer
        'include_raw_content': false,
        'max_results': 5, // Limit for efficiency
        'include_domains': [], // No domain restrictions
        'exclude_domains': [], // No exclusions
      };

      debugPrint('SearchService: Executing advanced search for: "$query"');

      final response = await http.post(
        Uri.parse(_tavilyEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseResponse(data);
      } else {
        debugPrint(
          'Tavily API Error: ${response.statusCode} - ${response.body}',
        );
        return SearchResult.empty();
      }
    } catch (e) {
      debugPrint('SearchService Exception: $e');
      return SearchResult.empty();
    }
  }

  /// Parses the Tavily API response into a SearchResult
  SearchResult _parseResponse(Map<String, dynamic> data) {
    try {
      final String answer = data['answer'] ?? '';
      final List<dynamic> results = data['results'] ?? [];

      // Parse sources
      final sources = results
          .map((r) => SearchSource.fromJson(r as Map<String, dynamic>))
          .where((s) => s.url.isNotEmpty) // Filter out invalid sources
          .toList();

      // Sort by relevance score
      sources.sort((a, b) => b.score.compareTo(a.score));

      final hasResults = answer.isNotEmpty || sources.isNotEmpty;

      debugPrint(
        'SearchService: Found ${sources.length} sources, answer: ${answer.isNotEmpty}',
      );

      return SearchResult(
        answer: answer,
        sources: sources,
        hasResults: hasResults,
      );
    } catch (e) {
      debugPrint('SearchService Parse Error: $e');
      return SearchResult.empty();
    }
  }

  /// Quick check if a query likely needs real-time web data
  ///
  /// This is a helper method to determine if web search should be triggered
  static bool isRealTimeQuery(String query) {
    final realTimeKeywords = [
      'weather',
      'stock',
      'stocks',
      'price',
      'news',
      'today',
      'current',
      'latest',
      'now',
      'live',
      'happening',
      'breaking',
      'recent',
      'update',
      'score',
      'match',
      'game',
      'election',
      'market',
      'cryptocurrency',
      'bitcoin',
      'crypto',
    ];

    final lowerQuery = query.toLowerCase();
    return realTimeKeywords.any((keyword) => lowerQuery.contains(keyword));
  }
}
