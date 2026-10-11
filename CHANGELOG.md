# Changelog

All notable changes to Friday Assistant are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]
### Fixed
- Chat: interpolate current time/date into system prompt (no more raw `{{current_time}}`).
- Chat: remove double-wrapping of orchestrator-enriched messages.
- Chat: simplify `_manageHistory` to avoid orphaned tool messages.
- Chat: conservative `ResponseSanitizer` (only strips leading think blocks).
- GPS: 30s timeout + last-known-position fallback in `LocationService`.
- GPS: `action=navigate` + `google.navigation:` intent fallback in `NavigationTool`.
- GPS: share single `LocationService` instance across tools.

## [1.0.0] - 2026-10-07
### Added
- Voice-activated chat (Groq LLM + Whisper STT + flutter_tts).
- Long-term vector memory (Supabase pgvector + HF embeddings + Memory Auditor).
- Real-time web search (Tavily), weather (Open-Meteo), GPS navigation.
- 10-agent tool system with risk-based approval flow.
- Proactive Sentinel background nudges (Workmanager + notifications).
- Holographic Flutter UI (orb, particles, glassmorphism).
- CI workflow (`flutter analyze` + `flutter test`).
