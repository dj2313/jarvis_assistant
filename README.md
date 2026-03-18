# Friday Assistant (Persona AI)

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/Groq-AI-orange?style=for-the-badge" alt="Groq AI" />
</div>

<br />

**Friday Assistant** is a next-generation, voice-activated Personal AI companion built with **Flutter**. Designed with a "Sci-Fi First" philosophy, it combines state-of-the-art Large Language Models (LLMs) with a premium, immersive user interface featuring holographic aesthetics, reactive animations, and proactive intelligence.

Unlike standard chatbots, Friday possesses **Long-Term Memory**, **Real-Time Web Access**, and a **Proactive Sentinel Mode** that watches out for you even when the app is in the background.

---

## 🌌 Futuristic UI/UX
The interface is designed to feel like a piece of advanced technology from the future.
- **The Friday Orb:** A central, living core that reacts to voice amplitude, pulses when thinking, and transforms based on the AI's state (Idle, Listening, Processing, Speaking).
- **Holographic Aesthetics:** Extensive use of **Glassmorphism**, neon gradients, and a dynamic **Particle Field** background that drifts endlessly.
- **Neural HUD:** A "Heads-Up Display" header showing real-time system status, inclusive of a "Neural Link" indicator and active Memory Node count.
- **Immersive Feedback:** Haptic feedback on interactions and distinct sound effects for activation, processing, and responses.

## 🧠 Advanced Intelligence (The Brain)
At the core is the `FridayBrainService`, powered by **Groq (Llama 3.3 70B)**, enabling lightning-fast inference and complex reasoning.
- **Agentic Workflow:** Friday doesn't just guess; he thinks. The UI visualizes his thought process phases: `Thinking` → `Searching Web` → `Accessing Memory` → `Synthesizing`.
- **Memory Auditor:** An autonomous sub-agent that verifies new information against existing long-term memory to prevent conflicts, deciding whether to **Update**, **Correct**, or **Add** data.
- **Tool Use:**
  - **`web_search`**: Fetches real-time data (Weather, News, Stock Prices).
  - **`save_memory` / `search_memory`**: Interacts with the Supabase Vault to recall personal facts, preferences, and past conversations.

## 🛡️ Proactive Sentinel System
Friday isn't just reactive; he is **Proactive**.
- **Background "Nudges":** Utilizing `workmanager` and `flutter_local_notifications`, Friday performs background checks on your schedule, weather, and environment.
- **Contextual Awareness:** "Sir, you have an outdoor meeting at 3 PM, but rain is forecast. I suggest taking an umbrella."
- **Manual Diagnostics:** Trigger a "Sentinel Check" manually to have Friday analyze your current situation immediately.

## 🗣️ Vocal Interface
- **Multilingual Support:** Fluent in English, French, German, Spanish, and Hindi.
- **Real-Time Transcription:** sophisticated `speech_to_text` integration for seamless dictation.
- **Natural Voice:** High-quality Text-to-Speech (TTS) response system.

## 📜 System Protocols
Friday operates under a strict set of behavioral protocols to ensure stability and personality:

- **Sentinel Protocol:** Background conflict detection (Weather vs. Schedule).

- **Auditor Protocol:** Pre-save memory verification to prevent data contradictions.

- **Planning Protocol:** Automatic decomposition of complex goals into multi-phase action plans.

- **Vocal Protocol:** Natural language filtering to ensure the TTS sounds like a refined butler, not a machine.

## 🔒 Privacy & Security

- **Local Context:** Initial reasoning is processed via Groq's high-speed inference.
- **Encrypted Vault:** All personal memories are stored in a private Supabase instance with Row Level Security (RLS) enabled.
- **Minimal Footprint:** No audio data is stored; STT is processed in real-time and discarded.

## 🛠️ Tech Stack

| Component | Technology |
|-----------|------------|
| **Framework** | Flutter (Dart) |
| **AI Backend** | Groq API (Llama 3.3 70B) |
| **Database** | Supabase (PostgreSQL) |
| **State Management** | Native `setState` & Streams |
| **Animations** | `flutter_animate` & Custom Painters |
| **Voice** | `speech_to_text` & `flutter_tts` |
| **Background Tasks** | `workmanager` |
| **Notifications** | `flutter_local_notifications` |

## 🚀 Getting Started

### Prerequisites
1.  **Flutter SDK** installed (v3.10+ recommended).
2.  **Supabase Project** set up with a `chat_messages` and `Friday_memory` table.
3.  **Groq API Key** for LLM inference.

### Installation

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/your-username/Friday-assistant.git
    cd Friday-assistant
    ```

2.  **Configure Environment**
    Create a `.env` file in the root directory:
    ```env
    GROQ_API_KEY=your_groq_api_key_here
    SUPABASE_URL=your_supabase_url_here
    SUPABASE_ANON_KEY=your_supabase_anon_key_here
    ```

3.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

4.  **Run the App**
    ```bash
    flutter run
    ```

## 📂 Project Structure

```
lib/
├── core/            # Configuration and Constants
├── models/          # Data Models (ChatMessage, etc.)
├── screens/         # UI Screens
│   ├── Friday_home_screen.dart       # Main HUD Interface
│   ├── Friday_initialization_screen.dart # Boot-up Sequence
│   └── ...
├── services/        # Logic & API Layers
│   ├── Friday_brain_service.dart     # AI Core, Groq Integration, & Tools
│   ├── memory_service.dart           # Supabase DB Interactions
│   └── vocal_service.dart            # TTS & STT Handling
└── widgets/         # Reusable UI Components
    └── Friday_orb.dart               # The animated AI Core
```

---

_Built with ❤️ for the Future._
