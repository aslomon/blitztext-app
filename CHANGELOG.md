# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Mode System**: New configurable text rewriting modes (API-based + Apple Foundation Models) with curated email and prompt defaults
- **ModeConfig.swift**: Core mode model and mode registry with per-mode email templates and prompt settings
- **RewriteModelRegistry.swift**: Real OpenAI model IDs, dynamic `/v1/models` API client for model availability checking
- **RewriteProvider.swift**: Unified provider abstraction supporting OpenAI, Apple Foundation Models, and provider selection context
- **SelectionContextService.swift**: Captures selection context (filename, window title, content type) for intelligent prompt adaptation
- **ModeCardView.swift**: UI component for browsing and selecting rewriting modes with visual mode presentation
- **DESIGN.md**: Comprehensive architecture and design documentation covering mode system, provider implementations, and UI patterns
- **docs/PLAN-v2.md**: Implementation plan for Blitztext v2 with phased feature roadmap (stable signing, accessibility grants, local LLM, Prompts tab)
- **docs/PLAN-modi-und-features.md**: Detailed planning document for the mode system infrastructure and feature implementation
- **LLMError**: New error cases `modelUnavailable` and `localModelUnavailable` for better error handling and user feedback

### Changed

- **WorkflowProtocol.swift**: Extended with AppSettings support and mode management (`modes` property, `updateMode` handling)
- **AppState.swift**: Major refactoring to support mode infrastructure
  - Added mode state management and migrations
  - Integrated provider factory with backend gating
  - Implemented selection context capture
  - Updated all workflow instantiation to use provider-based approach
  - Code formatting: consistent indentation and import organization
- **LLMService.swift**: Refactored as provider-agnostic prompt builder
  - Removed OpenAI-specific request/response structs (moved to provider implementations)
  - New `rewriteSystemPrompt()` method supporting custom terms and selection context integration
  - Added default rewrite temperature constant (0.3)
  - Preserved system prompt builders for email, prompt, and generic improvement modes
- **DampfAblassenWorkflow.swift**: Migrated from hardcoded provider to dynamic provider selection
- **EmojiTextWorkflow.swift**: Migrated from hardcoded provider to dynamic provider selection
- **TextImprovementWorkflow.swift**: Migrated from hardcoded provider to dynamic provider selection
- **SettingsContentView.swift**: Added mode management UI with ModeCardView integration; code formatting improvements

### Fixed

- Provider selection now respects backend configuration and availability
- **Privacy fix**: Transcription now runs locally in secure offline mode using WhisperKit — audio no longer leaves the device
- **Fail-closed**: macOS < 26 with forced offline mode no longer silently falls back to OpenAI — strictly enforces local-only processing
- **Silent downgrade prevented**: Migration no longer forces `secureLocalModeEnabled=false` — user's offline choice is preserved
- **Default names**: Correct fallback names when selection context is unavailable
- **EditSelection guard**: `editSelection` workflow only activates with genuine text selection, not empty selections
- **Reply context path**: Cleaned up reply context path handling in workflow execution
- **Clipboard fallback**: Improved handling of auto-paste fallback mechanism
