/// Removes model-internal reasoning and pseudo tool-call markup before text is
/// stored, displayed, or spoken to the user.
class ResponseSanitizer {
  // Qwen thinking delimiters: "<think> ... </?>" (and "</think>") — used by
  // the Qwen reasoning models. These blocks are model-internal reasoning and
  // are never legitimate user-facing content, so they are stripped anywhere.
  static final RegExp _qwenThinkSection = RegExp(
    r'\s*<[ \t]*think[ \t]*>[\s\S]*?(?:</[ \t]*\?>|</[ \t]*think[ \t]*>)\s*',
    caseSensitive: false,
  );
  // Fallback: remove any stray Qwen delimiters left behind.
  static final RegExp _qwenDelimiter = RegExp(
    r'</[ \t]*\?>|<[ \t]*\?[ \t]*>',
    caseSensitive: false,
  );
  static final RegExp _functionBlock = RegExp(
    r'<\s*function\b[^>]*>[\s\S]*?<\s*/\s*function\s*>',
    caseSensitive: false,
  );
  static final RegExp _functionTag = RegExp(
    r'<\s*/?\s*function\b[^>]*>?',
    caseSensitive: false,
  );
  static final RegExp _toolCallBlock = RegExp(
    r'<\s*tool_call\b[^>]*>[\s\S]*?<\s*/\s*tool_call\s*>',
    caseSensitive: false,
  );
  static final RegExp _toolCallTag = RegExp(
    r'<\s*/?\s*tool_call\b[^>]*>?',
    caseSensitive: false,
  );

  static String clean(String content) {
    var result = content.trim();

    // Only strip leading standard think blocks (model reasoning leaked
    // into output). Qwen sections are handled separately below.
    result = result.replaceFirst(
      RegExp(
        r'^\s*<\s*think\b[^>]*>[\s\S]*?<\s*/\s*think\s*>\s*',
        caseSensitive: false,
      ),
      '',
    );

    // Strip Qwen thinking sections anywhere: "<think> ... </?>" blocks are
    // model-internal reasoning, never legitimate user-facing content.
    result = result
        .replaceAll(_qwenThinkSection, '')
        .replaceAll(_qwenDelimiter, '');

    // Strip tool-call markup anywhere in the text
    result = result
        .replaceAll(_functionBlock, '')
        .replaceAll(_toolCallBlock, '')
        .replaceAll(_functionTag, '')
        .replaceAll(_toolCallTag, '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return result;
  }

  static String extractThought(String content) {
    final thoughts = RegExp(
      r'<\s*think\b[^>]*>([\s\S]*?)<\s*/\s*think\s*>',
      caseSensitive: false,
    ).allMatches(content).map((match) => match.group(1)?.trim() ?? '');
    return thoughts.where((thought) => thought.isNotEmpty).join('\n').trim();
  }

  const ResponseSanitizer._();
}
