# Product Requirements Document (PRD)

## Friday Assistant — Automated Personal AI Agent

**Version:** 2.0  
**Platform:** Android  
**Frontend:** Flutter  
**Native Integration:** Kotlin via Flutter Platform Channels  
**AI Provider:** Groq API  
**Primary Model:** Llama 3.3 70B  
**Backend and Database:** Supabase  
**Search Provider:** Tavily  
**Development Environment:** Antigravity IDE  
**Document Status:** Implementation PRD  
**Implementation Strategy:** Phased upgrade of the existing project

---

# 1. Executive Summary

Friday Assistant is an existing Flutter-based, voice-activated personal AI companion. The current application already includes Groq-powered AI responses, Supabase authentication and long-term memory, speech-to-text, text-to-speech, Tavily web search, routine management, token limits, Workmanager background tasks, local notifications, and a futuristic holographic interface.

The next version will upgrade the application from a conversational AI assistant into a secure, context-aware, tool-using, and partially autonomous personal agent.

The upgraded Friday Assistant must be able to understand natural-language requests, retrieve relevant memories, collect contextual information, create structured plans, select approved tools, request confirmation for sensitive actions, execute supported Android actions, verify results, recover from failures, and proactively notify the user about important events.

The current codebase must be extended incrementally. Working features should not be removed or rewritten until their replacements are implemented, tested, and integrated.

---

# 2. Current Product Foundation

The existing project contains the following confirmed components:

- Flutter application using Dart
- Groq API integration
- Llama 3.3 70B inference
- Supabase authentication
- Supabase-based long-term memory
- Row Level Security assumptions for user-specific memory
- Speech-to-text using `speech_to_text`
- Text-to-speech using `flutter_tts`
- Tavily web search
- Workmanager background processing
- Routine scheduling
- Local notifications
- Token and daily usage limits
- Shared Preferences for usage persistence
- Fallback AI service
- Environment-variable configuration
- Holographic Friday interface
- Animated Friday Orb
- Memory Vault screen
- Routine management screen
- Neural settings and usage statistics
- Sentinel background checks

Important current services include:

```text
lib/
├── core/
│   └── config.dart
├── models/
│   └── routine.dart
├── screens/
│   ├── auth_screen.dart
│   ├── friday_home_screen.dart
│   ├── friday_initialization_screen.dart
│   ├── landing_screen.dart
│   ├── memory_vault_screen.dart
│   ├── neural_settings_screen.dart
│   └── routines_screen.dart
├── services/
│   ├── auth_service.dart
│   ├── fallback_brain_service.dart
│   ├── friday_brain_service.dart
│   ├── memory_service.dart
│   ├── routine_service.dart
│   ├── search_service.dart
│   ├── token_manager.dart
│   ├── vocal_service.dart
│   └── voice_service.dart
├── widgets/
│   ├── ambient_idle_overlay.dart
│   ├── friday_orb.dart
│   ├── holographic_cards.dart
│   ├── rich_message_card.dart
│   └── usage_stats_card.dart
└── main.dart
```

The actual codebase remains the source of truth if the implementation differs from this structure.

---

# 3. Product Vision

Friday Assistant will become a personal agent operating system for Android.

It should feel like a practical version of Friday or Jarvis while remaining realistic, secure, permission-based, and compatible with Android restrictions.

Friday should be able to:

- Understand voice and text commands
- Remember relevant personal information
- Retrieve memories semantically
- Understand time, device, task, and routine context
- Search the web when fresh information is required
- Select and execute registered tools
- Create multi-step plans
- Ask for approval before sensitive actions
- Verify whether actions succeeded
- Resume interrupted tasks
- Detect conflicts and important changes
- Produce proactive briefings
- Explain which context or memory influenced a recommendation
- Operate simple commands locally when possible
- Clearly report unsupported capabilities

---

# 4. Product Goals

## 4.1 Primary Goals

1. Convert the existing assistant into a modular AI-agent architecture.
2. Add a secure tool registry and controlled tool execution.
3. Separate reasoning, planning, permission checking, execution, and verification.
4. Improve long-term memory using structured semantic retrieval.
5. Add contextual awareness without sending unnecessary private data to the model.
6. Support safe native Android actions.
7. Upgrade routines into an event-driven automation engine.
8. Support multi-step task planning and execution.
9. Improve voice responsiveness and interruption handling.
10. Make every important action transparent and auditable.
11. Prevent false success messages and hallucinated tool execution.
12. Preserve current working features during migration.

