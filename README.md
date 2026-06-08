# Blitztext App - Local AI Fork

This is a local-first, more capable fork of the original open-source Blitztext macOS menubar app. It extends Blitztext from a simple speech-to-text workflow into a dictation, instruction, rewrite, and local AI assistant for everyday writing on macOS.

The fork keeps the original spirit of a hackable native AI workflow, but pushes it further: a redesigned interface, a live dictation pill, clearer error and fallback states, local LLM support via Ollama, smarter rewrite modes, vocabulary learning, and prototype context-aware prompting.

> Fork status: actively developed local AI edition. Bring your own OpenAI API key for cloud workflows, or use local models where supported. No hosted backend, no warranty, no support guarantee.

## What Makes This Fork Different

- **Redesigned macOS UI**: clearer menubar structure, improved settings layout, better mode cards, and a more production-grade visual system.
- **Live dictation pill**: visible recording, processing, fallback, and error states with clearer keyboard hints and copy/paste affordances.
- **Local LLM support**: use Ollama-backed local rewrite models instead of relying only on the OpenAI API.
- **Local model manager**: browse, download, delete, and inspect local models with hardware-aware recommendations.
- **Configurable rewrite modes**: duplicate, rename, reorder, delete, and tune modes for different people, clients, or writing contexts.
- **Rebindable global hotkeys**: configure mode-specific shortcuts and see conflicts before they bite.
- **Smarter rewrite modes**: dedicated modes for improving text, writing emails, optimizing prompts, and turning rough speech into calmer messages.
- **Semantic email memory**: opt-in local vector memory can retrieve similar earlier email drafts and use them as background context.
- **Two-version preview**: rewrite modes can pause in the floating pill and let you choose which variant to insert.
- **Better default system prompts**: each mode has a more precise prompt structure and clearer behavior expectations.
- **Dictated instructions**: workflows can distinguish spoken instructions from text that should be inserted verbatim.
- **Vocabulary and memory system**: frequently used names, domain terms, and custom wording can be learned and injected into future prompts.
- **Prototype context awareness**: the app can include focused-window, selected-text, semantic email-memory, file, and content-type hints in prompts.
- **More private by default**: local transcription, local rewrite options, fail-closed offline behavior, and opt-in archive/memory features.
- **More robust workflow**: improved paste reliability, Accessibility fallback behavior, code signing, onboarding, and test coverage.

## What It Does

- **Dictate**: record speech and transcribe it into text.
- **Improve**: turn rough dictated text into cleaner writing.
- **Write email**: transform spoken notes into a structured email draft.
- **Optimize prompts**: convert rough intent into a clearer prompt for AI tools.
- **Calm down**: turn frustrated speech into a calmer, usable message.
- **Create custom modes**: keep separate prompts, hotkeys, model choices, memory settings, and enrichment levels for different writing situations.
- **Use local AI**: run supported transcription and rewrite workflows locally when compatible models are installed.

## Important Preview Notes

- macOS only.
- Bring your own OpenAI API key for cloud workflows.
- Install Ollama and local models for local rewrite workflows.
- No hosted Blitztext backend is included or provided.
- In online mode, audio and text are sent directly from the app to the OpenAI API.
- Local transcription via WhisperKit/CoreML is supported when a compatible model is installed.
- Local rewrite workflows are supported through Ollama-backed models where available.
- `./build.sh` creates a locally ad-hoc-signed development app. No notarized release binary is provided.
- Still experimental and not production ready.
- No warranty and no support guarantee.

You are welcome to use, fork, adapt, and share this project under the license terms.

The intent is not to ship a one-click finished app. The intent is to make a more capable local-first AI workflow understandable: clone it, build it, read the code, change it, break it, fix it, and suggest improvements. If you want to learn how a small native macOS AI app can combine dictation, local models, rewrite modes, memory, and context, this fork is the most complete version of that direction.

## Screenshots

<table>
  <tr>
    <td><img src="docs/screenshots/online-mode.png" alt="Blitztext online transcription mode" width="420"></td>
    <td><img src="docs/screenshots/local-mode.png" alt="Blitztext secure local transcription mode" width="420"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/local-model-picker.png" alt="Blitztext local model picker" width="420"></td>
    <td><img src="docs/screenshots/settings-customize.png" alt="Blitztext settings and customization view" width="420"></td>
  </tr>
</table>

## Requirements

