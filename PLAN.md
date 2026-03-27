# ReToken Development Plan

## Status Summary

- Current date: 2026-03-27
- Project state: repo initialized, AppKit menu bar shell bootstrapped, local Claude/Codex ingestion added, GRDB-backed telemetry tracking and leaderboards added, XCTest coverage expanded
- Active architecture direction: AppKit-first macOS menu bar app
- SwiftUI policy: leaf views only, embedded from AppKit when justified
- Current progress: phase 0 through 3 complete, phases 4, 5, 6, and 7 in progress

## Progress Tracker

| Phase | Name | Status | Progress |
|------|------|--------|----------|
| 0 | Foundation and architecture | Completed | 100% |
| 1 | Menu bar shell and local state | Completed | 100% |
| 2 | Domain models and persistence | Completed | 100% |
| 3 | Provider adapters with mocks | Completed | 100% |
| 4 | Real usage integrations | In progress | 70% |
| 5 | Recent activity aggregation | In progress | 75% |
| 6 | Account surfaces and polish | In progress | 35% |
| 7 | Hardening and release prep | In progress | 50% |

## Completed So Far

- [x] Create initial Xcode AppKit macOS project
- [x] Initialize git repository on `main`
- [x] Add root `.gitignore` for Xcode/macOS artifacts
- [x] Establish contribution rules tailored to ReToken
- [x] Define phase-based plan with explicit tracking
- [x] Convert default app scaffold into menu bar architecture
- [x] Add placeholder AppKit status item and dashboard window
- [x] Add shared placeholder domain models
- [x] Add an app-owned shared snapshot controller
- [x] Bind the menu bar and dashboard to the same state source
- [x] Add lightweight JSON persistence for the last-known-good snapshot
- [x] Introduce provider adapter and mock provider implementations
- [x] Refresh app state from adapters during startup
- [x] Add stale-cache metadata to restored snapshots
- [x] Add a persisted mock/live provider mode toggle
- [x] Surface provider issues in shared state and UI
- [x] Add first live OpenAI/Codex usage adapter
- [x] Add keychain-backed OpenAI credential storage and editing UI
- [x] Add automatic background refresh with persisted cadence
- [x] Add first XCTest target with regression coverage for formatter, composition, and OpenAI parsing
- [x] Add live Claude local history and token-stat ingestion
- [x] Add live Codex local thread and token ingestion from on-disk state
- [x] Add fixture-based parser tests for Claude and Codex local sources
- [x] Add persisted local activity history with stable activity identifiers
- [x] Add persistence regression tests for activity merge and deduplication
- [x] Add GRDB-backed telemetry storage for usage samples and activity history
- [x] Surface tracked usage summary in the AppKit menu and dashboard
- [x] Add GRDB-backed personal leaderboard summaries
- [x] Add leaderboard surfaces to the menu bar and dashboard
- [x] Replace temporary debug launch scaffolding and restore menu bar accessory mode
- [x] Refresh the dashboard into a more intentional card-style AppKit layout

---

## Phase 0: Foundation and Architecture

Status: Completed

Goals:

- Replace default window-app assumptions with menu bar app assumptions
- Define the initial folder layout
- Introduce a dedicated status item coordinator
- Decide where mock data, provider adapters, and persistence will live
- Keep AppKit as the default UI layer

Deliverables:

- `CONTRIBUTING.md`
- `PLAN.md`
- Initial source layout under the app target
- Basic architecture notes captured in code and docs

Exit criteria:

- Repo has stable structure for new files
- Menu bar ownership is not sitting in `ViewController`
- App startup path is clear and documented

Checklist:

- [x] Add repo-specific contribution guide
- [x] Add phase tracker
- [x] Create app structure folders
- [x] Add `StatusItemController`
- [x] Add `AppCoordinator`
- [x] Remove dependence on the default generated `ViewController` design

---

## Phase 1: Menu Bar Shell and Local State

Status: Completed

Goals:

- Create a working `NSStatusItem`
- Show a stable title or icon in the menu bar
- Add an `NSMenu` with placeholder sections
- Add manual refresh and quit actions
- Support opening a detail panel or popover

Deliverables:

- Status item controller
- Menu composition layer
- Placeholder dashboard panel

Exit criteria:

- App launches without a standard main window requirement
- Menu bar item is stable and responsive
- Placeholder usage state can be rendered from local mock data

Checklist:

- [x] Hide dock presence if appropriate for the product direction
- [x] Add status item setup
- [x] Add menu sections for usage, accounts, recent activity, and app actions
- [x] Add mock refresh action
- [x] Add placeholder detail panel

---

## Phase 2: Domain Models and Persistence

Status: Completed

Goals:

- Define shared models for usage, account summary, provider status, and recent activity
- Add lightweight persistence for cached snapshots
- Define refresh timestamps and failure states