## 4.2 Secondary Goals

- Reduce unnecessary Groq requests
- Reduce token usage
- Add partial offline command execution
- Improve recovery after network failure or application restart
- Add execution logs and diagnostics
- Improve accessibility and small-screen responsiveness
- Make the project portfolio-ready
- Prepare the architecture for future multi-user or commercial use

---

# 5. Non-Goals

The upgraded application will not:

- Root the Android device
- Bypass Android permissions
- Secretly control third-party applications
- Read private application data without permission
- Perform hidden accessibility clicks
- Make payments automatically
- Send messages or emails without required approval
- Claim to support actions that Android does not permit
- Stay continuously active through unsupported background behaviour
- Expose private chain-of-thought reasoning
- Replace medical, legal, financial, or emergency professionals
- Store every conversation permanently by default

---

# 6. Target Users

## Primary User

An Android user who wants a secure, voice-first personal assistant for daily planning, reminders, work, university, communication preparation, notifications, routines, and supported device actions.

## Typical User Characteristics

- Uses Android daily
- Has work, university, and personal commitments
- Wants faster task completion through voice
- Needs reminders and proactive alerts
- Values privacy and user control
- Wants the assistant to remember useful information
- Wants transparent explanations
- Uses multiple applications for daily productivity

---

# 7. Core User Problems

The product should solve the following problems:

1. Simple tasks require opening several applications.
2. Traditional assistants have weak long-term memory.
3. Chatbots provide answers but do not reliably execute actions.
4. Users receive too many notifications.
5. Important reminders and conflicts are easy to miss.
6. Multi-step tasks require repetitive manual work.
7. AI systems may incorrectly claim that an action succeeded.
8. Background automation may create privacy concerns.
9. Existing assistants do not explain why a recommendation was made.
10. Users cannot easily inspect or delete what an assistant remembers.

---

# 8. Product Principles

## 8.1 User Control

The user must remain in control of all important and sensitive actions.

## 8.2 Permission Before Sensitive Actions

Friday must request confirmation before performing sensitive actions.

## 8.3 Verify Before Reporting Success

Friday must not report success unless the tool result is verified.

## 8.4 Local-First Behaviour

Simple deterministic actions should be processed locally where possible.

## 8.5 Minimum Required Context

Only context relevant to the current request should be collected and sent to the AI model.

## 8.6 Privacy by Design

Sensitive information must be protected, minimized, and removable.

## 8.7 Graceful Failure

Friday must clearly explain failures and provide a retry or recovery path.

## 8.8 Transparent Assistance

Friday should provide a concise explanation of why it used particular memories, context, or tools.

## 8.9 Incremental Migration

Existing working services should initially be wrapped and reused instead of immediately removed.

---

# 9. Target Request Lifecycle

```text
Voice or Text Input
        ↓
Input Normalization
        ↓
Intent Classification
        ↓
Context Selection
        ↓
Relevant Memory Retrieval
        ↓
Direct Action or Task Planning
        ↓
Policy and Risk Evaluation
        ↓
User Confirmation When Required
        ↓
Registered Tool Execution
        ↓
Result Verification
        ↓
Task and Memory Update
        ↓
Voice and Visual Response
```

---

# 10. Functional Requirements

## 10.1 Friday Orchestrator

The Friday Orchestrator will manage the complete request lifecycle.

### Responsibilities

- Receive voice or text requests
- Generate a unique request ID
- Normalize user input
- Call the intent router
- Request relevant context
- Retrieve relevant memories
- Decide whether planning is required
- Send approved tool calls to the executor
- Pause for confirmation when necessary
- Verify results
- Save task state
- Update memory when appropriate
- Generate the final response
- Support cancellation and retry

### Required States

```text
received
classifying
collectingContext
retrievingMemory
planning
waitingForConfirmation
executing
verifying
completed
partiallyCompleted
failed
cancelled
```

### Constraints

- The orchestrator must not directly perform device actions.
- It must use typed requests and responses.
- It must prevent duplicate execution.
- It must support resuming eligible tasks.
- It must initially wrap `friday_brain_service.dart` rather than deleting it.

---

## 10.2 Intent Router

The Intent Router will classify requests before invoking the primary model.

### Supported Intents

