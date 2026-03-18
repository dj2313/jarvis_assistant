import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/memory_service.dart';

class MemoryVaultScreen extends StatefulWidget {
  const MemoryVaultScreen({super.key});

  @override
  State<MemoryVaultScreen> createState() => _MemoryVaultScreenState();
}

class _MemoryVaultScreenState extends State<MemoryVaultScreen> {
  final MemoryService _memoryService = MemoryService();
  List<Map<String, dynamic>> _memories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMemories();
  }

  Future<void> _fetchMemories() async {
    setState(() => _isLoading = true);
    final data = await _memoryService.getAllMemories();
    if (mounted) {
      setState(() {
        _memories = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteMemory(int id, int index) async {
    // Optimistic update
    final backup = _memories[index];
    setState(() {
      _memories.removeAt(index);
    });

    try {
      await _memoryService.deleteMemory(id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Memory Node Deleted",
            style: GoogleFonts.shareTechMono(),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // Revert if failed
      setState(() {
        _memories.insert(index, backup);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Deletion Failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: Text(
          "MEMORY VAULT EXPLORER",
          style: GoogleFonts.orbitron(
            color: Colors.cyanAccent,
            letterSpacing: 2,
            fontSize: 14,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.cyanAccent),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: _fetchMemories,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  )
                : _memories.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: _memories.length,
                    itemBuilder: (context, index) {
                      final memory = _memories[index];
                      return _buildMemoryCard(memory, index)
                          .animate()
                          .fadeIn(duration: 300.ms, delay: (50 * index).ms)
                          .slideY(begin: 0.1, end: 0);
                    },
                  ),
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
          Icon(Icons.memory_outlined, size: 80, color: Colors.white10),
          const SizedBox(height: 20),
          Text(
            "NO DATA ARCHIVED",
            style: GoogleFonts.orbitron(color: Colors.white30, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(Map<String, dynamic> memory, int index) {
    final id = memory['id'] as int;
    final content = memory['content'] as String;
    final date = memory['created_at'] != null
        ? DateTime.parse(
            memory['created_at'],
          ).toLocal().toString().split('.')[0]
        : "Unknown Date";

    return Dismissible(
      key: Key(id.toString()),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withOpacity(0.2),
        child: const Icon(Icons.delete, color: Colors.redAccent),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => _deleteMemory(id, index),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 100, // Fixed height for uniformity
        margin: const EdgeInsets.only(bottom: 12),
        borderRadius: 16,
        blur: 15,
        alignment: Alignment.center,
        border: 1,
        linearGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderGradient: LinearGradient(
          colors: [Colors.cyanAccent.withOpacity(0.3), Colors.transparent],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint,
                  color: Colors.cyanAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Archived: $date",
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              // Delete Button (Mini)
              IconButton(
                icon: Icon(Icons.close, color: Colors.white24, size: 18),
                onPressed: () => _deleteMemory(id, index),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