Deliverables:

- Shared domain models
- Snapshot store
- Error/loading state handling

Exit criteria:

- UI can bind against stable internal models rather than raw payloads
- Last-known-good state survives app restart

Checklist:

- [x] Define `ProviderKind`
- [x] Define `UsageSnapshot`
- [x] Define `AccountSnapshot`
- [x] Define `RecentActivityItem`
- [x] Add local snapshot persistence
- [x] Add cache invalidation rules

---

## Phase 3: Provider Adapters With Mocks

Status: Completed

Goals:

- Establish provider adapter protocol
- Implement mock adapters for OpenAI/Codex, Anthropic/Claude, and Gemini
- Exercise UI flows before wiring real integrations

Deliverables:

- `ProviderAdapter` protocol
- Mock adapters
- Mock data fixtures

Exit criteria:

- Menu and detail UI can render realistic multi-provider states
- App supports disconnected development without live credentials

Checklist:

- [x] Define adapter interface
- [x] Add mock OpenAI adapter
- [x] Add mock Anthropic adapter
- [x] Add mock Gemini adapter
- [x] Add development toggle for mock mode

---

## Phase 4: Real Usage Integrations

Status: In progress

Goals:

- Add real usage/account integrations incrementally
- Normalize usage into shared models
- Capture auth and failure cases cleanly

Deliverables:

- First real provider integration
- Keychain-backed secrets or local auth discovery where appropriate
- Error handling and retry behavior

Exit criteria:

- At least one provider returns live usage data end-to-end
- Failure states are visible and non-destructive

Recommended order:

1. OpenAI/Codex usage
2. Claude usage
3. Gemini usage

Checklist:

- [x] Add provider auth abstraction
- [x] Add first live provider
- [x] Add polling schedule
- [ ] Add stale data indicators
- [ ] Add per-provider error messaging

---

## Phase 5: Recent Activity Aggregation

Status: In progress

Goals:

- Define what "recent conversations" means per provider
- Support official APIs where available
- Fall back to local capture or local history parsing where necessary
- Keep the provenance of activity items explicit

Deliverables:

- Recent activity model
- Source attribution per activity item
- Unified recent activity UI section

Exit criteria:

- The app can show recent activity without pretending every provider has the same primitives
- Users can tell whether activity came from API data, local CLI logs, or cached app history

Checklist:

- [x] Classify activity sources
- [x] Add local activity store
- [x] Add provider-specific activity mappers
- [x] Add recent activity menu section
- [x] Persist activity history in GRDB
- [ ] Add expanded detail view

---

## Phase 6: Account Surfaces and Polish

Status: In progress

Goals:

- Show plan/account context per provider
- Make high usage feel visually intentional
- Improve menu readability and panel layout

Deliverables:

- Account summary surfaces
- Visual token-burn indicators
- Better loading/error affordances

Exit criteria:

- The app communicates both utility and delight
- High token usage is legible, not just numeric

Checklist:

- [ ] Add account metadata display
- [x] Add visual usage intensity treatment
- [ ] Add compact charts or bars
- [ ] Add better empty and error states
- [ ] Add settings for refresh cadence and providers
- [x] Add leaderboard-style self-comparison surfaces

---

## Phase 7: Hardening and Release Prep

Status: In progress

Goals:

- Improve reliability, entitlement hygiene, and startup behavior
- Add tests for fragile provider parsing paths
- Prepare for signing, sandbox review, and distribution

Deliverables:

- Regression coverage for parsing and persistence
- Release checklist
- Packaging and signing notes

Exit criteria:

- App can be built and validated reproducibly
- Provider failures do not destabilize the app

Checklist:

- [x] Add core unit test bundle
- [x] Add parser fixtures
- [x] Add persistence tests
- [x] Add GRDB telemetry tests
- [ ] Add menu state tests
- [ ] Review entitlements and sandbox
- [ ] Add release checklist
- [ ] Document packaging flow

---

## Risks and Constraints

- Provider data availability is uneven; "recent conversations" will not be uniformly available
- Local CLI parsing may be brittle and require fixture-based tests
- macOS menu bar UI becomes fragile if refresh and rendering ownership are not clearly separated
- AppKit/SwiftUI mixing should stay limited to leaf views to avoid split ownership

## Next Recommended Implementation Step

Continue Phase 6, Phase 5, and Phase 4 by hardening the local-first path:

1. Add compact chart or streak treatments on top of the GRDB usage history
2. Improve per-provider error messaging for stale Claude stats, missing Codex state, auth scope issues, and partial cost responses
3. Add persistence tests around cached snapshot restore and stale-state transitions
4. Add an expanded recent-activity detail view driven by the GRDB telemetry store
5. Start Gemini only after the local-provider path is stable