```text
generalConversation
directQuestion
memoryLookup
memoryUpdate
webSearch
deviceAction
calendarAction
reminderAction
communicationAction
notificationQuery
routineAction
automationCreation
multiStepTask
unsupportedAction
safetySensitiveAction
```

### Requirements

- Use deterministic rules for obvious commands.
- Use Groq structured output when rules are insufficient.
- Validate model output.
- Provide a fallback intent.
- Return confidence and suggested tools.
- Log routing decisions.
- Avoid the large model for simple commands.

### Example Output

```json
{
  "intent": "reminderAction",
  "complexity": "simple",
  "requiresWeb": false,
  "requiresMemory": false,
  "requiresTool": true,
  "requiresPlanning": false,
  "requiresConfirmation": false,
  "suggestedTools": ["create_local_reminder"],
  "confidence": 0.94
}
```

---

## 10.3 Tool Registry and Tool Executor

Friday must use a controlled registry of approved tools.

### Tool Contract

```dart
abstract class FridayTool {
  String get name;
  String get description;
  ActionRiskLevel get riskLevel;
  Map<String, dynamic> get inputSchema;

  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
  );
}
```

### Tool Result Requirements

```text
success
message
data
errorCode
requiresConfirmation
verificationData
startedAt
completedAt
```

### Initial Tools

- Get current time
- Search the web
- Create a local reminder
- Open an installed application
- Read battery state
- Read network state
- Generate a communication draft
- Read pending tasks

### Tool Execution Rules

- Only registered tools may execute.
- Tool arguments must be validated.
- Unknown tools must be rejected.
- Execution must support timeouts.
- Failures must return structured errors.
- Sensitive tools must pass through the policy engine.
- The LLM must never invoke arbitrary Dart or Kotlin functions.
- Friday must not report success from generated text alone.

---

## 10.4 Permission and Risk System

Every tool must declare a fixed risk level.

### Risk Levels

| Level | Type | Behaviour |
|---|---|---|
| Level 0 | Read-only | Execute automatically |
| Level 1 | Reversible | Execute and notify |
| Level 2 | Sensitive | Require explicit confirmation |
| Level 3 | Critical | Require confirmation and biometric authentication |

### Examples

| Action | Risk Level |
|---|---|
| Read time | Level 0 |
| Read weather | Level 0 |
| Open an application | Level 1 |
| Create a reminder | Level 1 |
| Send a message | Level 2 |
| Delete memory | Level 2 |
| Share sensitive information | Level 3 |
| Payment-related action | Level 3 |

### Requirements

- The model cannot lower a tool’s risk level.
- Confirmation must show the action, target, and shared data.
- Users must be able to approve, edit, or cancel.
- Confirmations must expire.
- Approval must not trigger duplicate execution.
- Sensitive actions must appear in an audit log.
- Level 3 actions must use Android biometric authentication where supported.

---

## 10.5 Memory System

The existing Supabase memory system will be upgraded into structured semantic memory.

### Memory Types

```text
profile
preference
episodic
relationship
schedule
location
task
temporary
conversationSummary
```

### Memory Fields

```text
id
userId
content
memoryType
importance
confidence
source
embedding
createdAt
updatedAt
lastAccessedAt
expiresAt
isSensitive
metadata
```

### Requirements

- Preserve existing memories during migration.
- Add semantic search using Supabase pgvector when available.
- Provide a fallback when pgvector is unavailable.
- Rank memories by similarity, importance, recency, and confidence.
- Avoid storing every conversation.
- Ask before storing sensitive information.
- Support memory expiration.
- Support deduplication.
- Support consolidation.
- Allow users to inspect, edit, and delete memories.
- Maintain user-specific RLS.
- Never store a Supabase service-role key in the application.

### User Commands

- “What do you remember about me?”
- “Forget my work schedule.”
- “Do not remember this.”
- “Remember this for one week.”

---

## 10.6 Context Engine

Friday must collect only the context needed for the active request.

### Context Sources

- Current date and time
- User timezone
- Battery status
- Charging state
- Network state
- Relevant memories
- Pending tasks
- Recent tool executions
- Active routine
- Calendar events when permission is granted
- Location when permission is granted
- Weather
- Bluetooth state
- Current application when available and permitted

### Requirements

- Use typed context providers.
- Every provider must be permission-aware.
- Providers must have timeouts.
- One failed provider must not fail the request.
- Context must include source and freshness.
- Sensitive context must be redacted unless required.
- A selector must choose context based on intent.
- Debug context must appear only in development mode.
- Users should be able to view why context was used.

