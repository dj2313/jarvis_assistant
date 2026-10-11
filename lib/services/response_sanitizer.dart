/// Removes model-internal reasoning and pseudo tool-call markup before text is
/// stored, displayed, or spoken to the user.
class ResponseSanitizer {
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

    // Only strip leading think blocks (model reasoning that leaked into output)
    result = result.replaceFirst(
      RegExp(
        r'^\s*<\s*think\b[^>]*>[\s\S]*?<\s*/\s*think\s*>\s*',
        caseSensitive: false,
      ),
      '',
    );

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