- macOS 14 or newer
- Xcode 16 or newer (Swift 5.10), with Command Line Tools installed and selected for `xcodebuild`
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project
- For online transcription and rewriting: an OpenAI API key with access to:
  - `whisper-1` for transcription
  - `gpt-4o-mini` and optionally `gpt-4o` for rewriting
- For local-only transcription: a WhisperKit CoreML model in:
  `~/Library/Application Support/Blitztext/models/whisperkit/`
- For local rewriting: [Ollama](https://ollama.com/) with at least one compatible local LLM installed.
- For semantic email memory: Ollama running locally with an embedding model such as `nomic-embed-text`.

The build also pulls one Swift Package dependency automatically:

- [`argmax-oss-swift`](https://github.com/argmaxinc/argmax-oss-swift) (WhisperKit) — used for local on-device transcription.

Install XcodeGen if needed:

```bash
brew install xcodegen
```

## Build And Run

```bash
git clone https://github.com/aslomon/blitztext-app.git
cd blitztext-app
./build.sh --run
```

For a local install into `/Applications`:

```bash
./build.sh --install --run
```

The generated `.app` is ad-hoc signed for local development only. Do not treat it as a trusted redistributable binary. A public binary release would need Developer ID signing and notarization.

On first launch, either paste your own OpenAI API key for online workflows or install local models for local transcription and rewriting.

For a local-first setup, install a WhisperKit CoreML model, install an Ollama model through the local model manager, and enable **Sicherer Lokaler Modus** in the app.

For a slower, more explicit walkthrough, see [docs/setup.md](docs/setup.md).

## Permissions

Blitztext asks for:

- **Microphone**: to record your voice.
- **Accessibility**: to paste the result back into the app you were using.

If you do not grant Accessibility permission, you can still copy results manually.

Full Disk Access is not required. If auto-paste does not work even though transcription succeeds, open **System Settings -> Privacy & Security -> Accessibility**, enable Blitztext there, restart Blitztext, and try again with the cursor focused in a text field. If macOS shows multiple Blitztext entries, remove or disable the old ones and grant the permission to the app you just built or installed.

## Data Flow

The preview has no custom backend.

```text
Online transcription: Your Mac -> OpenAI Audio Transcriptions API
Online rewriting:     Your Mac -> OpenAI Chat Completions API
Local transcription:  Your Mac -> WhisperKit/CoreML on device
Local rewriting:      Your Mac -> Ollama model on device
Email embeddings:     Your Mac -> Ollama embedding model on device
```

The app stores your OpenAI API key in the user's macOS Keychain.

Read [docs/privacy.md](docs/privacy.md) before using the preview with sensitive content.

## Project Structure

```text
BlitztextMac/
  App/          App lifecycle, paste handling, model window wiring
  Features/     Workflows, menubar UI, onboarding, settings, local model UI
  Services/     Recording, providers, hotkeys, local storage, context services
  Tests/        Swift tests for workflows, onboarding, and context behavior
build.sh        Local build and signing script
docs/           Setup, privacy, roadmap, preflight, and planning notes
```

## Local Models

Local transcription is available through WhisperKit/CoreML, and local rewriting is available through Ollama-backed LLMs. The app does not bundle models; use the local model manager to inspect your hardware, choose suitable models, download them, and switch to the local workflow from the menubar or settings.

See [docs/local-models.md](docs/local-models.md).

## Contributing

Contributions are welcome, especially if they make the preview easier to build, understand, or fork.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## Support And Roadmap

This preview has no formal support promise. See [SUPPORT.md](SUPPORT.md) for how to ask for help without sharing secrets.

The current direction is documented in [ROADMAP.md](ROADMAP.md). Maintainer-facing release checks live in [docs/open-source-preflight.md](docs/open-source-preflight.md).

## License

Code is released under the MIT License. See [LICENSE](LICENSE).

Project names, logos, and app icons are not automatically granted as trademarks or brand assets. See [TRADEMARKS.md](TRADEMARKS.md).

## Legal / Impressum & Datenschutz

This is an experimental, non-commercial open-source project, provided as-is under the MIT License without warranty or support. Nothing is sold here and no installation or operation is performed on your behalf.

The companion website (blitztext.de) is operated by Blackboat Internet GmbH:

- Impressum: https://www.blackboat.com/impressum
- Datenschutz / Privacy: https://www.blackboat.com/datenschutz