---

## 10.7 Multi-Step Task Planning

Friday must create structured plans only for requests requiring multiple dependent actions.

### Example

User request:

```text
Prepare me for tomorrow.
```

Possible plan:

```text
1. Read tomorrow’s calendar.
2. Check the weather.
3. Review pending tasks.
4. Detect schedule conflicts.
5. Calculate preparation requirements.
6. Generate a briefing.
7. Offer to create reminders.
```

### Required Models

```text
TaskPlan
TaskStep
StepDependency
StepResult
TaskExecutionState
```

### Step States

```text
planned
waitingForConfirmation
ready
running
completed
failed
skipped
cancelled
```

### Requirements

- Use structured JSON plans.
- Validate every plan.
- Allow only registered tools.
- Reject unknown tools.
- Detect circular dependencies.
- Limit maximum plan size.
- Require approval before sensitive steps.
- Persist plans.
- Support retries.
- Support cancellation.
- Support partial completion.
- Support resumption after restart.
- Display a concise user-facing plan.
- Do not expose private chain-of-thought reasoning.

---

## 10.8 Automation Engine

The current routines and Sentinel system will evolve into a trigger-condition-action engine.

### Structure

```text
Trigger
    ↓
Conditions
    ↓
Actions
    ↓
Verification
    ↓
Notification
```

### Initial Triggers

- Scheduled time
- Calendar event approaching
- Battery threshold
- Network change
- Manual command
- Application opened
- Location entry or exit
- Notification received

### Initial Actions

- Show a notification
- Create a reminder
- Run a web search
- Generate a briefing
- Open an application
- Read pending tasks
- Prepare a communication draft

### Requirements

- Support enable and disable states.
- Store last run and next run.
- Store execution history.
- Add cooldown periods.
- Prevent notification loops.
- Support retry policies.
- Use Workmanager only for deferrable work.
- Use Android-compliant foreground services only where required.
- Do not perform continuous hidden execution.
- Require confirmation for sensitive actions.
- Provide an automation builder UI.

### Initial Sample Automations

- Morning briefing
- Work-shift weather alert
- Low-battery reminder
- Upcoming-event preparation
- Daily pending-task summary

---

## 10.9 Native Android Bridge

Flutter must communicate with native Kotlin services through platform channels.

### Initial Native Capabilities

- Open an installed application
- Read battery state
- Read network state
- Trigger biometric authentication
- Check permission status

### Future Native Capabilities

- Notification listener
- Foreground voice service
- Contacts integration
- Calendar integration
- Media control
- Geofencing
- Android assistant role
- Quick Settings tile
- Home-screen widget

### Constraints

- Native features must return structured responses.
- Unsupported features must fail gracefully.
- Permissions must be requested only when required.
- Permission explanations must be user-friendly.
- The application must not request every permission during onboarding.
- Hidden accessibility actions are prohibited.
- Android version differences must be handled.

---

## 10.10 Voice Interaction

The existing STT and TTS services will be preserved and improved.

### Voice States

```text
idle
listening
processing
speaking
interrupted
error
```

### Requirements

- Show partial transcripts.
- Support speech timeout handling.
- Prevent multiple microphone sessions.
- Prevent overlapping TTS responses.
- Allow the user to cancel listening.
- Add retry after recognition failure.
- Synchronize voice state with the Friday Orb.
- Route simple commands locally.
- Prepare the architecture for streaming.
- Add barge-in support where technically feasible.

### Barge-In Behaviour

When Friday is speaking and the user starts speaking:

1. Stop TTS.
2. Change state to interrupted.
3. Start listening.
4. Process the new request.
5. Cancel or pause the previous response where appropriate.

Wake-word detection is not part of the initial upgrade unless a stable implementation is already available.

---

## 10.11 User Interface Updates

The current holographic style must be preserved.

### New Components

- Live task status card
- Multi-step plan timeline
- Approval sheet
- Tool execution result card
- Failure recovery card
- Context explanation card
- Automation status card
- Memory source indicator
- Permission explanation screen
- Debug diagnostics screen

### UI Requirements

