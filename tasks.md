# Tasks: Dynamic Modes, Email Memory, Variant Selection

Generated from: user-approved autonomous sprint request + `docs/BACKLOG.md`
Date: 2026-06-08

## Sprint Map

- Sprint 1: Dynamic mode foundation (`FT-2`) and compatibility migration.
- Sprint 2: Rebindable global hotkeys (`DR-1`) for dynamic modes.
- Sprint 3: Semantic email memory foundation using local embeddings.
- Sprint 4: Email enrichment controls and prompt injection.
- Sprint 5: Two-variant generation and pill selection (`R3-FT-preview`).
- Sprint 6: End-to-end hardening, UX polish, verification, and backlog cleanup.

## Sprint 1: Dynamic Mode Foundation

- [x] [T-001] [P1] Add stable `ModeID` and dynamic-mode collection types — blocks: T-003, T-004
- [x] [T-002] [P1] Add Codable migration tests for legacy slot-keyed `AppSettings.modes` — blocks: T-003
- [x] [T-003] [P1] Migrate settings from fixed slot dictionary to ordered dynamic mode list — blocked by: T-001, T-002
- [x] [T-004] [P1] Route display names, availability, and start workflow through dynamic mode records — blocked by: T-001, T-003
- [x] [T-005] [P1] Update menu bar and Prompts settings to render dynamic mode records — blocked by: T-004
- [x] [T-006] [P2] Add duplicate, delete, reorder, and reset actions for user-created modes — blocked by: T-005
- [x] [T-007] [P2] Preserve archive/stat labels for migrated legacy modes — blocked by: T-003

## Sprint 2: Rebindable Hotkeys

- [x] [T-008] [P1] Add `HotkeyConfig` model and Codable migration for existing fn-combos — blocks: T-009, T-010
- [x] [T-009] [P1] Add pure shortcut matching tests for modifiers, key codes, hold/toggle behavior — blocked by: T-008
- [x] [T-010] [P1] Refactor `HotkeyService` to dispatch by `ModeID` from stored configs — blocked by: T-008, T-009
- [x] [T-011] [P1] Update app delegate hotkey handling to start/stop dynamic modes — blocked by: T-010
- [x] [T-012] [P2] Build shortcut recorder UI in mode cards — blocked by: T-010
- [x] [T-013] [P2] Add conflict detection and reserved-combo warnings — blocked by: T-012

## Sprint 3: Semantic Email Memory Foundation

- [x] [T-014] [P1] Add local `OllamaEmbeddingProvider` for `/api/embed` with fixture-backed tests — blocks: T-016
- [x] [T-015] [P1] Add `SemanticMemoryStore` with secure JSON persistence and retention caps — blocks: T-016, T-017
- [x] [T-016] [P1] Implement cosine retrieval over stored normalized embeddings — blocked by: T-014, T-015
- [x] [T-017] [P1] Ingest completed rewrite/archive runs into semantic memory when opted in — blocked by: T-015
- [x] [T-018] [P2] Add email/context metadata extraction heuristics for app/window/title/mode — blocked by: T-017
- [x] [T-019] [P2] Surface embedding model setup/status in local model settings — blocked by: T-014

## Sprint 4: Email Enrichment Controls

- [x] [T-020] [P1] Extend `RewriteConfig` with semantic memory toggle and enrichment level — blocks: T-021, T-022
- [x] [T-021] [P1] Add prompt tests for light/medium/strong retrieval budgets — blocked by: T-020
- [x] [T-022] [P1] Inject retrieved email memories into E-Mail rewrite prompts with anti-invention rules — blocked by: T-016, T-020, T-021
- [x] [T-023] [P2] Add enrichment control UI to E-Mail mode cards — blocked by: T-020, T-022
- [x] [T-024] [P2] Add privacy copy and clear semantic memory action — blocked by: T-015, T-023

## Sprint 5: Two-Variant Pill Selection

- [x] [T-025] [P1] Extend rewrite outcomes to carry one or more variants — blocks: T-026, T-027
- [x] [T-026] [P1] Add tests for single-result auto-paste versus variant-choice pause — blocked by: T-025
- [x] [T-027] [P1] Add `variantChoice` pill phase and model state — blocked by: T-025, T-026
- [x] [T-028] [P1] Implement variant card UI with insert/copy/dismiss actions — blocked by: T-027
- [x] [T-029] [P2] Add per-mode "show two versions" setting — blocked by: T-025, T-028
- [x] [T-030] [P2] Add failure/fallback behavior when one variant fails — blocked by: T-025

## Sprint 6: Hardening And Release Readiness

- [x] [T-031] [P1] Run full build/test verification and fix failures — blocked by: T-001...T-030
- [x] [T-032] [P1] Run security/code review and fix findings — blocked by: T-031
- [x] [T-033] [P1] Update `DESIGN.md`, `README.md`, and `docs/BACKLOG.md` to match shipped behavior — blocked by: T-032
- [x] [T-034] [P2] Add manual QA checklist for hotkeys, variants, and email memory privacy states — blocked by: T-031

## Progress

- [x] Sprint 1: 7/7
- [x] Sprint 2: 6/6
- [x] Sprint 3: 6/6
- [x] Sprint 4: 5/5
- [x] Sprint 5: 6/6
- [x] Sprint 6: 4/4
- Total: 34/34
