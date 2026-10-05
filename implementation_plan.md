# Friday Assistant v2.0 — Full Agent Upgrade

Upgrade the existing Friday Assistant from a conversational chatbot into a modular, tool-using, context-aware, autonomous personal agent — per the [phased PRD](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/friday_assistant_phased_prd.md).

The PRD defines 14 phases (0–13). **Phase 0 (audit) is already done** — I've read every source file. This plan starts at **Phase 1** and proceeds incrementally, wrapping existing services rather than deleting them.

> [!IMPORTANT]
> This is a large, multi-phase project. I propose we execute it **one milestone at a time**. Each milestone ships a working app. Approve this plan to begin **Milestone A (Phases 1–3)**.

---

## User Review Required

> [!WARNING]
> **Daily chat limit is currently 5.** During development you'll need to test heavily. Consider raising `DAILY_CHAT_LIMIT` in `token_manager.dart` temporarily, or the token manager will block your own testing.

> [!IMPORTANT]
> **Kotlin platform channel code is required in Phase 7.** The existing `android/app/src/main/kotlin/` has only the default Flutter activity. Native Kotlin code will need to be written later for battery, network, app-launch, and biometric tools. Confirm you're comfortable with Kotlin additions to the Android project when we reach that phase.

---

## Open Questions

1. **Token limits during dev**: Should I raise `DAILY_CHAT_LIMIT` to 50 (or unlimited) for the duration of development, then restore it before release?
2. **Supabase pgvector**: Is the `pgvector` extension already enabled on your Supabase project? Phase 4 (semantic memory) depends on it. If not, we can use the existing HuggingFace embedding + `match_memories` RPC as a fallback.
3. **Biometric auth**: Phase 3 calls for `local_auth` (fingerprint/face). Are you testing on a physical device, or emulator only? Biometrics won't work on emulator without mock setup.

---

## Proposed Changes

The PRD has 14 phases grouped into 4 milestones. Below is the concrete file plan for **Milestone A (Phases 1–3)** — the foundation that turns Friday into an agent.

---

### Phase 1 — Agent Foundation (`lib/agent/`)

> Wrap the existing `friday_brain_service.dart`; don't delete it. Add a typed orchestrator that owns the request lifecycle.

#### [NEW] [friday_orchestrator.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/agent/friday_orchestrator.dart)
Central coordinator. Receives user input → classifies intent → collects context → calls brain → routes to tools → verifies result → returns response. Wraps `FridayBrainService` internally. Generates a unique `requestId` per interaction. Manages the state machine: `received → classifying → collectingContext → retrievingMemory → planning → waitingForConfirmation → executing → verifying → completed / failed / cancelled`.

#### [NEW] [agent_models.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/agent/agent_models.dart)
Contains `AgentRequest`, `AgentResponse`, `AgentState` enum, and `RequestStatus`. Single file — no factory/interface/abstraction overhead per ponytail rules.

#### [NEW] [intent_router.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/agent/intent_router.dart)
Deterministic keyword matching for obvious commands (`what time`, `set reminder`, `open app`). Falls through to a single Groq structured-output call for ambiguous input. Returns an `IntentResult` with `intent`, `confidence`, `suggestedTools`, and boolean flags (`requiresWeb`, `requiresMemory`, `requiresTool`, `requiresPlanning`, `requiresConfirmation`).

#### [NEW] [context_engine.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/agent/context_engine.dart)
Interface-only in Phase 1. Returns a `ContextSnapshot` (time, timezone, battery placeholder, network placeholder). Concrete providers added in Phase 5.

#### [NEW] [result_verifier.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/agent/result_verifier.dart)
Takes a `ToolResult` and checks `success` field. Prevents the LLM from reporting success from generated text alone. Simple pass-through for now; enriched in later phases.

#### [MODIFY] [friday_home_screen.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/screens/friday_home_screen.dart)
Wire the new `FridayOrchestrator` as the entry point for user messages instead of calling `FridayBrainService.chatWithIntelligence()` directly. The orchestrator delegates to the brain service internally, so existing chat + voice behaviour is preserved.

---

### Phase 2 — Tool Registry & Safe Execution (`lib/tools/`)

> Move the hardcoded tool list out of `friday_brain_service.dart` into a typed registry. Add real initial tools.

#### [NEW] [friday_tool.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/tools/friday_tool.dart)
Abstract contract: `name`, `description`, `riskLevel`, `inputSchema`, `execute()`. Plus `ToolResult` model (`success`, `message`, `data`, `errorCode`, `startedAt`, `completedAt`) and `ToolContext`.

#### [NEW] [tool_registry.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/tools/tool_registry.dart)
Map of `name → FridayTool`. `register()`, `get()`, `has()`, `toGroqToolList()` (generates the JSON array currently hardcoded in `_buildToolRegistry`). Rejects unregistered tool names.