- Show when Friday is listening, thinking, searching, accessing memory, waiting for approval, executing, verifying, completed, or failed.
- Allow cancellation of running tasks.
- Allow editing before approval.
- Clearly distinguish verified success from assumed output.
- Show retry options.
- Keep animations smooth and lightweight.
- Ensure readable contrast.
- Support small Android screens.
- Maintain the existing Friday Orb as the central visual element.

---

## 10.12 Reliability and Recovery

### Requirements

- Generate request IDs and task IDs.
- Add structured logs.
- Do not log secrets or private memory content.
- Add API timeouts.
- Add retries with exponential backoff.
- Add offline detection.
- Add idempotency for sensitive actions.
- Add circuit breakers for failing services.
- Validate all model responses.
- Handle malformed JSON.
- Integrate existing token limits.
- Persist eligible task states.
- Resume interrupted tasks where safe.
- Prevent duplicate actions.
- Provide graceful fallback responses.
- Add debug-only diagnostics.

---

## 10.13 Security

### Requirements

- No hardcoded secrets.
- `.env` must remain excluded from version control.
- Supabase service-role keys must never be included in the client.
- User-specific data must be protected by RLS.
- Model output must be treated as untrusted input.
- Tool arguments must be validated.
- Tools must be registered explicitly.
- Sensitive actions must require approval.
- Critical actions must use biometrics where supported.
- Logs must not expose personal data.
- Memory deletion must work.
- Account deletion must remove user-owned data.
- Android permissions must follow least privilege.
- Automations must not silently perform sensitive actions.
- All unresolved risks must be documented.

---

# 11. Non-Functional Requirements

## Performance

- Simple local actions should begin within 500 milliseconds where technically possible.
- UI state changes should feel immediate.
- Animations should target smooth 60 FPS performance.
- Context collection should run concurrently where safe.
- Each context provider must have a timeout.
- The main interface must remain responsive during AI requests.

## Reliability

- A failed external service must not crash the application.
- Every action must return a structured result.
- Duplicate sensitive actions must be prevented.
- Failed tasks must provide retry or recovery options.

## Privacy

- Only necessary information should be sent to Groq or Tavily.
- Sensitive memories should require explicit permission.
- Users must be able to review and delete stored memories.
- Debug logs must redact personal data.

## Maintainability

- Features must use clean interfaces.
- Business logic must not be tightly coupled to UI widgets.
- Native integrations must be isolated behind a bridge.
- Existing working services must be migrated gradually.
- New modules must include tests and documentation.

## Scalability

- Tool registration must support additional capabilities.
- Memory retrieval must support larger datasets.
- Automation triggers and actions must be extensible.
- Model providers should be replaceable through interfaces.

---

# 12. Proposed Target Architecture

```text
lib/
├── agent/
│   ├── friday_orchestrator.dart
│   ├── agent_request.dart
│   ├── agent_response.dart
│   ├── agent_state.dart
│   ├── intent_router.dart
│   ├── context_engine.dart
│   ├── task_planner.dart
│   └── result_verifier.dart
├── tools/
│   ├── friday_tool.dart
│   ├── tool_context.dart
│   ├── tool_result.dart
│   ├── tool_registry.dart
│   ├── tool_executor.dart
│   ├── device/
│   ├── search/
│   ├── productivity/
│   └── communication/
├── security/
│   ├── action_risk_level.dart
│   ├── permission_guard.dart
│   ├── policy_engine.dart
│   └── biometric_guard.dart
├── memory/
│   ├── memory_manager.dart
│   ├── memory_classifier.dart
│   ├── memory_retriever.dart
│   ├── memory_ranker.dart
│   ├── memory_consolidator.dart
│   └── memory_models.dart
├── automation/
│   ├── trigger_engine.dart
│   ├── condition_engine.dart
│   ├── action_engine.dart
│   ├── automation_runner.dart
│   └── automation_models.dart
├── native/
│   └── android_bridge.dart
├── diagnostics/
│   ├── diagnostics_service.dart
│   └── diagnostics_screen.dart
└── existing project folders and services
```

The exact structure may be adjusted after Antigravity audits the real codebase.

---

# 13. Phased Implementation Plan

## Phase 0 — Project Audit and Baseline

### Objective

Understand the current implementation before modifying it.

### Scope

- Inspect the complete codebase
- Document architecture
- Map request lifecycle
- Audit security
- Audit Android permissions
- Audit Supabase usage
- Audit voice services
- Audit Workmanager routines
- Run existing tests
- Build the current Android application
- Record known issues

### Deliverables

