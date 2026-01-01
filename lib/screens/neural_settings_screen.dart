import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/memory_service.dart';

class NeuralSettingsScreen extends StatefulWidget {
  const NeuralSettingsScreen({super.key});

  @override
  State<NeuralSettingsScreen> createState() => _NeuralSettingsScreenState();
}

class _NeuralSettingsScreenState extends State<NeuralSettingsScreen> {
  final MemoryService _memoryService = MemoryService();

  double _responsePrecision = 0.7; // Default temperature
  double _searchDepth = 0.0; // 0.0 = Basic, 1.0 = Advanced
  int _memoryCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchMemoryStats();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _responsePrecision = prefs.getDouble('response_precision') ?? 0.7;
      _searchDepth = prefs.getDouble('search_depth') ?? 0.0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('response_precision', _responsePrecision);
    await prefs.setDouble('search_depth', _searchDepth);
  }

  Future<void> _fetchMemoryStats() async {
    final count = await _memoryService.getMemoryCount();
    if (mounted) {
      setState(() {
        _memoryCount = count;
        _isLoading = false;
      });
    }
  }

  Future<void> _wipeMemory() async {
    // Show confirmation dialog locally using a glassmorphic style
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => _buildGlassDialog(context),
        ) ??
        false;

    if (confirm) {
      HapticFeedback.heavyImpact();
      await _memoryService.wipeMemory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Memory Core Purged.",
              style: GoogleFonts.shareTechMono(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        _fetchMemoryStats();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: Text(
          "NEURAL CONFIGURATION",
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
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background (Static or shared painter could be used)
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF1A1A2E), Colors.black],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  // 1. Brain Capacity Gauge
                  _buildCapacityGauge(),

                  const SizedBox(height: 50),

                  // 2. Sliders
                  _buildSliderSection(
                    "RESPONSE PRECISION",
                    "Temperature: ${_responsePrecision.toStringAsFixed(1)}",
                    _responsePrecision,
                    (val) {
                      setState(() => _responsePrecision = val);
                      _saveSettings();
                    },
                    Colors.cyanAccent,
                  ),

                  const SizedBox(height: 30),

                  _buildSliderSection(
                    "SEARCH DEPTH",
                    _searchDepth > 0.5 ? "Advanced (Deep)" : "Basic (Fast)",
                    _searchDepth,
                    (val) {
                      setState(() => _searchDepth = val);
                      _saveSettings();
                    },
                    Colors.purpleAccent,
                    divisions: 1,
                  ),

                  const Spacer(),

                  // 3. Wipe Memory Button
                  _buildWipeButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityGauge() {
    return Column(
      children: [
        SizedBox(
          height: 180,
          width: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.1),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              // Gauge
              SizedBox(
                height: 160,
                width: 160,
                child: CircularProgressIndicator(
                  value:
                      _memoryCount / 1000, // Assuming 1000 capacity visual cap
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(Colors.cyanAccent),
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Inner Text
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.memory, color: Colors.cyanAccent, size: 30)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: Offset(1, 1),
                        end: Offset(1.1, 1.1),
                        duration: 1.seconds,
                      ),
                  const SizedBox(height: 10),
                  Text(
                    _isLoading ? "..." : "$_memoryCount",
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "NODES ACTIVE",
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSliderSection(
    String title,
    String status,
    double value,
    ValueChanged<double> onChanged,
    Color activeColor, {
    int? divisions,
  }) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 120,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 1,
      linearGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.05),
          Colors.white.withOpacity(0.02),
        ],
      ),
      borderGradient: LinearGradient(
        colors: [activeColor.withOpacity(0.5), Colors.transparent],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.orbitron(
                    color: activeColor,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  status,
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: activeColor,
                inactiveTrackColor: Colors.white10,
                thumbColor: Colors.white,
                overlayColor: activeColor.withOpacity(0.2),
                trackHeight: 2,
              ),
              child: Slider(
                value: value,
                onChanged: onChanged,
                divisions: divisions,
                min: 0.0,
                max: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWipeButton() {
    return GestureDetector(
      onTap: _wipeMemory,
      child:
          GlassmorphicContainer(
                width: double.infinity,
                height: 60,
                borderRadius: 30,
                blur: 20,
                alignment: Alignment.center,
                border: 1,
                linearGradient: LinearGradient(
                  colors: [
                    Colors.redAccent.withOpacity(0.1),
                    Colors.red.withOpacity(0.05),
                  ],
                ),
                borderGradient: LinearGradient(
                  colors: [
                    Colors.redAccent.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_forever, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Text(
                      "INITIATE CORE WIPE",
                      style: GoogleFonts.orbitron(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: Offset(1, 1),
                end: Offset(1.02, 1.02),
                duration: 2.seconds,
              ),
    );
  }

  Widget _buildGlassDialog(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassmorphicContainer(
        width: 300,
        height: 250,
        borderRadius: 20,
        blur: 20,
        alignment: Alignment.center,
        border: 1,
        linearGradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.6),
          ],
        ),
        borderGradient: LinearGradient(
          colors: [Colors.redAccent, Colors.transparent],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: 20),
              Text(
                "CONFIRM PURGE",
                style: GoogleFonts.orbitron(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "This action is irreversible. All cached memory nodes will be lost.",
                textAlign: TextAlign.center,
                style: GoogleFonts.shareTechMono(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      "CANCEL",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text("PURGE", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
