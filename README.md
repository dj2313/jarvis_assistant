# Friday Assistant (Persona AI)

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/Groq-AI-orange?style=for-the-badge" alt="Groq AI" />
</div>

## Overview

**Friday Assistant** is a next-generation, voice-activated Personal AI companion built with **Flutter**. Designed with a "Sci-Fi First" philosophy, it combines state-of-the-art Large Language Models (LLMs) with a premium, immersive user interface featuring holographic aesthetics, reactive animations, and proactive intelligence.

Unlike standard chatbots, Friday possesses **Long-Term Memory**, **Real-Time Web Access**, and a **Proactive Sentinel Mode** that watches out for you even when the app is in the background.

---

## 🌌 Features

### Futuristic UI/UX
- **The Friday Orb:** A central, living core that reacts to voice amplitude, pulses when thinking, and transforms based on AI state (Idle, Listening, Processing, Speaking)
- **Holographic Aesthetics:** Glassmorphism effects, neon gradients, and dynamic Particle Field backgrounds
- **Neural HUD:** Real-time system status display with Neural Link indicator and active Memory Node count
- **Immersive Feedback:** Haptic feedback and distinct sound effects for all interactions

### 🧠 Advanced Intelligence
- **FridayBrainService:** Powered by **Groq (Llama 3.3 70B)** for lightning-fast inference and complex reasoning
- **Agentic Workflow:** Visualized thought process phases: Thinking → Searching Web → Accessing Memory → Synthesizing
- **Memory Auditor:** Autonomous sub-agent that verifies information against existing memory to prevent conflicts
- **Tool Integration:**
  - **web_search:** Real-time data fetching (Weather, News, Stock Prices)
  - **save_memory/search_memory:** Supabase Vault integration for personal facts and preferences

### 🛡️ Proactive Sentinel System
- **Background Nudges:** Scheduled background checks on schedule, weather, and environment
- **Contextual Awareness:** Intelligent notifications (e.g., "Outdoor meeting at 3 PM with forecasted rain - take an umbrella")
- **Manual Diagnostics:** Trigger instant Sentinel Check for immediate analysis

### 🗣️ Vocal Interface
- **Multilingual Support:** English, French, German, Spanish, and Hindi
- **Real-Time Transcription:** Seamless speech-to-text dictation
- **Natural Voice:** High-quality Text-to-Speech response system

### 📜 System Protocols
- **Sentinel Protocol:** Background conflict detection
- **Auditor Protocol:** Pre-save memory verification
- **Planning Protocol:** Automatic goal decomposition into multi-phase action plans
- **Vocal Protocol:** Natural language filtering for refined TTS output

### 🔒 Privacy & Security
- **Local Processing:** Initial reasoning via Groq's high-speed inference
- **Encrypted Vault:** Personal memories in private Supabase instance with Row Level Security (RLS)
- **Minimal Footprint:** No audio data storage; STT processed and discarded in real-time

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|------------|
| **Framework** | Flutter (Dart) |
| **AI Backend** | Groq API (Llama 3.3 70B) |
| **Database** | Supabase (PostgreSQL) |
| **State Management** | Native setState & Streams |
| **Animations** | flutter_animate & Custom Painters |
| **Voice** | speech_to_text & flutter_tts |
| **Background Tasks** | workmanager |
| **Notifications** | flutter_local_notifications |

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK** v3.10+ installed
- **Supabase Project** with `chat_messages` and `Friday_memory` tables
- **Groq API Key** for LLM inference

### Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/dj2313/jarvis_assistant.git
   cd jarvis_assistant
   ```

2. **Configure Environment**
   Create a `.env` file in the root directory:
   ```env
   GROQ_API_KEY=your_groq_api_key_here
   SUPABASE_URL=your_supabase_url_here
   SUPABASE_ANON_KEY=your_supabase_anon_key_here
   ```

3. **Install Dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the App**
   ```bash
   flutter run
   ```

---

## 📂 Project Structure

```
lib/
├── core/            # Configuration and Constants
├── models/          # Data Models (ChatMessage, etc.)
├── screens/         # UI Screens
│   ├── friday_home_screen.dart              # Main HUD Interface
│   ├── friday_initialization_screen.dart    # Boot-up Sequence
│   └── ...
├── services/        # Logic & API Layers
│   ├── friday_brain_service.dart    # AI Core, Groq Integration, & Tools
│   ├── memory_service.dart          # Supabase DB Interactions
│   └── vocal_service.dart           # TTS & STT Handling
└── widgets/         # Reusable UI Components
    └── friday_orb.dart              # The animated AI Core
```

---

_Built with ❤️ for the Future._