- `docs/current_architecture_audit.md`
- `docs/current_request_lifecycle.md`
- `docs/security_audit_initial.md`
- `docs/technical_debt_report.md`
- `docs/refactoring_plan.md`
- `docs/implementation_checklist.md`

### Acceptance Criteria

- No application code is modified.
- Current build status is documented.
- Existing capabilities are confirmed from code.
- Critical risks are identified.
- Migration order is approved.

---

## Phase 1 — Agent Foundation

### Objective

Create the modular request-processing architecture.

### Scope

- Friday Orchestrator
- Agent request and response models
- Agent states
- Intent Router
- Initial Context Engine interface
- Task Planner interface
- Result Verifier interface
- Dependency injection
- Wrapper around `friday_brain_service.dart`

### Deliverables

- `lib/agent/`
- Unit tests for state transitions
- Architecture documentation

### Acceptance Criteria

- Existing chat and voice behaviour still works.
- Every new request receives a unique ID.
- Request state is visible internally.
- The existing brain service is wrapped, not deleted.
- Flutter analysis passes.
- Unit tests pass.

---

## Phase 2 — Tool Registry and Safe Execution

### Objective

Allow Friday to perform controlled actions through approved tools.

### Scope

- Tool contract
- Tool Registry
- Tool Executor
- Tool argument validation
- Tool timeout handling
- Structured results
- Execution logs
- Initial mock and real tools

### Initial Tools

- Current time
- Tavily web search
- Local reminder
- Open application
- Battery status
- Network status

### Acceptance Criteria

- Only registered tools can execute.
- Invalid arguments are rejected.
- Unknown tools are rejected.
- Tool failures return structured errors.
- No false success is reported.
- Existing Tavily logic is reused.

---

## Phase 3 — Permission, Confirmation, and Policy Engine

### Objective

Protect sensitive actions.

### Scope

- Risk levels
- Policy Engine
- Permission Guard
- Confirmation UI
- Action expiry
- Audit log
- Biometric interface

### Acceptance Criteria

- Every tool has a fixed risk level.
- Sensitive actions require approval.
- Critical actions require biometric verification where supported.
- The model cannot lower risk.
- Users can approve, edit, or cancel.
- Duplicate execution after approval is prevented.

---

## Phase 4 — Semantic Memory Upgrade

### Objective

Make memory structured, relevant, transparent, and controllable.

### Scope

- Memory types
- Memory metadata
- Semantic retrieval
- pgvector support
- Memory ranking
- Deduplication
- Expiration
- Consolidation
- Sensitive-memory approval
- Memory Vault improvements
- Supabase migrations

### Acceptance Criteria

- Existing memories are preserved.
- Only relevant memories are retrieved.
- User-specific RLS is verified.
- Users can inspect, edit, and delete memories.
- Sensitive data is not stored silently.
- Destructive migrations are not run automatically.

---

## Phase 5 — Context Awareness

### Objective

Provide Friday with relevant real-time context.

### Scope

- Time provider
- Timezone provider
- Battery provider
- Network provider
- Memory provider
- Pending-task provider
- Context selector
- Context redaction
- Freshness metadata
- User-facing context explanation

### Acceptance Criteria

- Provider failure does not break the request.
- Context is selected by intent.
- Sensitive context is redacted unless needed.
- Context sources and freshness are recorded.
- Debug context is available only in development mode.

---

## Phase 6 — Multi-Step Planning

### Objective

Allow Friday to handle complex requests safely.

### Scope

- TaskPlan model
- TaskStep model
- Dependency graph
- Structured JSON planning
- Plan validation
- Circular-dependency detection
- Step confirmation
- Partial success
- Retry
- Cancellation
- Persistence and resumption
- Plan timeline UI

### Acceptance Criteria

- Plans use only registered tools.
- Unknown tools are rejected.
- Circular dependencies are rejected.
- Sensitive steps pause for approval.
- Failed steps can be retried.
- Tasks can resume after restart where safe.
- Private chain-of-thought is not shown.

---

## Phase 7 — Native Android Bridge

### Objective

Enable Android-specific actions through Kotlin.

### Scope

- Flutter MethodChannel
- Application opening
- Battery state
- Network state
- Biometric authentication
- Permission-status checking
- Android-version handling
- Structured native responses

### Acceptance Criteria

- Unsupported capabilities fail gracefully.
- Android permissions follow least privilege.
- No hidden accessibility control is implemented.
- Debug APK builds successfully.
- Manual test instructions are documented.

