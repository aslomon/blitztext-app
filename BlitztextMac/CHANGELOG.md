# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Configurable Modes & Hotkey System**: New workflow mode configuration system allowing users to customize mode names, prompts, and behavior via settings. Hotkey recording UI added to capture custom keyboard shortcuts for each mode.
- **HotkeyCaptureView & HotkeyRecorderView**: New UI components for recording and configuring global hotkeys with real-time capture feedback.
- **HotkeyService, HotkeyConfig, HotkeyKey**: Core hotkey handling infrastructure for monitoring and managing keyboard shortcuts system-wide.
- **ModeConfig**: Centralized workflow mode configuration with default presets and customization support.
- **RewriteVariantBuilder**: New utility for building rewrite operation variants.
- **Email Semantic Memory**: New `EmailSemanticMemoryStore` for semantic storage of email context and retrieval via embeddings.
- **OllamaEmbeddingProvider**: Support for local Ollama-based embeddings in addition to OpenAI embeddings.
- **Enhanced Tests**: New test coverage for hotkey configuration, email semantic memory, and mode configuration defaults.
- **Documentation**: Updated DESIGN.md with architectural clarifications; added docs for local models setup and privacy considerations; QA guidelines for email modes.

### Changed

- **AppState**: Significantly refactored to support mode configurability, hotkey management, and semantic memory integration. Now manages mode subscriptions and hotkey service lifecycle.
- **WorkflowProtocol**: Extended to support workflow configuration introspection and metadata.
- **ModeCardView & ModeCardAdvanced**: Enhanced UI for editing mode configurations, including prompt customization and hotkey assignment.
- **Settings UI**: Reorganized settings views to include SystemSettingsView, PromptsSettingsView, and improved separation of concerns.
- **MenuBar Integration**: Updated to work with configurable modes and hotkey system; added workflow row view enhancements.
- **Services Architecture**: LLMService and RewriteProvider enhanced with better provider handling and configuration support.
- **Memory System**: SelectionContextService and MemoryCoordinator updated to integrate semantic memory retrieval.

### Fixed

- Better handling of workflow state during mode configuration changes
- Improved robustness of hotkey registration and deregistration
- Enhanced error handling in semantic memory retrieval
- Fixed potential race conditions in hotkey service initialization

### Removed

- N/A
