import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/jarvis_orb.dart';
import '../services/voice_service.dart';
import '../services/jarvis_brain_service.dart';

// Enhanced Chat Message Model
class ChatMessage {
  final String text;
  final String? thought;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser, this.thought});
}

class JarvisHomeScreen extends StatefulWidget {
  const JarvisHomeScreen({super.key});

  @override
  State<JarvisHomeScreen> createState() => _JarvisHomeScreenState();
}

class _JarvisHomeScreenState extends State<JarvisHomeScreen>
    with TickerProviderStateMixin {
  AssistantState _state = AssistantState.idle;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  String _liveTranscript = "";
  double _soundLevel = 0.0;
  String? _currentThoughtLine;
  bool _hasInteracted = false; // Track if chat should be shown

  final VoiceService _voiceService = VoiceService();
  final JarvisBrainService _brainService = JarvisBrainService();
  StreamSubscription<double>? _amplitudeSub;

  final List<Map<String, String>> _supportedLanguages = [
    {'name': 'EN', 'locale': 'en-GB'},
    {'name': 'FR', 'locale': 'fr-FR'},
    {'name': 'DE', 'locale': 'de-DE'},
    {'name': 'ES', 'locale': 'es-ES'},
    {'name': 'HI', 'locale': 'hi-IN'},
  ];

  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _initializeVoice();
    _initializeHistory();
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  // --- Core Logic ---

  Future<void> _initializeVoice() async {
    try {
      await _voiceService.initialize();
      _amplitudeSub = _voiceService.amplitudeStream.listen((amp) {
        if (mounted && _state == AssistantState.speaking) {
          setState(() {
            _soundLevel = amp;
          });
        }
      });
    } catch (e) {
      debugPrint("Voice Init Error: $e");
    }
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning, Sir.";
    if (hour < 17) return "Good Afternoon, Sir.";
    return "Good Evening, Sir.";
  }

  Future<void> _initializeHistory() async {
    final greeting = _getTimeBasedGreeting();

    setState(() {
      _messages.add(ChatMessage(text: greeting, isUser: false));
    });

    // Speak the greeting
    await _voiceService.speak(greeting);

    // Initializing history silently
    await _brainService.initializeHistory();
  }

  Future<void> _playSound(String assetName) async {
    // Placeholder
  }

  void _handleOrbTap() async {
    HapticFeedback.heavyImpact();
    _playSound('activate');
    if (_state == AssistantState.idle || _state == AssistantState.speaking) {
      _startListening();
    } else if (_state == AssistantState.listening) {
      await _voiceService.stopListening();
    } else if (_state == AssistantState.thinking) {
      setState(() {
        _state = AssistantState.idle;
      });
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _state = AssistantState.listening;
      _liveTranscript = "Listening...";
      _hasInteracted = true; // Show chat
    });
    try {
      await _voiceService.startListening(
        onResult: (text) {
          if (mounted) setState(() => _liveTranscript = text);
        },
        onStatus: (status) {
          if (status == 'notListening') {
            if (mounted) {
              if (_state == AssistantState.listening &&
                  _liveTranscript != "Listening..." &&
                  _liveTranscript.isNotEmpty) {
                _handleUserCommand(_liveTranscript);
              } else {
                setState(() {
                  _state = AssistantState.idle;
                  _liveTranscript = "";
                  _soundLevel = 0.0;
                });
              }
            }
          }
        },
        onSoundLevel: (level) {
          if (mounted && _state == AssistantState.listening) {
            setState(() => _soundLevel = ((level + 5) / 15).clamp(0.0, 1.0));
          }
        },
      );
    } catch (e) {
      setState(() => _state = AssistantState.idle);
    }
  }

  void _handleUserCommand(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _hasInteracted = true;
      _messages.add(ChatMessage(text: text, isUser: true));
      _liveTranscript = "";
      _textController.clear();
      _state = AssistantState.thinking;
      _currentThoughtLine = "Initializing Neural Net...";
    });
    _playSound('processing');
    _scrollToBottom();
    _processCommand(text);
  }

  Future<void> _processCommand(String text) async {
    final BrainResponse response = await _brainService.chatWithIntelligence(
      text,
      onPhaseChange: _handlePhaseChange,
    );

    if (!mounted) return;

    setState(() {
      _currentThoughtLine = null;
      _state = AssistantState.speaking;
      _messages.add(
        ChatMessage(
          text: response.content,
          thought: response.thought,
          isUser: false,
        ),
      );
    });
    _playSound('response');
    _scrollToBottom();
    await _voiceService.speak(response.content);
    if (mounted) {
      setState(() => _state = AssistantState.idle);
    }
  }

  void _handlePhaseChange(AgentPhase phase, String? statusMessage) {
    if (!mounted) return;
    setState(() {
      switch (phase) {
        case AgentPhase.thinking:
          _state = AssistantState.thinking;
          _currentThoughtLine = statusMessage ?? "Analyzing Query...";
          break;
        case AgentPhase.searchingWeb:
          _state = AssistantState.searchingWeb;
          _currentThoughtLine = statusMessage ?? "Scanning Web...";
          break;
        case AgentPhase.searchingMemory:
          _state = AssistantState.searchingMemory;
          _currentThoughtLine = statusMessage ?? "Accessing Memory Vault...";
          break;
        case AgentPhase.savingMemory:
          _state = AssistantState.savingMemory;
          _currentThoughtLine = statusMessage ?? "Saving to Core...";
          break;
        case AgentPhase.synthesizing:
          _state = AssistantState.synthesizing;
          _currentThoughtLine = statusMessage ?? "Synthesizing...";
          break;
        case AgentPhase.complete:
          _currentThoughtLine = null;
          break;
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _changeLanguage(String locale) async {
    HapticFeedback.selectionClick();
    await _voiceService.setLanguage(locale);
    setState(() {});
    String confirmation = "Language recalibrated.";
    _voiceService.speak(confirmation);
  }

  // --- UI Layout ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: Stack(
        children: [
          // 1. Particle Background
          Positioned.fill(
            child: CustomPaint(painter: ParticlePainter(_particleController)),
          ),

          SafeArea(
            child: Column(
              children: [
                // 2. Navbar with System Status Icons
                StreamBuilder<int>(
                  stream: _brainService.memoryCountStream,
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return _buildNeuralHeader(count);
                  },
                ),

                // 3. Main Content Area (Orb + Chat)
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Central Orb
                      // Transitions to top when interacted
                      AnimatedPositioned(
                        duration: 800.ms,
                        curve: Curves.easeOutCubic,
                        top: _hasInteracted ? 0 : null,
                        child: AnimatedContainer(
                          duration: 800.ms,
                          curve: Curves.easeOutCubic,
                          width: _hasInteracted ? 140 : 280,
                          height: _hasInteracted ? 140 : 280,
                          child: JarvisOrb(
                            state: _state,
                            soundLevel: _soundLevel,
                            onTap: _handleOrbTap,
                          ),
                        ),
                      ),

                      // Chat Overlay
                      // Positioned below the Orb (140 + padding)
                      if (_hasInteracted && _messages.isNotEmpty)
                        Positioned.fill(
                          top: 150, // Starts below the shrunk Orb
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black,
                                  Colors.black,
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.05, 0.95, 1.0],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: _buildChatList(),
                            ),
                          ),
                        ).animate().fadeIn(
                          duration: 800.ms,
                          curve: Curves.easeOut,
                        ),

                      // Thinking Status
                      if (_currentThoughtLine != null)
                        Positioned(
                          bottom: 20,
                          child: _buildThinkingIndicator(),
                        ),
                    ],
                  ),
                ),

                // 4. Floating Command Bar
                _buildFloatingCommandBar(),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeuralHeader(int memoryCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: System Identity
          Flexible(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "JARVIS CORE",
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.orbitron(
                    color: Colors.cyan,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.5),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "NEURAL LINK: ACTIVE",
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.shareTechMono(
                          color: Colors.greenAccent.withOpacity(0.8),
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right: Controls & Memory Status
          Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Test Sentinel Button
                  _buildSentinelButton(),

                  const SizedBox(width: 8),

                  // Memory Count Capsule (Interactive)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showMemoryStatus(memoryCount);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.05),
                        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.storage,
                            size: 14,
                            color: Colors.cyan.withOpacity(0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$memoryCount NODES",
                            style: GoogleFonts.shareTechMono(
                              color: Colors.cyanAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Menu Options
                  _buildMenuOptions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentinelButton() {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "ANALYZING...",
                  style: GoogleFonts.shareTechMono(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        final result = await _brainService.checkProactiveStatus();

        if (!mounted) return;

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.contains("NOMINAL")
                  ? "✓ NOMINAL"
                  : result.contains("ERROR")
                  ? "⚠ ERROR"
                  : "🔔 ALERT SENT",
              style: GoogleFonts.shareTechMono(color: Colors.white),
            ),
            backgroundColor: result.contains("NOMINAL")
                ? Colors.green.withOpacity(0.8)
                : result.contains("ERROR")
                ? Colors.red.withOpacity(0.8)
                : Colors.orange.withOpacity(0.8),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.shield_outlined,
              size: 14,
              color: Colors.orange.withOpacity(0.9),
            ),
            const SizedBox(width: 6),
            Text(
              "SENTINEL",
              style: GoogleFonts.shareTechMono(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMemoryStatus(int memoryCount) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassmorphicContainer(
          width: 300,
          height: 350,
          borderRadius: 20,
          blur: 20,
          alignment: Alignment.center,
          border: 1,
          linearGradient: LinearGradient(
            colors: [Colors.black87, Colors.black54],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderGradient: LinearGradient(
            colors: [Colors.cyan.withOpacity(0.5), Colors.transparent],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "NEURAL DIAGNOSTIC",
                  style: GoogleFonts.orbitron(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Divider(color: Colors.cyan),
                const SizedBox(height: 20),

                _buildDiagnosticRow("Status", "ONLINE", Colors.greenAccent),
                _buildDiagnosticRow("Core Nodes", "$memoryCount", Colors.white),
                _buildDiagnosticRow("Cycle", "ACTIVE", Colors.blueAccent),
                _buildDiagnosticRow("Sentinel", "ARMED", Colors.orangeAccent),

                const Spacer(),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "CLOSE DIAGNOSTIC",
                      style: GoogleFonts.shareTechMono(
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.shareTechMono(color: Colors.grey)),
          Text(
            value,
            style: GoogleFonts.shareTechMono(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOptions() {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'delete_history') {
          await _brainService.clearHistory();
          setState(() {
            _messages.clear();
            _messages.add(
              ChatMessage(text: "Memory banks purged, Sir.", isUser: false),
            );
          });
        } else if (value == 'logout') {
          // Implement logout logic here
          // For now, we'll just pop to the previous screen or show a message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Logging out..."),
              duration: Duration(seconds: 1),
            ),
          );
          // Assuming a parent navigator exists, otherwise replace with appropriate navigation
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      color: const Color(0xFF1E1E1E),
      icon: Icon(Icons.more_vert, color: Colors.blueAccent, size: 20),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'delete_history',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
              const SizedBox(width: 10),
              Text(
                "Purge Memory",
                style: GoogleFonts.shareTechMono(color: Colors.white),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                "Logout",
                style: GoogleFonts.shareTechMono(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(
        top: 10,
        bottom: 80,
      ), // Less top padding since Positioned handles offset
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildMessageCard(msg);
      },
    );
  }

  Widget _buildMessageCard(ChatMessage msg) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: isUser ? Radius.circular(20) : Radius.circular(5),
            bottomRight: isUser ? Radius.circular(5) : Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.black.withOpacity(0.6),
                border: Border.all(
                  color: isUser
                      ? Colors.blueAccent.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isUser) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "JARVIS",
                          style: GoogleFonts.orbitron(
                            color: Colors.blueAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    msg.text,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: isUser ? 1.0 : 0.9),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return GlassmorphicContainer(
          width: 250,
          height: 40,
          borderRadius: 20,
          blur: 20,
          alignment: Alignment.center,
          border: 1,
          linearGradient: LinearGradient(
            colors: [Colors.black54, Colors.black26],
          ),
          borderGradient: LinearGradient(
            colors: [Colors.blueAccent.withOpacity(0.5), Colors.transparent],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _currentThoughtLine ?? "Processing...",
                style: GoogleFonts.shareTechMono(
                  color: Colors.blueAccent,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .fadeIn(duration: 400.ms)
        .then()
        .fadeOut(duration: 400.ms, delay: 1200.ms);
  }

  Widget _buildFloatingCommandBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 55,
            color: Colors.white.withOpacity(0.08),
            child: Row(
              children: [
                Icon(
                  Icons.terminal,
                  color: Colors.blueAccent.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: GoogleFonts.shareTechMono(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "COMMAND...",
                      hintStyle: GoogleFonts.shareTechMono(
                        color: Colors.white30,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: _handleUserCommand,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _state == AssistantState.listening
                        ? Icons.mic
                        : Icons.mic_none,
                    color: _state == AssistantState.listening
                        ? Colors.redAccent
                        : Colors.white54,
                  ),
                  onPressed: _handleOrbTap,
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: () => _handleUserCommand(_textController.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Reuse Particle Background from previous step (included here for completeness)
class ParticlePainter extends CustomPainter {
  final Animation<double> animation;
  final List<Particle> particles = [];
  final Random random = Random();

  ParticlePainter(this.animation) : super(repaint: animation) {
    for (int i = 0; i < 40; i++) {
      particles.add(Particle(random));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var particle in particles) {
      particle.update(size.width, size.height);
      paint.color = Colors.blueAccent.withOpacity(
        particle.opacity,
      ); // Blue particles
      canvas.drawCircle(Offset(particle.x, particle.y), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Particle {
  double x = 0;
  double y = 0;
  double speedX = 0;
  double speedY = 0;
  double size = 0;
  double opacity = 0;

  Particle(Random random) {
    reset(random, 400, 800);
  }

  void reset(Random random, double w, double h) {
    x = random.nextDouble() * w;
    y = random.nextDouble() * h;
    speedX = (random.nextDouble() - 0.5) * 0.3;
    speedY = (random.nextDouble() - 0.5) * 0.3;
    size = random.nextDouble() * 2 + 1;
    opacity = random.nextDouble() * 0.2 + 0.05;
  }

  void update(double w, double h) {
    x += speedX;
    y += speedY;
    if (x < 0) x = w;
    if (x > w) x = 0;
    if (y < 0) y = h;
    if (y > h) y = 0;
  }
}

class Random {
  double nextDouble() => math.Random().nextDouble();
}
