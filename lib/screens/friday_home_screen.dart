import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/friday_orb.dart';
import '../services/voice_service.dart';
import '../agent/friday_orchestrator.dart';
import '../agent/agent_models.dart';
import '../security/permission_guard.dart';
import '../widgets/rich_message_card.dart';
import '../widgets/ambient_idle_overlay.dart';
import 'routines_screen.dart';

// Enhanced Chat Message Model
class ChatMessage {
  final String text;
  final String? thought;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser, this.thought});
}

class FridayHomeScreen extends StatefulWidget {
  const FridayHomeScreen({super.key});

  @override
  State<FridayHomeScreen> createState() => _FridayHomeScreenState();
}

class _FridayHomeScreenState extends State<FridayHomeScreen>
    with TickerProviderStateMixin, AmbientIdleMixin {
  AssistantState _state = AssistantState.idle;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  double _soundLevel = 0.0;
  String? _currentThoughtLine;
  bool _hasInteracted = false; // Track if chat should be shown

  final VoiceService _voiceService = VoiceService();
  final FridayOrchestrator _orchestrator = FridayOrchestrator();
  StreamSubscription<double>? _amplitudeSub;
  StreamSubscription<AgentState>? _orchestratorStateSub;
  StreamSubscription<PendingConfirmation>? _confirmationSub;

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
    _orchestratorStateSub?.cancel();
    _confirmationSub?.cancel();
    _orchestrator.dispose();
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
    if (hour < 12) return "Good morning, Sir. J.A.R.V.I.S. at your service.";
    if (hour < 17) return "Good afternoon, Sir. All systems are online.";
    return "Good evening, Sir. How may I assist you?";
  }

  Future<void> _initializeHistory() async {
    final greeting = _getTimeBasedGreeting();

    setState(() {
      _messages.add(ChatMessage(text: greeting, isUser: false));
    });

    // Speak the greeting
    await _voiceService.speak(greeting);

    // Initializing history silently
    await _orchestrator.brainService.initializeHistory();

    // Subscribe to orchestrator state changes
    _orchestratorStateSub = _orchestrator.stateStream.listen((agentState) {
      if (!mounted) return;
      _mapOrchestratorStateToUI(agentState);
    });

    // Subscribe to tool approval requests
    _confirmationSub = _orchestrator.confirmationStream.listen((confirmation) {
      if (!mounted) return;
      _showApprovalSheet(confirmation);
    });
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
      // Stop recording — Whisper transcribes and returns text
      final text = await _voiceService.stopListening();
      if (mounted && text.isNotEmpty) {
        setState(() {
          _soundLevel = 0.0;
        });
        _handleUserCommand(text);
      } else if (mounted) {
        setState(() {
          _state = AssistantState.idle;
          _soundLevel = 0.0;
        });
      }
    } else if (_state == AssistantState.thinking) {
      setState(() {
        _state = AssistantState.idle;
      });
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _state = AssistantState.listening;
      _hasInteracted = true;
    });
    try {
      await _voiceService.startListening(
        onResult: (text) {
          // Whisper transcription complete — send to orchestrator
          if (mounted && text.isNotEmpty) {
            setState(() {
              _soundLevel = 0.0;
            });
            _handleUserCommand(text);
          } else if (mounted) {
            setState(() {
              _state = AssistantState.idle;
              _soundLevel = 0.0;
            });
          }
        },
        onStatus: (status) {
          if (status == 'notListening' && mounted) {
            if (_state == AssistantState.listening) {
              setState(() {
                _state = AssistantState.idle;
                _soundLevel = 0.0;
              });
            }
          }
        },
        onSoundLevel: (level) {
          if (mounted && _state == AssistantState.listening) {
            setState(() => _soundLevel = level.clamp(0.0, 1.0));
          }
        },
      );
    } catch (e) {
      setState(() => _state = AssistantState.idle);
    }
  }

  Future<void> _handleUserCommand(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _hasInteracted = true;
      _messages.add(ChatMessage(text: text, isUser: true));
      _textController.clear();
      _state = AssistantState.thinking;
      _currentThoughtLine = "Processing request...";
    });
    _playSound('processing');
    _scrollToBottom();
    // JARVIS brief acknowledgement before task execution
    await _voiceService.speakAcknowledgement();
    if (!mounted) return;
    await _processCommand(text);
  }

  Future<void> _processCommand(String text) async {
    final AgentResponse response = await _orchestrator.processRequest(text);

    if (!mounted) return;

    setState(() {
      _currentThoughtLine = null;
      _state = AssistantState.speaking;
      _messages.add(
        ChatMessage(
          text: response.text,
          thought: response.thought,
          isUser: false,
        ),
      );
    });
    _playSound('response');
    _scrollToBottom();
    await _voiceService.speak(response.text, isTaskAck: true);
    if (mounted) {
      setState(() => _state = AssistantState.idle);
    }
  }

  void _mapOrchestratorStateToUI(AgentState agentState) {
    if (!mounted) return;
    setState(() {
      switch (agentState) {
        case AgentState.received:
        case AgentState.classifying:
          _state = AssistantState.thinking;
          _currentThoughtLine = "Analyzing request...";
          break;
        case AgentState.collectingContext:
          _state = AssistantState.thinking;
          _currentThoughtLine = "Gathering context...";
          break;
        case AgentState.retrievingMemory:
          _state = AssistantState.searchingMemory;
          _currentThoughtLine = "Accessing memory banks...";
          break;
        case AgentState.planning:
          _state = AssistantState.thinking;
          _currentThoughtLine = "Formulating response...";
          break;
        case AgentState.waitingForConfirmation:
          _state = AssistantState.thinking;
          _currentThoughtLine = "Awaiting confirmation, Sir...";
          break;
        case AgentState.executing:
          _state = AssistantState.searchingWeb;
          _currentThoughtLine = "Executing task...";
          break;
        case AgentState.verifying:
          _state = AssistantState.synthesizing;
          _currentThoughtLine = "Verifying results...";
          break;
        case AgentState.completed:
          _currentThoughtLine = null;
          break;
        case AgentState.failed:
          _state = AssistantState.idle;
          _currentThoughtLine = "Processing Failed";
          break;
        case AgentState.cancelled:
          _state = AssistantState.idle;
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

  Future<void> _showApprovalSheet(PendingConfirmation confirmation) async {
    HapticFeedback.mediumImpact();

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1A1A).withOpacity(0.95),
                const Color(0xFF0E0E0E).withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tool Approval Required',
                textAlign: TextAlign.center,
                style: GoogleFonts.exo2(
                  color: const Color(0xFFFFB347),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                confirmation.decision.riskLevel.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.rajdhani(
                  color: Colors.orangeAccent,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              _buildApprovalRow('Action', confirmation.toolName),
              const SizedBox(height: 10),
              _buildApprovalArgs(confirmation.args),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildApprovalButton(
                      label: 'CANCEL',
                      color: Colors.redAccent,
                      onTap: () {
                        _orchestrator.cancelConfirmation(confirmation.token);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildApprovalButton(
                      label: 'APPROVE',
                      color: Colors.greenAccent,
                      onTap: () {
                        _orchestrator.approveConfirmation(confirmation.token);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApprovalRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.rajdhani(
              color: Colors.white38,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.rajdhani(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalArgs(Map<String, dynamic> args) {
    if (args.isEmpty) {
      return Text(
        'No additional parameters',
        style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 13),
      );
    }

    final entries = args.entries.map((e) => '${e.key}: ${e.value}').join('\n');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        entries,
        style: GoogleFonts.rajdhani(
          color: Colors.white70,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildApprovalButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: GoogleFonts.exo2(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  // --- UI Layout ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // 1. Particle Background
          Positioned.fill(
            child: CustomPaint(painter: ParticlePainter(_particleController)),
          ),

          // 2. Waveform Visualizer (Behind everything at bottom)
          if (_state == AssistantState.speaking ||
              _state == AssistantState.listening)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: CustomPaint(
                painter: WaveformPainter(
                  amplitude: _soundLevel,
                  color: _state == AssistantState.listening
                      ? const Color(0xFFFF9500)
                      : const Color(0xFFFFB347),
                ),
              ),
            ),

          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  // 3. Navbar with System Status Icons
                  StreamBuilder<int>(
                    stream: _orchestrator.brainService.memoryCountStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return RepaintBoundary(child: _buildNeuralHeader(count));
                    },
                  ),

                  // 4. Main Content Area (Orb + Chat)
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
                            width: _hasInteracted
                                ? 100
                                : 280, // Smaller when chatting
                            height: _hasInteracted ? 100 : 280,
                            child: FridayOrb(
                              state: _state,
                              soundLevel: _soundLevel,
                              onTap: _handleOrbTap,
                            ),
                          ),
                        ),

                        // Chat Overlay
                        if (_hasInteracted && _messages.isNotEmpty)
                          Positioned.fill(
                            top: 110, // Adjusted for smaller orb
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
                                  horizontal: 10,
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

                  // 5. Floating Command Bar
                  _buildFloatingCommandBar(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // 6. Ambient Screensaver Overlay (From Mixin)
          Positioned.fill(child: buildAmbientOverlay()),
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
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "J.A.R.V.I.S.",
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.orbitron(
                    color: const Color(0xFFFF9500),
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
                        color: const Color(0xFFFFB347),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9500).withOpacity(0.5),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "SYSTEMS: ONLINE",
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.shareTechMono(
                          color: const Color(0xFFFFB347).withOpacity(0.8),
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
          Expanded(
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
                        color: const Color(0xFFFF9500).withOpacity(0.05),
                        border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9500).withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.storage,
                            size: 14,
                            color: const Color(0xFFFF9500).withOpacity(0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$memoryCount NODES",
                            style: GoogleFonts.shareTechMono(
                              color: const Color(0xFFFFB347),
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

        final result = await _orchestrator.brainService.checkProactiveStatus();

        if (!mounted) return;

        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Status protocol: NOMINAL (green) / SENTINEL_OFFLINE (amber —
        // transient, nothing scary) / anything else = proactive alert
        // (orange). Red is reserved for genuine misconfiguration.
        final bool isNominal = result.contains("NOMINAL");
        final bool isOffline = result.contains("SENTINEL_OFFLINE");
        final bool isMisconfigured = result.contains("API_KEY");

        final String label;
        final Color color;
        if (isNominal) {
          label = "✓ NOMINAL";
          color = Colors.green.withOpacity(0.8);
        } else if (isMisconfigured) {
          label = "⚠ CONFIG ERROR — set GROQ_API_KEY";
          color = Colors.red.withOpacity(0.8);
        } else if (isOffline) {
          label = "◐ SENTINEL OFFLINE — retry shortly";
          color = Colors.orangeAccent.withOpacity(0.8);
        } else {
          label = "🔔 ALERT SENT";
          color = Colors.orange.withOpacity(0.8);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              label,
              style: GoogleFonts.shareTechMono(color: Colors.white),
            ),
            backgroundColor: color,
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
            colors: [const Color(0xFFFF9500).withOpacity(0.5), Colors.transparent],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SYSTEM DIAGNOSTIC",
                  style: GoogleFonts.orbitron(
                    color: const Color(0xFFFFB347),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Divider(color: Color(0xFFFF9500)),
                const SizedBox(height: 20),

                _buildDiagnosticRow("Status", "ONLINE", const Color(0xFFFFB347)),
                _buildDiagnosticRow("Core Nodes", "$memoryCount", Colors.white),
                _buildDiagnosticRow("Cycle", "ACTIVE", const Color(0xFFFF9500)),
                _buildDiagnosticRow("Sentinel", "ARMED", const Color(0xFFFF6F00)),

                const Spacer(),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "CLOSE DIAGNOSTIC",
                      style: GoogleFonts.shareTechMono(
                        color: const Color(0xFFFFB347),
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

  // --- Ambient Mode Overrides ---
  @override
  String? get ambientWeather => "24°C Clear"; // Placeholder or fetch from Brain
  @override
  String? get ambientNextEvent => "Meeting 5:00 PM"; // Placeholder
  @override
  int? get ambientMemoryCount => 42; // Placeholder or use _brainService

  Widget _buildMenuOptions() {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        resetIdleTimer(); // User interaction
        if (value == 'routines') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RoutinesScreen()),
          );
        } else if (value == 'delete_history') {
          await _orchestrator.brainService.clearHistory();
          setState(() {
            _messages.clear();
            _messages.add(
              ChatMessage(text: "Memory banks purged, Sir.", isUser: false),
            );
          });
        } else if (value == 'reset_limits') {
          final stats = _orchestrator.brainService.resetDailyLimits();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Limits reset — ${stats['chats_remaining']} chats, "
                  "${(stats['tokens_remaining'] / 1000).toStringAsFixed(1)}k "
                  "tokens remaining, Sir.",
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (value == 'logout') {
          // Implement logout logic here
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Logging out..."),
              duration: Duration(seconds: 1),
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      color: const Color(0xFF1E1E1E),
      icon: const Icon(Icons.more_vert, color: Color(0xFFFF9500), size: 20),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'routines',
          child: Row(
            children: [
              const Icon(
                Icons.auto_fix_high,
                color: Color(0xFFFFB347),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                "Automation Hub",
                style: GoogleFonts.shareTechMono(color: Colors.white),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete_history',
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                "Purge Memory",
                style: GoogleFonts.shareTechMono(color: Colors.white),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'reset_limits',
          child: Row(
            children: [
              const Icon(
                Icons.restart_alt,
                color: Color(0xFFFFB347),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                "Reset Daily Limits",
                style: GoogleFonts.shareTechMono(color: Colors.white),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, color: Colors.white, size: 18),
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
      padding: const EdgeInsets.only(top: 10, bottom: 80),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return RichMessageCard(
          text: msg.text,
          isUser: msg.isUser,
          shouldAnimate: index == _messages.length - 1,
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
      },
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
            colors: [const Color(0xFFFF9500).withOpacity(0.5), Colors.transparent],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: const Color(0xFFFF9500),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _currentThoughtLine ?? "Processing...",
                style: GoogleFonts.shareTechMono(
                  color: const Color(0xFFFFB347),
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
                  color: const Color(0xFFFF9500).withOpacity(0.7),
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
                    onSubmitted: (text) {
                      resetIdleTimer();
                      _handleUserCommand(text);
                    },
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
                  icon: const Icon(Icons.send, color: Color(0xFFFF9500)),
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
      paint.color = const Color(0xFFFF9500).withOpacity(
        particle.opacity,
      ); // Amber particles
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

class WaveformPainter extends CustomPainter {
  final double amplitude;
  final Color color;

  WaveformPainter({required this.amplitude, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    final midY = size.height / 2;
    final width = size.width;

    path.moveTo(0, midY);

    for (double i = 0; i <= width; i += 5) {
      final x = i;
      // Simple sine wave modulation based on max amplitude
      final normalizedAmp = amplitude.clamp(0.0, 1.0);
      final waveHeight =
          50 * normalizedAmp * math.sin((i / width) * 2 * math.pi * 5);
      path.lineTo(x, midY + waveHeight);
    }

    canvas.drawPath(path, paint);

    // Mirror
    final paintFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.2),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, width, size.height), paintFill);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.amplitude != amplitude || oldDelegate.color != color;
  }
}
