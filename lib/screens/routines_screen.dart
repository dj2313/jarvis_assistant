import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/routine.dart';
import '../services/routine_service.dart';

/// Routines Screen - Manage automation workflows
/// Uses lazy loading for list items and efficient state management

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  final RoutineService _routineService = RoutineService();
  List<Routine>? _routines;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final routines = await _routineService.getRoutines();
      if (mounted) {
        setState(() {
          _routines = routines;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load routines';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runRoutine(Routine routine) async {
    HapticFeedback.mediumImpact();

    // Show running dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RoutineRunningDialog(
        routine: routine,
        routineService: _routineService,
      ),
    );
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteConfirmDialog(routineName: routine.name),
    );

    if (confirmed == true && routine.id != null) {
      HapticFeedback.heavyImpact();
      await _routineService.deleteRoutine(routine.id!);
      _loadRoutines();
    }
  }

  void _showAddRoutineSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddRoutineSheet(
        onRoutineCreated: (routine) {
          _routineService.createRoutine(routine);
          _loadRoutines();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 1.5,
                  colors: [Colors.blue.withOpacity(0.08), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Content
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AUTOMATION HUB',
                  style: GoogleFonts.orbitron(
                    color: Colors.cyanAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '${_routines?.length ?? 0} routines configured',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Refresh button
          GestureDetector(
            onTap: _loadRoutines,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyan.withOpacity(0.3)),
              ),
              child: Icon(
                Icons.refresh,
                color: Colors.cyanAccent.withOpacity(0.8),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: GoogleFonts.inter(color: Colors.white70)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadRoutines,
              child: Text(
                'Retry',
                style: GoogleFonts.shareTechMono(color: Colors.cyanAccent),
              ),
            ),
          ],
        ),
      );
    }

    if (_routines == null || _routines!.isEmpty) {
      return _buildEmptyState();
    }

    return _buildRoutinesList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.cyanAccent,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Routines Yet',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create automated workflows to\nlet Friday handle tasks for you',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),

          // Preset suggestions
          Text(
            'QUICK START',
            style: GoogleFonts.shareTechMono(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          ...RoutinePresets.presets.map((preset) => _buildPresetCard(preset)),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildPresetCard(Routine preset) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        await _routineService.createRoutine(preset);
        _loadRoutines();
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                preset.actions.isNotEmpty ? preset.actions.first.icon : '⚡',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${preset.actions.length} actions',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.add_circle_outline,
              color: Colors.cyanAccent,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutinesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _routines!.length,
      // Lazy loading - only build visible items
      itemBuilder: (context, index) {
        final routine = _routines![index];
        return _RoutineCard(
              key: ValueKey(routine.id),
              routine: routine,
              onRun: () => _runRoutine(routine),
              onDelete: () => _deleteRoutine(routine),
              onToggle: (enabled) {
                if (routine.id != null) {
                  _routineService.toggleRoutine(routine.id!, enabled);
                }
              },
            )
            .animate(delay: Duration(milliseconds: index * 80))
            .fadeIn(duration: 400.ms)
            .slideX(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
          onPressed: _showAddRoutineSheet,
          backgroundColor: Colors.cyanAccent,
          icon: const Icon(Icons.add, color: Colors.black),
          label: Text(
            'NEW ROUTINE',
            style: GoogleFonts.shareTechMono(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 300.ms)
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }
}

// ============================================================================
// ROUTINE CARD WIDGET
// ============================================================================

class _RoutineCard extends StatelessWidget {
  final Routine routine;
  final VoidCallback onRun;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _RoutineCard({
    super.key,
    required this.routine,
    required this.onRun,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(routine.isEnabled ? 0.08 : 0.03),
              Colors.white.withOpacity(routine.isEnabled ? 0.02 : 0.01),
            ],
          ),
          border: Border.all(
            color: routine.isEnabled
                ? Colors.cyan.withOpacity(0.3)
                : Colors.white12,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: routine.isEnabled
                              ? Colors.cyan.withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          routine.actions.isNotEmpty
                              ? routine.actions.first.icon
                              : '⚡',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Title & trigger
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routine.name,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  routine.triggerIcon,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  routine.triggerLabel,
                                  style: GoogleFonts.shareTechMono(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Toggle
                      Switch(
                        value: routine.isEnabled,
                        onChanged: onToggle,
                        activeColor: Colors.cyanAccent,
                        activeTrackColor: Colors.cyan.withOpacity(0.3),
                      ),
                    ],
                  ),

                  // Description
                  if (routine.description != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      routine.description!,
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Actions preview
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: routine.actions.take(4).map((action) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${action.icon} ${action.label}',
                          style: GoogleFonts.shareTechMono(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Action buttons
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Run button
                      Expanded(
                        child: GestureDetector(
                          onTap: routine.isEnabled ? onRun : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: routine.isEnabled
                                  ? Colors.cyan.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: routine.isEnabled
                                    ? Colors.cyan.withOpacity(0.4)
                                    : Colors.white12,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_arrow,
                                  size: 18,
                                  color: routine.isEnabled
                                      ? Colors.cyanAccent
                                      : Colors.white38,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'RUN NOW',
                                  style: GoogleFonts.shareTechMono(
                                    color: routine.isEnabled
                                        ? Colors.cyanAccent
                                        : Colors.white38,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Delete button
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ROUTINE RUNNING DIALOG
// ============================================================================

class _RoutineRunningDialog extends StatefulWidget {
  final Routine routine;
  final RoutineService routineService;

  const _RoutineRunningDialog({
    required this.routine,
    required this.routineService,
  });

  @override
  State<_RoutineRunningDialog> createState() => _RoutineRunningDialogState();
}

class _RoutineRunningDialogState extends State<_RoutineRunningDialog> {
  String? _result;
  bool _isRunning = true;

  @override
  void initState() {
    super.initState();
    _runRoutine();
  }

  Future<void> _runRoutine() async {
    final result = await widget.routineService.executeRoutine(widget.routine);
    if (mounted) {
      setState(() {
        _result = result;
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.cyan.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isRunning
                            ? Colors.cyan.withOpacity(0.2)
                            : Colors.green.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: _isRunning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.cyanAccent,
                              ),
                            )
                          : const Icon(
                              Icons.check,
                              color: Colors.greenAccent,
                              size: 20,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isRunning ? 'EXECUTING' : 'COMPLETE',
                            style: GoogleFonts.shareTechMono(
                              color: Colors.white54,
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            widget.routine.name,
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_isRunning) ...[
                  const SizedBox(height: 24),
                  // Progress indicator
                  ValueListenableBuilder<int>(
                    valueListenable: widget.routineService.currentActionIndex,
                    builder: (context, index, _) {
                      final action = widget.routine.actions[index];
                      return Column(
                        children: [
                          Text(
                            '${action.icon} ${action.label}',
                            style: GoogleFonts.shareTechMono(
                              color: Colors.cyanAccent,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (index + 1) / widget.routine.actions.length,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.cyanAccent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Step ${index + 1} of ${widget.routine.actions.length}',
                            style: GoogleFonts.shareTechMono(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  // Results
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: Text(
                        _result ?? 'No results',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.cyan.withOpacity(0.5)),
                        ),
                      ),
                      child: Text(
                        'CLOSE',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DELETE CONFIRM DIALOG
// ============================================================================

class _DeleteConfirmDialog extends StatelessWidget {
  final String routineName;

  const _DeleteConfirmDialog({required this.routineName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.red.withOpacity(0.3)),
      ),
      title: Text(
        'Delete Routine?',
        style: GoogleFonts.orbitron(color: Colors.white, fontSize: 16),
      ),
      content: Text(
        'This will permanently delete "$routineName". This action cannot be undone.',
        style: GoogleFonts.inter(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.shareTechMono(color: Colors.white54),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Delete',
            style: GoogleFonts.shareTechMono(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ADD ROUTINE BOTTOM SHEET
// ============================================================================

class _AddRoutineSheet extends StatefulWidget {
  final ValueChanged<Routine> onRoutineCreated;

  const _AddRoutineSheet({required this.onRoutineCreated});

  @override
  State<_AddRoutineSheet> createState() => _AddRoutineSheetState();
}

class _AddRoutineSheetState extends State<_AddRoutineSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedTrigger = 'manual';
  TimeOfDay? _selectedTime;
  final List<RoutineAction> _actions = [];

  final List<Map<String, dynamic>> _availableActions = [
    {'type': 'weather', 'label': 'Check Weather', 'icon': '🌤️'},
    {'type': 'news', 'label': 'Read Top News', 'icon': '📰'},
    {'type': 'calendar', 'label': 'Check Calendar', 'icon': '📅'},
    {'type': 'email', 'label': 'Summarize Emails', 'icon': '📧'},
    {'type': 'focus', 'label': 'Enable Focus Mode', 'icon': '🎯'},
    {'type': 'speak', 'label': 'Speak Message', 'icon': '🗣️'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _addAction(Map<String, dynamic> actionData) {
    setState(() {
      _actions.add(
        RoutineAction(
          type: actionData['type'] as String,
          label: actionData['label'] as String,
        ),
      );
    });
    HapticFeedback.selectionClick();
  }

  void _removeAction(int index) {
    setState(() => _actions.removeAt(index));
    HapticFeedback.lightImpact();
  }

  void _createRoutine() {
    if (_nameController.text.isEmpty || _actions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add a name and at least one action',
            style: GoogleFonts.shareTechMono(color: Colors.white),
          ),
          backgroundColor: Colors.red.withOpacity(0.8),
        ),
      );
      return;
    }

    final routine = Routine(
      name: _nameController.text,
      description: _descController.text.isNotEmpty
          ? _descController.text
          : null,
      trigger: _selectedTrigger,
      triggerConfig: _selectedTrigger == 'time' && _selectedTime != null
          ? {
              'time':
                  '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
            }
          : {},
      actions: _actions,
    );

    widget.onRoutineCreated(routine);
    Navigator.pop(context);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'CREATE ROUTINE',
                  style: GoogleFonts.orbitron(
                    color: Colors.cyanAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _createRoutine,
                  child: Text(
                    'SAVE',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name field
                  _buildTextField(
                    controller: _nameController,
                    label: 'Routine Name',
                    hint: 'e.g., Morning Briefing',
                  ),
                  const SizedBox(height: 16),

                  // Description field
                  _buildTextField(
                    controller: _descController,
                    label: 'Description (optional)',
                    hint: 'What does this routine do?',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // Trigger selection
                  Text(
                    'TRIGGER',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTriggerChip('manual', '👆 Manual'),
                      const SizedBox(width: 8),
                      _buildTriggerChip('time', '⏰ Scheduled'),
                    ],
                  ),

                  if (_selectedTrigger == 'time') ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() => _selectedTime = time);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _selectedTime != null
                                  ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                  : 'Select Time',
                              style: GoogleFonts.shareTechMono(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Actions
                  Text(
                    'ACTIONS',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Added actions
                  if (_actions.isNotEmpty) ...[
                    ..._actions.asMap().entries.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.cyan.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              entry.value.icon,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value.label,
                                style: GoogleFonts.inter(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white54,
                              ),
                              onPressed: () => _removeAction(entry.key),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // Available actions
                  Text(
                    'ADD ACTIONS',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableActions.map((action) {
                      return GestureDetector(
                        onTap: () => _addAction(action),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(action['icon'] as String),
                              const SizedBox(width: 6),
                              Text(
                                action['label'] as String,
                                style: GoogleFonts.shareTechMono(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.shareTechMono(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTriggerChip(String value, String label) {
    final isSelected = _selectedTrigger == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTrigger = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyan.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.cyanAccent.withOpacity(0.5)
                : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.shareTechMono(
            color: isSelected ? Colors.cyanAccent : Colors.white54,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