---

## Phase 8 — Automation and Sentinel 2.0

### Objective

Upgrade routines into proactive automations.

### Scope

- Trigger engine
- Condition engine
- Action engine
- Automation runner
- Cooldowns
- Retry policies
- Execution history
- Workmanager integration
- Foreground-service interfaces
- Automation builder UI
- Sample automations

### Acceptance Criteria

- Automations can be enabled and disabled.
- Last run and next run are shown.
- Notification loops are prevented.
- Sensitive actions require approval.
- Workmanager is used only for suitable tasks.
- Continuous hidden background execution is not used.

---

## Phase 9 — Voice Experience Upgrade

### Objective

Make Friday feel responsive and natural.

### Scope

- Voice state machine
- Partial transcripts
- Barge-in
- TTS interruption
- Voice cancellation
- Speech retry
- Local command routing
- Orb synchronization
- Streaming-ready architecture

### Acceptance Criteria

- Microphone sessions do not overlap.
- TTS responses do not overlap.
- Users can interrupt Friday while speaking where supported.
- Simple commands can avoid Groq.
- Voice errors provide clear recovery.
- Orb state accurately represents voice state.

---

## Phase 10 — Task, Approval, and Explainability UI

### Objective

Make agent behaviour understandable.

### Scope

- Live task status
- Plan timeline
- Approval sheet
- Tool result cards
- Failure recovery
- Context explanation
- Memory source indicators
- Automation status
- Debug diagnostics

### Acceptance Criteria

- Users can see what Friday is doing.
- Users can cancel tasks.
- Users can edit sensitive actions before approval.
- Verified success is clearly marked.
- Failed steps show retry actions.
- Existing holographic style is preserved.
- UI works on small Android devices.

---

## Phase 11 — Reliability, Caching, and Recovery

### Objective

Prepare the application for stable daily use.

### Scope

- Structured logging
- Redaction
- Request and task IDs
- Retry policies
- Exponential backoff
- Offline detection
- Idempotency
- Circuit breakers
- Response validation
- Task persistence
- Safe resumption
- Query caching
- Token optimization
- Diagnostics screen

### Acceptance Criteria

- External failures do not crash the app.
- Duplicate sensitive actions are prevented.
- Malformed model output is handled safely.
- Logs do not expose secrets.
- Eligible tasks resume safely.
- Existing token limits remain functional.

---

## Phase 12 — Security Hardening

### Objective

Complete a full security review before release.

### Scope

- Secrets
- Authentication
- RLS
- Memory privacy
- Android permissions
- Native channels
- Tool validation
- Confirmation system
- Biometric protection
- Logging
- Account deletion
- Threat modelling

### Deliverables

- `docs/security_audit.md`
- `docs/threat_model.md`
- `docs/privacy_model.md`
- `docs/known_security_limitations.md`

### Acceptance Criteria

- No hardcoded secrets exist.
- No service-role key exists in the client.
- RLS protects user data.
- Sensitive actions require approval.
- Tool calls are validated.
- Model output is treated as untrusted.
- Remaining risks are documented honestly.

---

## Phase 13 — Testing and Release Readiness

### Objective

Validate all integrated features.

### Scope

- Unit tests
- Widget tests
- Integration tests
- Android emulator testing
- Physical-device testing
- Voice testing
- Supabase testing
- Tool testing
- Automation testing
- Security testing
- Failure testing
- Debug APK build
- Documentation updates

### Deliverables

- `docs/test_report.md`
- `docs/manual_testing_checklist.md`
- `docs/supported_capabilities.md`
- `docs/current_limitations.md`
- Updated README
- Android setup guide
- Supabase setup guide

### Acceptance Criteria

- Flutter analysis passes.
- All critical tests pass.
- Debug APK builds successfully.
- Unsupported features are clearly labelled.
- No placeholder is marked complete.
- Known bugs and limitations are documented.
- Release candidate is manually tested.

---

# 14. Suggested Release Milestones

## Milestone A — Reliable Tool-Using Friday

Includes Phases 0–3.

Friday can:

- Understand simple intents
- Select registered tools
- Perform safe actions
- Ask for approval
- Verify results

## Milestone B — Context-Aware Personal Friday

Includes Phases 4–6.

Friday can:

- Retrieve relevant memories
- Understand current context
- Create multi-step plans
- Resume incomplete tasks

