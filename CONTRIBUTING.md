# Contributing to ReToken

## Project Intent

ReToken is a macOS menu bar application for tracking AI account usage, token burn, and recent activity across providers such as Claude, Gemini, and OpenAI/Codex.

The app should feel native to macOS, stay privacy-conscious, and keep provider integration logic separated from UI code.

## Platform Rules

- Target platform is macOS only
- Default UI framework is `AppKit`
- Use `SwiftUI` only for final leaf views that are clearly self-contained and embedded from AppKit
- Do not rewrite AppKit screens into SwiftUI without explicit approval
- Keep provider logic, storage, and parsing out of view controllers

This is not a cross-platform app. Optimize for native macOS behavior first.

---

## Git Policy

### Branches

| Branch | Purpose |
|--------|---------|
| `main` | Stable branch. Release-ready only. Never push directly. |
| `dev` | Integration branch for completed work. |
| `phase/N-topic` | Phase work, for example `phase/0-foundation` |
| `feat/topic` | Isolated feature work |
| `fix/topic` | Bug fixes |

Always branch from `dev`, never from `main`.

```bash
git checkout dev
git checkout -b phase/0-foundation
```

### Commit Messages

Use lowercase, present tense, and conventional-commit style:

```bash
feat: add status item controller
fix: prevent menu refresh overlap
docs: add provider integration rules
refactor: extract usage polling service
test: add parser fixtures for openai usage payloads
```

Rules:

- No trailing period
- Keep subject line under 72 characters
- Add a body only when the context is not obvious
- AI agents must not create commits without explicit approval

### Merge Rules

- Do not force-push `dev` or `main`
- Do not rebase shared branches
- Prefer normal merges unless the user asks otherwise

---

## Directory Layout

Current structure:

```text
ReToken/
├── CONTRIBUTING.md
├── PLAN.md
└── ReToken/
    ├── ReToken.xcodeproj/
    └── ReToken/
        ├── AppDelegate.swift
        └── ViewController.swift
```

Target structure as the app grows:

```text
ReToken/
├── CONTRIBUTING.md
├── PLAN.md
└── ReToken/
    ├── ReToken.xcodeproj
    └── ReToken/
        ├── AppDelegate.swift
        ├── Infrastructure/
        │   ├── AppBootstrap/
        │   ├── Persistence/
        │   ├── Networking/
        │   └── Keychain/
        ├── MenuBar/
        │   ├── StatusItem/
        │   ├── Menus/
        │   └── Panels/
        ├── Providers/
        │   ├── OpenAI/
        │   ├── Anthropic/
        │   └── Gemini/
        ├── Domain/
        │   ├── Usage/
        │   ├── Accounts/
        │   └── Activity/
        ├── Features/
        │   ├── Dashboard/
        │   ├── AccountDetails/
        │   └── RecentActivity/
        ├── Resources/
        └── Supporting/
```

Organize primarily by feature or domain boundary, not by dumping everything into controllers.

---

## AppKit Conventions

### Preferred Architecture

- `AppDelegate` handles application lifecycle and high-level startup only
- Menu bar setup belongs in a dedicated status item coordinator/controller
- Use dedicated controllers for panels, menus, and windows
- Keep model parsing and polling in services
- Use protocols at provider boundaries

### UI Guidance

- Default to `NSStatusItem`, `NSMenu`, `NSPopover`, `NSPanel`, and `NSWindowController`
- Use `NSHostingView` only when embedding a small leaf SwiftUI view is materially simpler
- Avoid putting networking, persistence, or parsing in view/controller classes
- Avoid storyboard sprawl; if storyboard friction grows, prefer programmatic AppKit for new screens

### Naming

| Item | Convention |
|------|-----------|
| Types | `PascalCase` |
| Variables, functions, properties | `camelCase` |
| Files | Match primary type name |
| Constants | `camelCase` unless true global/static constants justify otherwise |

Examples:

- `StatusItemController.swift`
- `ProviderUsagePoller.swift`
- `UsageSnapshotStore.swift`
- `RecentActivityPanelController.swift`

---

## Integration Rules

Provider integrations must be isolated and explicit.

- One provider namespace per vendor
- Normalize upstream payloads into shared domain models
- Preserve vendor-specific fields when they matter
- Treat account usage, token usage, and recent activity as separate data products
- Prefer official APIs first
- If local scraping or CLI parsing is required, isolate it behind a provider adapter and mark it clearly in code

Do not let one provider's assumptions leak into another provider's models.

---

## Privacy and Security

- Store secrets in Keychain, not plaintext files
- Cache only the minimum data needed for display and history
- Do not log tokens, API keys, or full conversation content unless that behavior is explicitly designed and approved
- If reading local CLI state or transcripts, document the source and permission expectations
- Be conservative about macOS entitlements and sandbox scope

---

## Testing

- Unit test domain logic, parsers, and polling transformations first
- Add fixture-based tests for provider payloads and CLI output parsing
- Add smoke coverage for status item/menu state transitions when practical
- Name tests after behavior, for example `parses_openai_daily_usage` or `renders_exhausted_weekly_state`

Priority order:

1. Provider parsing and normalization
2. Persistence and caching behavior
3. Menu state derivation
4. UI controller behavior

---

## Build and Run

Run from the Xcode project unless a CLI workflow is added later.

Preferred local workflow:

```bash
open /Users/ryancummins/Developer/ReToken/ReToken/ReToken.xcodeproj
```

When an `xcodebuild` workflow is added, document the exact commands here.

---

## Documentation Rules

- Update `PLAN.md` whenever phase status changes
- Update `CONTRIBUTING.md` when architecture or workflow rules change
- Capture non-trivial provider/API decisions in committed docs, not only in chat

---

## Current Development Priorities

1. Establish AppKit menu bar shell and app lifecycle
2. Define domain models for usage, account state, and recent activity
3. Implement provider adapters with mock data first
4. Add persistence and refresh scheduling
5. Add real provider integrations incrementally
