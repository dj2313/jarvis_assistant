import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

class RichMessageCard extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool shouldAnimate;

  const RichMessageCard({
    super.key,
    required this.text,
    required this.isUser,
    this.shouldAnimate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser
                ? const Radius.circular(20)
                : const Radius.circular(5),
            bottomRight: isUser
                ? const Radius.circular(5)
                : const Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.blue.withOpacity(0.2)
                    : const Color(0xFF1E1E1E).withOpacity(0.8),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Friday",
                          style: GoogleFonts.orbitron(
                            color: Colors.blueAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildContent(context),
                  if (!isUser) SizedBox(height: 4), // Spacing for visuals
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isUser) {
      return Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 15,
          height: 1.4,
        ),
      );
    }

    // Markdown for Assistant
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.inter(
          color: Colors.white.withOpacity(0.9),
          fontSize: 15,
          height: 1.5,
        ),
        strong: GoogleFonts.inter(
          color: Colors.cyanAccent,
          fontWeight: FontWeight.bold,
        ),
        code: GoogleFonts.shareTechMono(
          backgroundColor: Colors.black54,
          color: Colors.greenAccent,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        blockquote: GoogleFonts.inter(
          color: Colors.white60,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: Colors.cyanAccent, width: 4)),
        ),
      ),
    );
  }
}
