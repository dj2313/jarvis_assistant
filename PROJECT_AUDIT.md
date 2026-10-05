# J.A.R.V.I.S. / FRIDAY Assistant — Project Audit

**Date:** 2026-10-05  
**Auditor:** Automated Code Analysis  
**Project Version:** 1.0.0+1  
**Status:** Active Development

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Tech Stack](#2-tech-stack)
3. [Architecture](#3-architecture)
4. [File Inventory](#4-file-inventory)
5. [Core Services](#5-core-services)
6. [Tool System](#6-tool-system)
7. [Security & Permissions](#7-security--permissions)
8. [Configuration & Environment](#8-configuration--environment)
9. [Dependencies](#9-dependencies)
10. [Known Issues & Fixes Applied](#10-known-issues--fixes-applied)
11. [Code Quality Assessment](#11-code-quality-assessment)
12. [Recommendations](#12-recommendations)

---

## 1. Project Overview

**J.A.R.V.I.S. / FRIDAY** is a Flutter-based, voice-activated personal AI assistant inspired by Tony Stark's AI butler. It features:

- **Voice-first interface** with speech-to-text (Groq Whisper) and text-to-speech (flutter_tts)
- **Long-term memory** via Supabase vector embeddings (HuggingFace all-MiniLM-L6-v2)
- **Real-time web search** via Tavily API
- **Proactive "Sentinel" mode** with background task scheduling (Workmanager)
- **Tool-calling agent** with iterative multi-step execution
- **Sci-fi holographic UI** with glassmorphism, particle effects, and animated orb
- **Multi-platform** support (Android, iOS, Web, Desktop)

### Key Capabilities

| Capability | Implementation |
|------------|---------------|
| Natural language chat | Groq API (openai/gpt-oss-120b / qwen/qwen3.6-27b) |
| Voice input | Groq Whisper large-v3 via VoiceService |
| Voice output | flutter_tts with British male voice selection |
| Web search | Tavily API (advanced search + AI answer synthesis) |
| Memory storage | Supabase PostgreSQL + pgvector |
| Memory retrieval | Supabase RPC `match_memories` with cosine similarity |
| GPS navigation | geolocator + Google Maps URL launcher |
| Weather | Open-Meteo API (free, no key required) |
| App launching | Android intents via url_launcher + MethodChannel |
| Messaging | Deep links (WhatsApp, Telegram, SMS, Email, Instagram) |
| Background tasks | Workmanager + flutter_local_notifications |
| Auth | Supabase email/password with RLS |

---

## 2. Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Framework** | Flutter | SDK ^3.10.4 |
| **Language** | Dart | ^3.10.4 |
| **Backend DB** | Supabase (PostgreSQL + pgvector) | — |
| **Auth** | Supabase Auth | ^2.12.0 |
| **LLM** | Groq API | — |
| **Embeddings** | HuggingFace (all-MiniLM-L6-v2) | — |
| **Web Search** | Tavily API | — |
| **HTTP** | http package | ^1.6.0 |
| **GPS** | geolocator | ^14.0.3 |
| **Voice STT** | Groq Whisper large-v3 | — |
| **Voice TTS** | flutter_tts | ^4.2.3 |
| **Audio Record** | record | ^6.0.0 |
| **Permissions** | permission_handler | ^12.0.1 |
| **State Mgmt** | setState + Streams | — |
| **Animations** | flutter_animate | ^4.5.2 |
| **UI Effects** | glassmorphism | ^3.0.0 |
| **Fonts** | google_fonts | ^6.3.3 |
| **Env Config** | flutter_dotenv | ^6.0.0 |
| **Background** | workmanager | ^0.9.0+3 |
| **Notifications** | flutter_local_notifications | ^17.0.0 |
| **Battery** | battery_plus | ^7.1.1 |
| **Connectivity** | connectivity_plus | ^7.3.1 |
| **URL Launch** | url_launcher | ^6.3.1 |
| **Storage** | shared_preferences | ^2.5.4 |
| **Paths** | path_provider | ^2.1.0 |
| **UUID** | uuid | ^4.5.1 |
| **Markdown** | flutter_markdown | ^0.7.7+1 |

---

## 3. Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     FridayHomeScreen                         │
│  ┌─────────┐  ┌──────────┐  ┌───────────┐  ┌────────────┐  │
│  │  Orb   │  │  Chat    │  │  Command  │  │  Ambient   │  │
│  │  UI     │  │  List    │  │  Bar      │  │  Overlay   │  │
│  └────┬────┘  └────┬─────┘  └─────┬─────┘  └────────────┘  │
│       │            │              │                         │
│       └────────────┴──────────────┘                         │
│                    │                                        │
│              FridayOrchestrator                             │
│  ┌──────────┬───────────┬──────────┬──────────────┐        │
│  │  Intent  │  Context  │  Memory  │  Policy      │        │
│  │  Router  │  Engine   │  Service │  Engine      │        │
│  └────┬─────┴─────┬─────┴────┬─────┴──────┬───────┘        │
│       │           │          │            │                 │
│       └───────────┴──────────┴────────────┘                 │
│                         │                                   │
│              FridayBrainService                             │
│  ┌──────────┬───────────┬──────────┬──────────────┐        │
│  │  Groq   │  Tool     │  Token   │  Response    │        │
│  │  API    │  Executor │  Manager │  Sanitizer   │        │
│  └────┬─────┴─────┬─────┴──────────┴──────────────┘        │
│       │           │                                         │
│  ┌────┴────┐ ┌────┴────────────────────────────────┐       │
│  │ Supabase│ │           Tool Registry              │       │
│  │         │ │  navigate, get_location, get_weather │       │
│  │ chat_   │ │  get_battery, current_time,          │       │
│  │ messages│ │  open_app, send_message, web_search, │       │
│  │ jarvis_ │ │  search_memory, save_memory          │       │
│  │ memory  │ └──────────────────────────────────────┘       │
│  └─────────┘                                                │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **User Input** → Text field or voice (Whisper STT)
2. **Intent Router** → Keyword match (local) or LLM classification (Groq)
3. **Context Engine** → Gathers time, battery, network, location
4. **Memory Service** → Vector search in Supabase for relevant past context
5. **Input Enrichment** → Combines context + memory + intent into enriched prompt
6. **Brain Service** → Sends to Groq with tool definitions
7. **Tool Loop** → Iterative tool execution (up to 6 rounds)
8. **Response Sanitizer** → Strips think blocks and tool markup
9. **UI Update** → Chat message added, TTS speaks response

---

## 4. File Inventory

### Root Configuration
| File | Purpose |
|------|---------|
| `pubspec.yaml` | Flutter dependencies and project config |
| `pubspec.lock` | Locked dependency versions |
| `.env` | API keys and secrets (not in VCS) |
| `.env.example` | Template for environment variables |
| `analysis_options.yaml` | Dart linting rules |
| `.metadata` | Flutter metadata |
| `README.md` | Project documentation |

### lib/ — Main Source (47 files)

#### core/
| File | Lines | Purpose |
|------|-------|---------|
| `config.dart` | 74 | Central configuration, API keys, model names |

#### agent/
| File | Lines | Purpose |
|------|-------|---------|
| `agent_models.dart` | 147 | Core data models (AgentState, ToolResult, IntentResult, etc.) |
| `friday_orchestrator.dart` | 342 | Main orchestrator — routes requests through the pipeline |
| `intent_router.dart` | 318 | Intent classification (keyword + LLM fallback) |
| `context_engine.dart` | 195 | Gathers device context (time, battery, network, location) |
| `result_verifier.dart` | 72 | Post-execution tool result validation |

#### services/
| File | Lines | Purpose |
|------|-------|---------|
| `friday_brain_service.dart` | ~1243 | Core AI service — Groq API, tool loop, history, nudges |
| `fallback_brain_service.dart` | 212 | Ollama local fallback (currently unused) |
| `memory_service.dart` | 190 | Supabase vector memory (save, search, delete) |
| `search_service.dart` | 207 | Tavily web search integration |
| `location_service.dart` | ~80 | GPS location with fallback |
| `auth_service.dart` | 85 | Supabase authentication |
| `token_manager.dart` | 161 | Daily usage limits (100 chats, 50K tokens) |
| `voice_service.dart` | 357 | STT (Whisper) + TTS (flutter_tts) |
| `response_sanitizer.dart` | ~60 | Strips think/tool markup from responses |
| `routine_service.dart` | — | Routine management |
| `vocal_service.dart` | — | Additional vocal processing |

#### tools/
| File | Lines | Purpose |
|------|-------|---------|
| `friday_tool.dart` | 18 | Abstract base class for all tools |
| `tool_registry.dart` | 52 | Tool registration and lookup |
| `tool_executor.dart` | 66 | Tool execution with timeout and validation |
| `tool_bootstrap.dart` | 41 | Factory — creates all tool instances |
| `navigation_tool.dart` | ~120 | GPS navigation via Google Maps |
| `get_location_tool.dart` | 122 | Current GPS position + reverse geocode |
| `weather_tool.dart` | 174 | Open-Meteo weather API |
| `web_search_tool.dart` | 83 | Tavily web search |
| `memory_save_tool.dart` | 83 | Save fact to memory vault |
| `memory_search_tool.dart` | 77 | Search memory vault |
| `current_time_tool.dart` | 114 | Current time/date |
| `battery_tool.dart` | 68 | Battery status |
| `open_app_tool.dart` | 177 | Launch Android apps |
| `send_message_tool.dart` | 224 | Send messages via deep links |

#### screens/
| File | Purpose |
|------|---------|
| `friday_home_screen.dart` | Main chat UI (1267 lines) |
| `auth_screen.dart` | Login/signup |
| `friday_initialization_screen.dart` | Boot sequence |
| `landing_screen.dart` | Landing page |
| `memory_vault_screen.dart` | Memory management |
| `neural_settings_screen.dart` | Settings |
| `routines_screen.dart` | Automation routines |

#### security/
| File | Lines | Purpose |
|------|-------|---------|
| `policy_engine.dart` | 113 | Risk-based tool execution policy |
| `permission_guard.dart` | 139 | Confirmation flow with timeout |
| `action_risk_level.dart` | — | Risk level enum |

#### widgets/
| File | Purpose |
|------|---------|
| `friday_orb.dart` | Animated AI orb |
| `rich_message_card.dart` | Chat message bubbles |
| `holographic_cards.dart` | Glassmorphic cards |
| `usage_stats_card.dart` | Token usage display |
| `approval_sheet.dart` | Tool confirmation UI |
| `ambient_idle_overlay.dart` | Idle screensaver |

---

## 5. Core Services

### 5.1 FridayBrainService (~1243 lines)

The central AI service. Responsibilities:
- **Groq API communication** with retry + exponential backoff (429 handling)
- **Iterative tool-calling loop** (up to 6 rounds)
- **Message history management** (max 20 messages, system prompt preserved)
- **Token usage tracking** via TokenManager
- **Proactive nudge detection** (JSON blob extraction from responses)
- **Multi-tier fallback**: Groq → Gemini → error message

**Key Methods:**
| Method | Purpose |
|--------|---------|
| `chatWithIntelligence()` | Main entry — serializes requests, calls inner |
| `_chatWithIntelligenceInner()` | Tool-calling loop with Groq |
| `_callGroqWithRetry()` | HTTP POST with retry + throttle |
| `_selectModel()` | Fast vs smart model selection |
| `_executeTool()` | Routes to ToolRegistry or legacy fallback |
| `_manageHistory()` | Trims old messages |
| `checkProactiveStatus()` | Sentinel mode analysis |
| `checkAndTriggerNudge()` | Extracts nudge JSON, triggers notification |

### 5.2 FridayOrchestrator (342 lines)

Pipeline orchestrator. Responsibilities:
- Intent routing
- Context collection
- Memory retrieval
- Input enrichment
- Tool approval flow (PolicyEngine + PermissionGuard)
- Result verification

### 5.3 VoiceService (357 lines)

Full voice pipeline:
- **STT**: Records audio → Groq Whisper API → text
- **TTS**: flutter_tts with British male voice selection
- **Visual feedback**: Amplitude stream for orb animation
- **Auto-stop**: 30-second recording limit
- **JARVIS phrasing**: Auto-appends "Sir" to responses

### 5.4 MemoryService (190 lines)

Vector memory system:
- **Embeddings**: HuggingFace all-MiniLM-L6-v2 (384-dim)
- **Storage**: Supabase `jarvis_memory` table with pgvector
- **Retrieval**: Supabase RPC `match_memories` (cosine similarity, threshold 0.4)
- **Conflict detection**: Pre-save audit via LLM

### 5.5 TokenManager (161 lines)

Usage limiting:
- **Daily limits**: 100 chats, 50,000 tokens
- **Persistence**: SharedPreferences
- **Auto-reset**: Midnight daily
- **Estimation**: ~4 chars per token + 100 overhead

---

## 6. Tool System

### Tool Architecture

```
FridayTool (abstract)
├── name, description, riskLevel, inputSchema
├── groqToolDefinition → JSON schema for Groq API
└── execute(args, context) → ToolResult

ToolRegistry
├── register(tool), get(name), toGroqToolList()
└── count, allTools, registeredToolNames

ToolExecutor
├── execute(tool, args, context) → ToolResult
├── _validateArgs(tool, args) → bool
└── defaultTimeout: 30 seconds
```

### Tool Inventory

| Tool | Name | Risk | Description |
|------|------|------|-------------|
| NavigationTool | `navigate` | 1 | Google Maps turn-by-turn navigation |
| GetLocationTool | `get_location` | 0 | GPS coordinates + reverse geocode |
| WeatherTool | `get_weather` | 0 | Open-Meteo weather data |
| WebSearchTool | `web_search` | 0 | Tavily web search |
| MemorySaveTool | `save_memory` | 1 | Save to Supabase memory vault |
| MemorySearchTool | `search_memory` | 0 | Search Supabase memory vault |
| CurrentTimeTool | `current_time` | 0 | Current time/date |
| BatteryTool | `get_battery` | 0 | Battery level and status |
| OpenAppTool | `open_app` | 1 | Launch Android apps |
| SendMessageTool | `send_message` | 3 | Send messages via deep links |

### Risk Levels

| Level | Behavior | Tools |
|-------|----------|-------|
| 0 — ReadOnly | Auto-execute | get_location, get_weather, web_search, search_memory, current_time, get_battery |
| 1 — Reversible | Auto-execute | navigate, save_memory, open_app |
| 2 — Sensitive | Requires confirmation | (default for unknown tools) |
| 3 — Critical | Requires biometric | send_message |

---

## 7. Security & Permissions

### Android Permissions (AndroidManifest.xml)

| Permission | Purpose |
|------------|---------|
| `INTERNET` | API calls |
| `RECORD_AUDIO` | Voice input |
| `BLUETOOTH` / `BLUETOOTH_ADMIN` / `BLUETOOTH_CONNECT` | Bluetooth devices |
| `ACCESS_FINE_LOCATION` | GPS |
| `ACCESS_COARSE_LOCATION` | Approximate location |

### Security Architecture

1. **PolicyEngine** — Evaluates tool risk level, decides auto-execute vs confirmation
2. **PermissionGuard** — Manages confirmation flow with 60-second timeout
3. **Supabase RLS** — Row Level Security on all tables (users can only access own data)
4. **API Keys** — Stored in `.env`, loaded via flutter_dotenv, never hardcoded
5. **Approval Gate** — Tools with riskLevel >= 2 require UI confirmation

### Confirmation Flow

```
Tool Execution Request
       │
       ▼
PolicyEngine.evaluate(tool)
       │
       ├── readOnly/reversible → auto-execute
       │
       └── sensitive/critical → PermissionGuard.createConfirmation()
                                      │
                                      ▼
                              UI Approval Sheet
                              (60s timeout)
                                      │
                               ┌──────┴──────┐
                               │             │
                            Approve        Cancel/Timeout
                               │             │
                               ▼             ▼
                          Execute Tool   Return Failure
```

---

## 8. Configuration & Environment

### Required Environment Variables (.env)

| Variable | Required | Purpose |
|----------|----------|---------|
| `GROQ_API_KEY` | Yes | Groq LLM API access |
| `SUPABASE_URL` | Yes | Supabase project URL |
| `SUPABASE_ANON_KEY` | Yes | Supabase anonymous key |
| `HF_TOKEN` | Yes | HuggingFace embeddings |
| `TAVILY_API_KEY` | Yes | Tavily web search |
| `GEMINI_API_KEY` | No | Gemini fallback LLM |

### Model Configuration (config.dart)

| Setting | Value |
|---------|-------|
| Fast model | `openai/gpt-oss-120b` |
| Smart model | `qwen/qwen3.6-27b` |
| STT model | `whisper-large-v3` |
| Max tokens | 2048 |
| Temperature | 0.1 |

### Supabase Tables

| Table | Purpose |
|-------|---------|
| `chat_messages` | Chat history (role, content) |
| `jarvis_memory` | Vector memory (user_id, content, embedding) |
| `Friday_routines` | Automation routines |

---

## 9. Dependencies

### Production Dependencies (28 packages)

```
flutter SDK
cupertino_icons        ^1.0.8
supabase_flutter       ^2.12.0
http                   ^1.6.0
speech_to_text         ^7.3.0
record                 ^6.0.0
flutter_tts            ^4.2.3
path_provider          ^2.1.0
glassmorphism          ^3.0.0
flutter_dotenv         ^6.0.0
google_fonts           ^6.3.3
permission_handler     ^12.0.1
audioplayers           ^6.5.1
workmanager            ^0.9.0+3
flutter_local_notifications ^17.0.0
flutter_animate         ^4.5.2
flutter_staggered_grid_view ^0.7.0
shared_preferences     ^2.5.4
flutter_markdown       ^0.7.7+1
shimmer                ^3.0.0
uuid                   ^4.5.1
url_launcher           ^6.3.1
battery_plus           ^7.1.1
connectivity_plus       ^7.3.1
geolocator             ^14.0.3
```

### Dev Dependencies

```
flutter_test SDK
flutter_lints          ^6.0.0
flutter_launcher_icons ^0.13.1
```

---

## 10. Known Issues & Fixes Applied

### High Priority Fixes

| ID | Issue | Root Cause | Fix | Status |
|----|-------|-----------|-----|--------|
| H1 | LLM sees `{{current_time}}` | Template placeholder never interpolated | Replaced static const with `_getSystemInstructions()` method | ✅ Fixed |
| H2 | Double-wrapping of user messages | Orchestrator enriches → brain service wraps again | Pass enriched input through directly | ✅ Fixed |
| H3 | GPS timeout too short | 10s timeout for cold GPS fix | Increased to 30s + `getLastKnownPosition()` fallback | ✅ Fixed |
| H4 | No immediate turn-by-turn | Missing `action=navigate` in URL | Added `action=navigate` + `google.navigation:` intent fallback | ✅ Fixed |

### Low Priority Fixes

| ID | Issue | Fix | Status |
|----|-------|-----|--------|
| L1 | Complex `_manageHistory` | Simplified to trim-from-start approach | ✅ Fixed |
| L2 | Over-aggressive sanitizer | Only strip leading think blocks | ✅ Fixed |
| L3 | Multiple LocationService instances | Singleton pattern in `buildDefaultTools()` | ✅ Fixed |
| L4 | No location status helper | Added `getLocationStatus()` method | ✅ Fixed |

### Remaining Known Issues

| Issue | Severity | Description |
|-------|----------|-------------|
| FallbackBrainService unused | Low | Ollama fallback code exists but is not wired into the main flow |
| Hardcoded contacts in SendMessageTool | Low | `_contacts` map has placeholder phone numbers |
| No offline mode | Medium | App requires internet for all AI features |
| Web platform limitations | Medium | Voice, GPS, and app launching don't work on web |
| No unit tests | Medium | Only `widget_test.dart` exists (default template) |
| `vocal_service.dart` | Low | Exists but appears unused — possible dead code |
| `routine_service.dart` | Low | Exists but not integrated into main flow |

---

## 11. Code Quality Assessment

### Strengths

- **Clean architecture** — Clear separation between orchestrator, brain, tools, and services
- **Tool system** — Well-designed abstract base class with registry pattern
- **Security** — Policy engine + permission guard + Supabase RLS
- **Error handling** — Retry logic, fallback tiers, graceful degradation
- **UI/UX** — Polished sci-fi interface with animations and haptic feedback
- **Multi-platform** — Single codebase for Android, iOS, Web, Desktop

### Weaknesses

- **Large files** — `friday_brain_service.dart` (~1243 lines) and `friday_home_screen.dart` (~1267 lines) are doing too much
- **No tests** — No unit or widget tests for business logic
- **Hardcoded values** — Battery context is hardcoded (`"Battery: 89%"`), contacts are placeholder
- **Dead code** — `FallbackBrainService`, `vocal_service.dart`, `routine_service.dart` appear unused
- **No CI/CD** — No automated build, test, or deployment pipeline
- **Missing error boundaries** — No global error handler for uncaught exceptions
- **Token estimation is rough** — 4 chars/token is imprecise; may hit limits unexpectedly

### Code Metrics

| Metric | Value |
|--------|-------|
| Total Dart files | ~47 |
| Total lines (est.) | ~8,000+ |
| Largest file | `friday_home_screen.dart` (1267 lines) |
| Test coverage | ~0% |
| Public API classes | 15+ |
| Tool count | 10 |

---

## 12. Recommendations

### Immediate (P0)

1. **Add unit tests** — Test `TokenManager`, `ResponseSanitizer`, `IntentRouter`, `PolicyEngine`
2. **Remove dead code** — Delete or integrate `FallbackBrainService`, `vocal_service.dart`, `routine_service.dart`
3. **Fix hardcoded battery** — Use `BatteryTool` to get real battery level in brain service context

### Short-term (P1)

4. **Split large files** — Break `friday_brain_service.dart` into `GroqClient`, `ToolLoopManager`, `NudgeService`
5. **Add integration tests** — Test the full orchestrator pipeline with mocked API responses
6. **Implement proper token counting** — Use Groq's usage response instead of estimation
7. **Add CI/CD** — GitHub Actions for `flutter analyze`, `flutter test`, `flutter build`

### Long-term (P2)

8. **Add offline mode** — Cache recent responses, queue actions for when online
9. **Implement streaming** — Use Groq's streaming API for real-time token display
10. **Add analytics** — Track usage patterns, common intents, error rates
11. **Plugin architecture** — Allow third-party tool registration
12. **Multi-language support** — i18n for UI strings (currently English only)

---

*End of Audit*
