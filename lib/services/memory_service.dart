import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Using a popular, lightweight model for embeddings
  // Ensures compatibility with standard 384-dimension vector columns
  static const String _hfModelApi =
      "https://router.huggingface.co/hf-inference/models/sentence-transformers/all-MiniLM-L6-v2/pipeline/feature-extraction";

  /// 1. Get Vector Embedding from HuggingFace
  Future<List<double>?> _getEmbedding(String text) async {
    final apiKey = dotenv.env['HF_TOKEN'];
    try {
      final response = await http.post(
        Uri.parse(_hfModelApi),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "inputs": [text], // Wrapped in a list as per new router requirements
          "options": {"wait_for_model": true},
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // The router returns a list containing the vector list: [[0.12, 0.45...]]
        if (data.isNotEmpty && data[0] is List) {
          return List<double>.from(data[0].map((x) => x.toDouble()));
        }
      }
      return null;
    } catch (e) {
      debugPrint("Embedding Error: $e");
      return null;
    }
  }

  /// Retrieves relevant context from the 'jarvis_memory' table.
  Future<String> retrieveContext(String query) async {
    try {
      // 1. Convert the search query into a vector
      final List<double>? queryVector = await _getEmbedding(query);

      if (queryVector == null) {
        return "I'm having trouble accessing my neural patterns, Sir.";
      }

      // 2. Call the 'match_memories' RPC function in Supabase
      // This compares the query vector against all stored vectors
      final List<dynamic> response = await _supabase.rpc(
        'match_memories',
        params: {
          'query_embedding': queryVector,
          'match_threshold': 0.4, // Sensitivity: 0.0 to 1.0
          'match_count': 3, // Number of memories to retrieve
        },
      );

      if (response.isEmpty) {
        return "No specific archives found regarding '$query', Sir.";
      }

      // 3. Format the found memories for the LLM
      final memories = response
          .map(
            (e) =>
                "- ${e['content']} (Relevance: ${(e['similarity'] * 100).toStringAsFixed(1)}%)",
          )
          .join('\n');

      return "Here is what I found in your archives:\n$memories";
    } catch (e) {
      debugPrint("Retrieval Error: $e");
      return "Error accessing memory vault: $e";
    }
  }

  Future<bool> saveMemory(String content) async {
    try {
      final List<double>? vector = await _getEmbedding(content);
      if (vector == null) return false;

      // Log the dimension count to verify (Should be 384)
      debugPrint("Saving Memory. Vector Dimension: ${vector.length}");

      await _supabase.from('jarvis_memory').insert({
        'content': content,
        'embedding': vector,
      });

      debugPrint("✅ Memory Saved: $content");
      return true;
    } catch (e) {
      debugPrint("❌ Database Error: $e");
      return false;
    }
  }

  Future<int> getMemoryCount() async {
    try {
      // Use count option
      final response = await _supabase
          .from('jarvis_memory')
          .count(CountOption.exact);
      return response;
    } catch (e) {
      debugPrint("Error fetching memory count: $e");
      return 0;
    }
  }

  Future<void> wipeMemory() async {
    try {
      // Delete all rows where id is not 0 (effectively all)
      await _supabase.from('jarvis_memory').delete().neq('id', 0);
      debugPrint("Global Memory Wipe Initiated.");
    } catch (e) {
      debugPrint("Error wiping memory: $e");
      throw Exception("Failed to wipe memory: $e");
    }
  }

  Widget memoryCard(String content, double similarity) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.cyan.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content, style: TextStyle(color: Colors.white, fontSize: 16)),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.psychology, size: 14, color: Colors.cyan),
              SizedBox(width: 5),
              Text(
                "${(similarity * 100).toInt()}% Match",
                style: TextStyle(color: Colors.cyan, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
