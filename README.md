# Friday Assistant — Voice-Activated AI Companion (Flutter + Groq)

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Groq](https://img.shields.io/badge/Groq-AI-orange?style=for-the-badge)](https://groq.com)
[![CI](https://github.com/dj2313/jarvis_assistant/actions/workflows/ci.yml/badge.svg)](https://github.com/dj2313/jarvis_assistant/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/dj2313/jarvis_assistant?style=social)](https://github.com/dj2313/jarvis_assistant/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/dj2313/jarvis_assistant?style=social)](https://github.com/dj2313/jarvis_assistant/network/members)
[![GitHub issues](https://img.shields.io/github/issues/dj2313/jarvis_assistant)](https://github.com/dj2313/jarvis_assistant/issues)

**J.A.R.V.I.S.-style AI agent for your phone: voice chat, long-term vector memory, real-time web search, GPS navigation, and proactive notifications.**

*Flutter · Groq LLM + Whisper STT · Supabase pgvector memory · Tavily web search · Open-Meteo weather · Geolocator GPS*

[Getting Started](#-getting-started) · [Features](#-features) · [Architecture](#-architecture) · [Roadmap](#-roadmap) · [Contributing](CONTRIBUTING.md)

</div>

---

## Table of Contents

- [Why Friday Assistant?](#why-friday-assistant)
- [Features](#-features)
- [Demo](#-demo--screenshots)
- [Tech Stack](#-tech-stack)
- [Getting Started](#-getting-started)
- [Supabase Setup](#-supabase-setup)
- [Architecture](#-architecture)
- [Project Structure](#-project-structure)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [FAQ](#-faq)
- [License](#-license)

---

## Why Friday Assistant?

Unlike a plain chatbot, Friday is an **AI agent with tools**: it remembers you across sessions (vector memory), looks things up live (web search), knows where you are (GPS), opens apps, sends messages, and nudges you *before* problems happen (Sentinel mode).

| Capability | How | Benefit |
|------------|-----|---------|
| Voice-first chat | Groq Whisper STT + flutter_tts | Hands-free operation |
| Long-term memory | Supabase pgvector + HF embeddings | Remembers preferences across sessions |
| Real-time answers | Tavily web search | Current events, prices, news |
| Proactive alerts | Workmanager + local notifications | Warns before conflicts (rain vs. outdoor meeting) |
| Device actions | 10 tools (navigate, open_app, send_message…) | Opens apps, starts navigation, pre-fills messages |
| Privacy-first | Your own Supabase vault + RLS | Your data stays yours |
| Multi-platform | Android, iOS, Web, Desktop | One Flutter codebase |

---

## Features

### Futuristic UI/UX
- **The Friday Orb** — living core that reacts to voice amplitude; states: Idle, Listening, Thinking, Speaking.
- **Holographic aesthetics** — glassmorphism, neon gradients, drifting particle field.
- **Neural HUD** — system status + live memory-node count.
- **Haptic + sound feedback** on interactions.

### Agentic Intelligence (Groq tool-calling)
- Iterative tool loop (up to 6 rounds): `Thinking → Searching Web → Accessing Memory → Synthesizing`.
- **Memory Auditor** sub-agent: checks new facts against stored memories (update / correct / add).
- **10 tools**: `navigate`, `get_location`, `get_weather`, `web_search`, `search_memory`, `save_memory`, `current_time`, `get_battery`, `open_app`, `send_message`.

### Proactive Sentinel
- Background checks (schedule vs. weather/traffic) via `workmanager`.
- Manual **Sentinel** button for on-demand analysis.

### Vocal Interface
- Multilingual TTS (EN, FR, DE, ES, HI), British-butler persona ("Sir"/"Ma'am").
- Groq Whisper `whisper-large-v3` transcription, 30s auto-stop, waveform visualizer.

### Privacy & Security
- No audio stored; STT processed then discarded.
- Memories in private Supabase project with Row Level Security.
- Risk-based tool policy: read-only tools auto-run; sensitive/critical tools need your approval.

---

## Demo / Screenshots

> Add a 30–60s demo video and 2–3 screenshots — repos with a demo get ~3x more stars.

```
docs/demo.mp4            # <-- add screen recording (orb + voice + navigation)
assets/screenshots/home.png
assets/screenshots/chat.png
assets/screenshots/sentinel.png
```

Once added, embed them here:

```markdown
https://github.com/user-attachments/assets/…  <!-- demo video -->
![Home](assets/screenshots/home.png)
```

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter (Dart, SDK ^3.10.4) |
| LLM | Groq API (`openai/gpt-oss-120b` fast, `qwen/qwen3.6-27b` reasoning) |
| STT | Groq Whisper `whisper-large-v3` |
| Web search | Tavily API (advanced + AI answer) |
| Memory | Supabase PostgreSQL + pgvector, HF `all-MiniLM-L6-v2` embeddings |
| Weather | Open-Meteo (free, no key) |
| GPS | geolocator |
| State | setState + Streams |
| Background | workmanager + flutter_local_notifications |

---

## Getting Started

### Prerequisites
- Flutter SDK v3.10+
- A Supabase project (see [Supabase Setup](#-supabase-setup))
- API keys: Groq, HuggingFace, Tavily (all have free tiers)

### 1. Clone
```bash
git clone https://github.com/dj2313/jarvis_assistant.git
cd jarvis_assistant
```

### 2. Configure environment
Copy the example file and fill in your keys (never commit `.env`):
```bash
cp .env.example .env
```
```env
GROQ_API_KEY=your_groq_api_key_here
SUPABASE_URL=your_supabase_url_here
SUPABASE_ANON_KEY=your_supabase_anon_key_here
HF_TOKEN=your_huggingface_token_here
TAVILY_API_KEY=your_tavily_api_key_here
# Optional fallback LLM:
GEMINI_API_KEY=
```

### 3. Install & run
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

---

## Supabase Setup

Run these in the Supabase SQL editor:

1. **Routines table** — [`supabase/migrations/create_routines_table.sql`](supabase/migrations/create_routines_table.sql)
2. **Chat + memory tables** — you need:
   - `chat_messages (id uuid, role text, content text, created_at timestamptz)`
   - `jarvis_memory (id bigint, user_id uuid, content text, embedding vector(384), created_at timestamptz)`
   - `match_memories` RPC (cosine similarity over `embedding`, threshold ~0.4, top 3)
3. Enable **Row Level Security** so users only see their own rows, and enable **email auth**.

> Full schema + RLS reference: [`PROJECT_AUDIT.md`](PROJECT_AUDIT.md).

---

## Architecture

```
User text/voice → FridayHomeScreen → FridayOrchestrator
  → IntentRouter (keywords → Groq fallback)
  → ContextEngine (time, battery, network, location)
  → MemoryService (Supabase pgvector search)
  → FridayBrainService.chatWithIntelligence()
      → Groq tool-calling loop (max 6 rounds)
      → ToolExecutor → 10 tools
  → ResponseSanitizer → chat UI + TTS
```

Details: [`PROJECT_AUDIT.md`](PROJECT_AUDIT.md).

---

## Project Structure

```
lib/
├── agent/       # orchestrator, intent_router, context_engine, result_verifier
├── core/        # config (env keys, model names)
├── models/      # data models
├── screens/     # friday_home_screen, auth, routines, memory vault, settings
├── security/    # policy_engine, permission_guard
├── services/    # friday_brain, memory, search, location, voice, token_manager
├── tools/       # 10 FridayTool implementations + registry/executor/bootstrap
└── widgets/     # friday_orb, rich_message_card, approval_sheet, …
```

---

## Roadmap

- [ ] Streaming Groq responses (real-time tokens)
- [ ] Unit + widget tests (TokenManager, Sanitizer, IntentRouter, tools)
- [ ] Google Calendar sync ("what's my schedule today?")
- [ ] MCP-style plugin system for third-party tools
- [ ] BYOK model picker (Groq / Gemini / local Ollama)
- [ ] Offline queue (cache answers, queue actions)
- [ ] Release builds on GitHub Releases + Fastlane deploy

Vote / discuss in [Discussions](https://github.com/dj2313/jarvis_assistant/discussions) or open an [issue](https://github.com/dj2313/jarvis_assistant/issues).

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

```bash
git checkout -b feature/my-feature
flutter analyze && flutter test
```

---

## FAQ

**Does it work without API keys?** No — chat needs `GROQ_API_KEY`; memory needs Supabase + `HF_TOKEN`; web search needs `TAVILY_API_KEY`. Weather and GPS work without keys.

**Why is GPS slow the first time?** Cold GPS fix can take ~30s. The app waits up to 30s, then falls back to the last known position.

**Which platforms work best?** Android first (app launching, navigation intents). Voice/GPS/app-launch are limited on Web.

---

## License

MIT — see [LICENSE](LICENSE).

---

<div align="center">

**If this project helps you, please give it a ⭐ — it helps others discover it.**

[![Star History Chart](https://api.star-history.com/svg?repos=dj2313/jarvis_assistant&type=Date)](https://star-history.com/#dj2313/jarvis_assistant&Date)

*Built with love for the future.*

</div>