## Milestone C — Android Automation Friday

Includes Phases 7–10.

Friday can:

- Perform supported Android actions
- Run proactive automations
- Handle richer voice interaction
- Display task and approval timelines

## Milestone D — Stable Portfolio Release

Includes Phases 11–13.

Friday has:

- Recovery and caching
- Security hardening
- Complete testing
- APK build
- Setup documentation
- Known-limitations report

---

# 15. Success Metrics

## Functional Metrics

- At least 90% intent-routing accuracy for supported test commands
- 100% rejection of unregistered tools
- 100% confirmation enforcement for Level 2 and Level 3 actions
- 100% structured results for registered tools
- At least 95% successful execution for supported local tools
- No duplicate sensitive action in retry tests
- Successful task recovery for eligible persisted tasks
- Relevant memory retrieval without loading all stored memories

## Performance Metrics

- Local command routing begins within 500 milliseconds where possible
- UI state changes appear immediately
- No blocking of the Flutter UI thread during AI or tool execution
- Context providers time out independently
- Smooth animation on the primary target Android device

## Security Metrics

- Zero hardcoded production secrets
- Zero service-role keys in the client
- User-specific RLS enabled for private tables
- Zero sensitive actions executed without required approval
- Sensitive values removed from logs
- Model-generated tool calls validated before execution

## User Experience Metrics

- User can understand the current agent state
- User can cancel a running task
- User can edit an action before approval
- User can inspect and delete memories
- User can identify why Friday used a memory or context source
- Failures include a clear recovery action

---

# 16. Testing Requirements

The following areas must be tested:

- Authentication
- Token limits
- Voice input
- Voice output
- Intent routing
- Memory retrieval
- Context selection
- Tool registration
- Tool validation
- Tool execution
- Permission policies
- Confirmation flow
- Biometric flow
- Multi-step plans
- Plan resumption
- Task cancellation
- Automation triggers
- Automation cooldowns
- Native Android bridge
- Offline behaviour
- Groq failure
- Tavily failure
- Supabase failure
- Malformed JSON
- Duplicate actions
- Android permissions
- UI states
- Memory deletion
- Account deletion

---

# 17. Risks and Mitigations

## Risk: Existing Brain Service Is Too Tightly Coupled

**Mitigation:** Wrap it first. Extract responsibilities incrementally.

## Risk: Android Background Restrictions

**Mitigation:** Use Workmanager only for deferrable tasks and foreground services only when justified.

## Risk: Model Hallucinates Tools

**Mitigation:** Use a strict Tool Registry and reject unknown tools.

## Risk: False Success Messages

**Mitigation:** Require structured tool results and verification.

## Risk: Excessive Memory Context

**Mitigation:** Use semantic retrieval and context selection.

## Risk: Privacy Exposure

**Mitigation:** Apply RLS, redaction, permission checks, and memory controls.

## Risk: Duplicate Sensitive Actions

**Mitigation:** Use request IDs, task IDs, confirmation tokens, and idempotency keys.

## Risk: High API Usage

**Mitigation:** Use deterministic local routing, caching, and token limits.

## Risk: Large Refactor Breaks Existing Features

**Mitigation:** Implement phase by phase with tests and migration checkpoints.

---

# 18. Definition of Done

A phase is complete only when:

- Required functionality is implemented.
- Flutter analysis passes.
- Relevant unit tests pass.
- Relevant widget or integration tests pass.
- Existing features continue working.
- No critical security issue is introduced.
- Documentation is updated.
- Unfinished integrations are clearly labelled.
- Placeholder logic is not marked complete.
- Modified files are reported.
- Known limitations are documented.

---

# 19. Final Product Definition

Friday Assistant Version 2 will be considered successful when it can:

1. Understand voice and text requests.
2. Classify requests reliably.
3. Retrieve relevant memories.
4. Collect only required context.
5. Create safe structured plans.
6. Execute only registered tools.
7. Ask for confirmation before sensitive actions.
8. Use biometric verification for critical actions.
9. Verify results before reporting success.
10. Perform supported Android actions.
11. Run proactive automations within Android restrictions.
12. Recover from eligible failures and interruptions.
13. Explain which context and memories influenced its actions.
14. Protect user privacy.
15. Clearly report limitations and unsupported actions.

The implementation must remain realistic, secure, modular, and fully controlled by the user.
