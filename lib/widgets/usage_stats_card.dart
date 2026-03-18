import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';

class UsageStatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool isServiceAvailable;

  const UsageStatsCard({
    super.key,
    required this.stats,
    required this.isServiceAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final chatsUsed = stats['chats_used'] ?? 0;
    final chatsLimit = stats['daily_chat_limit'] ?? 5;
    final tokensUsed = stats['tokens_used'] ?? 0;
    final tokensLimit = stats['daily_token_limit'] ?? 5000;

    final chatPercentage = (chatsUsed / chatsLimit) * 100;
    final tokenPercentage = (tokensUsed / tokensLimit) * 100;

    return GlassmorphicContainer(
      width: double.infinity,
      height: 140,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.cyan.withOpacity(0.1),
          Colors.blue.withOpacity(0.1),
        ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.cyan.withOpacity(0.5),
          Colors.blue.withOpacity(0.5),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Neural Link Status',
                  style: GoogleFonts.orbitron(
                    color: Colors.cyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  isServiceAvailable ? Icons.check_circle : Icons.warning,
                  color: isServiceAvailable ? Colors.green : Colors.orange,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Chat Usage
            _buildUsageBar(
              'Chats Used',
              chatsUsed,
              chatsLimit,
              chatPercentage,
              Icons.chat_bubble_outline,
            ),
            const SizedBox(height: 10),
            // Token Usage
            _buildUsageBar(
              'Tokens Used',
              tokensUsed,
              tokensLimit,
              tokenPercentage,
              Icons.memory,
            ),
            const SizedBox(height: 8),
            // Reset time info
            Row(
              children: [
                Icon(Icons.schedule, size: 12, color: Colors.cyan.withOpacity(0.7)),
                const SizedBox(width: 6),
                Text(
                  'Resets at midnight',
                  style: GoogleFonts.robotoMono(
                    color: Colors.cyan.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageBar(
    String label,
    int used,
    int limit,
    double percentage,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: Colors.cyan),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.roboto(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Text(
              '$used / $limit',
              style: GoogleFonts.robotoMono(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage / 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyan,
                    Colors.blue,
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}