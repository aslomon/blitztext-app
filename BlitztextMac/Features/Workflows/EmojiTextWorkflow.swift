import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class EmojiTextWorkflow: Workflow {
  let type = WorkflowType.emojiText
  var phase: WorkflowPhase = .idle {
    didSet { onPhaseChange?(phase) }
  }
  var onOutput: WorkflowOutputHandler?
  var onPhaseChange: WorkflowPhaseChangeHandler?
  var onRun: WorkflowRunHandler?

  private let recorder = AudioRecorder()
  private let rewrite: RewriteConfig
  private let provider: any RewriteProvider
  private let customTerms: [String]
  private let language: String
  private let backend: TranscriptionBackend
  private let localModelName: String
  private var processingTask: Task<Void, Never>?

  init(
    rewrite: RewriteConfig,
    provider: any RewriteProvider,
    customTerms: [String] = [],
    language: String = "de",
    backend: TranscriptionBackend = .remote,
    localModelName: String = LocalTranscriptionService.recommendedFastModelName
  ) {
    self.rewrite = rewrite
    self.provider = provider
    self.customTerms = customTerms
    self.language = language
    self.backend = backend
    self.localModelName = localModelName
  }

  // MARK: - Recording State

  var isRecording: Bool { recorder.isRecording }
  var audioLevel: Float { recorder.audioLevel }

  // MARK: - Workflow Protocol

  func start() {
    phase = .running("Aufnahme l\u{00E4}uft ...")
    recorder.startRecording()

    if let error = recorder.errorMessage {
      phase = .error(error)
    }
  }

  func stop() {
    if recorder.isRecording {
      recorder.stopRecording()
      guard
        !TranscriptionQualityService.shouldRejectRecording(duration: recorder.lastRecordingDuration)
      else {
        recorder.discardRecording()
        phase = .error("Keine Aufnahme erkannt.")
        return
      }
      processRecording()
    } else {
      processingTask?.cancel()
      phase = .idle
    }
  }

  func reset() {
    processingTask?.cancel()
    if recorder.isRecording {
      recorder.stopRecording()
    }
    recorder.discardRecording()
    phase = .idle
  }

  // MARK: - Two-Phase Processing: Transcribe -> Emoji

  private func processRecording() {
    guard let url = recorder.recordingURL else {
      phase = .error("Keine Aufnahme vorhanden.")
      return
    }

    phase = .running("Wird transkribiert ...")
    let recordingDuration = recorder.lastRecordingDuration
    let vocabularyHints = recordingDuration >= 0.9 ? customTerms : []

    processingTask = Task {
      defer {
        try? FileManager.default.removeItem(at: url)
      }

      do {
        let rawText: String
        switch backend {
        case .remote:
          rawText = try await TranscriptionService.transcribe(
            audioURL: url,
            customTerms: vocabularyHints,
            language: language
          )
        case .local:
          rawText = try await LocalTranscriptionService.shared.transcribe(
            audioURL: url,
            language: language,
            modelName: localModelName
          )
        }
        let cleanedRawText = TranscriptionQualityService.cleanedTranscript(rawText)
        guard
          !TranscriptionQualityService.isLikelyArtifact(
            cleanedRawText, recordingDuration: recordingDuration)
        else {
          phase = .error("Keine Aufnahme erkannt.")
          return
        }

        if Task.isCancelled { return }

        phase = .running("Emojis werden eingef\u{00FC}gt ...")

        let systemPrompt = LLMService.emojiSystemPrompt(rewrite)
        let result = try await provider.rewrite(
          systemPrompt: systemPrompt,
          userText: cleanedRawText,
          temperature: LLMService.defaultRewriteTemperature
        )
        let cleanedResult = TranscriptionQualityService.cleanedTranscript(result)
        guard cleanedResult != "KEINE_AUFNAHME_ERKANNT" else {
          phase = .error("Keine Aufnahme erkannt.")
          return
        }
        phase = .done(cleanedResult)
        onRun?(
          ArchiveRunRecord(
            mode: type,
            rawTranscript: cleanedRawText,
            finalText: cleanedResult,
            backend: backend,
            durationSec: recordingDuration
          )
        )
        onOutput?(cleanedResult)
      } catch {
        phase = .error(error.localizedDescription)
      }
    }
  }
}