#### [NEW] [tool_executor.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/tools/tool_executor.dart)
Validates arguments against `inputSchema`, enforces timeout, calls `tool.execute()`, wraps result. Returns structured `ToolResult` — never raw strings.

#### [NEW] [tools/current_time_tool.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/tools/current_time_tool.dart)
Risk Level 0. Returns formatted local time. No API call.

#### [NEW] [tools/web_search_tool.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/tools/web_search_tool.dart)
Risk Level 0. Wraps existing `SearchService.search()`. Reuses all Tavily logic.

#### [NEW] [tools/memory_search_tool.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/tools/memory_search_tool.dart)
Risk Level 0. Wraps existing `MemoryService.retrieveContext()`.

#### [NEW] [tools/memory_save_tool.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/tools/memory_save_tool.dart)
Risk Level 1. Wraps existing `MemoryService.saveMemory()` + auditor logic currently in `_executeTool`.

#### [NEW] [tools/open_app_tool.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/tools/open_app_tool.dart)
Risk Level 1. Stub that uses `url_launcher` to open apps by package name. Full native Kotlin bridge deferred to Phase 7.

#### [NEW] [tools/battery_tool.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/tools/battery_tool.dart)
Risk Level 0. Returns battery level via `battery_plus` (or platform channel stub). Replaces the hardcoded `"Battery: 89%"` string in the brain service.

#### [MODIFY] [friday_brain_service.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/services/friday_brain_service.dart)
Replace `_buildToolRegistry()` with `ToolRegistry.toGroqToolList()`. Replace `_executeTool()` with `ToolExecutor.execute()`. The brain service becomes thinner — it still handles the Groq HTTP calls and message history, but tool definition/execution is delegated.

---

### Phase 3 — Permission, Confirmation & Policy Engine (`lib/security/`)

> Every tool has a fixed risk level. Sensitive ones pause for user approval.

#### [NEW] [action_risk_level.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/security/action_risk_level.dart)
Enum: `readOnly` (0), `reversible` (1), `sensitive` (2), `critical` (3).

#### [NEW] [policy_engine.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/security/policy_engine.dart)
Takes a `FridayTool` and decides: auto-execute (Level 0–1), pause for confirmation (Level 2), or require biometric + confirmation (Level 3). Returns a `PolicyDecision`.

#### [NEW] [permission_guard.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/security/permission_guard.dart)
Manages pending confirmations. Generates a one-time confirmation token. Prevents duplicate execution after approval. Expires after 60 seconds.

#### [NEW] [approval_sheet.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/widgets/approval_sheet.dart)
Bottom-sheet widget shown when `PolicyDecision` is `requiresConfirmation`. Displays action name, target, data being shared. Buttons: Approve / Edit / Cancel. Glassmorphic style matching existing UI.

#### [MODIFY] [friday_orchestrator.dart](file:///h:/0%20PROJECTS%20D/PERSONAL%20PROJECTS/Persona%20Ai/jarvis_assistant/lib/agent/friday_orchestrator.dart)
Wire PolicyEngine check between intent-routing and tool execution. If policy says pause → emit `waitingForConfirmation` state → show approval sheet → resume on approval.

---

## Milestones B–D (Phases 4–13) — Future Work

These are **not** started now. Summarized for visibility:

| Milestone | Phases | What it adds |
|---|---|---|
| **B — Context-Aware** | 4–6 | Semantic memory types + pgvector, context providers (battery/network/calendar), multi-step task planner with dependency graph |
| **C — Android Automation** | 7–10 | Kotlin MethodChannel bridge (open app, biometrics, contacts), trigger-condition-action automation engine replacing routines, voice barge-in, full agent UI (task cards, plan timeline, failure recovery) |
| **D — Stable Release** | 11–13 | Structured logging, circuit breakers, retry/backoff, response caching, security hardening, full test suite, release APK |

Each milestone will get its own detailed plan before execution.

---

## Verification Plan

### Automated Tests
- `flutter analyze` — must pass with zero errors after each phase.
- Unit tests for `IntentRouter` (keyword matching accuracy).
- Unit tests for `ToolRegistry` (reject unknown tools, validate arguments).
- Unit tests for `PolicyEngine` (correct risk-level decisions).
- Unit tests for `PermissionGuard` (token expiry, no duplicate execution).

### Manual Verification
- Send a chat message → confirm it flows through `FridayOrchestrator` → `IntentRouter` → `FridayBrainService` → response displayed. Existing behaviour preserved.
- Trigger a tool call (e.g., "what's the weather") → confirm `ToolRegistry` routes to `WebSearchTool` → structured `ToolResult` returned.
- Trigger a Level 2 action → confirm approval sheet appears → approve → action executes → result displayed.
- Trigger a Level 2 action → let confirmation expire → confirm action is NOT executed.
