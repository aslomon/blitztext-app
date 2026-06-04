import AppKit
import Foundation
import NaturalLanguage

/// One extracted, candidate-worthy token from a raw transcript.
struct ExtractedTerm: Sendable, Equatable {
  let lemma: String
  let surfaceForm: String
  let category: MemoryCategory
}

/// On-device extraction (NaturalLanguage + NSSpellChecker, NO network, NO bundled wordlist).
///
/// Signals (per docs/MEMORY-spezifikation.md):
/// - `name`    = out-of-dictionary + capitalized + (NER nameType vote OR recurs across docs)
/// - `foreign` = token whose dominant language != the document's primary language AND is
///               in-dictionary for that other language
/// - `term`    = recurring in-dictionary rare noun (frequency carries the weight, NOT NER)
///
/// Frequency × rarity is the gate — NER only *votes*, it never gates (German NER over-fires).
/// `Sendable` + nonisolated so it can run on `Task.detached(.utility)` off the main actor.
struct MemoryExtractionService: Sendable {
  /// Languages we treat as "native" — a token in another in-dictionary language is foreign.
  private let primaryLanguageHints: [NLLanguage]
  private let minimumTokenLength: Int

  init(
    primaryLanguageHints: [NLLanguage] = [.german, .english],
    minimumTokenLength: Int = 3
  ) {
    self.primaryLanguageHints = primaryLanguageHints
    self.minimumTokenLength = minimumTokenLength
  }

  /// Extract candidate terms from ONE raw transcript. Deterministic, pure, no I/O.
  func extract(from rawTranscript: String) -> [ExtractedTerm] {
    let text = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.count >= minimumTokenLength else { return [] }

    let documentLanguage = dominantLanguage(of: text) ?? .german
    // `checkSpelling(of:…language:…)` takes the language explicitly, so we never have to
    // mutate (and restore) the shared checker's current language.
    let spellChecker = NSSpellChecker.shared

    var results: [String: ExtractedTerm] = [:]

    let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .lemma, .language])
    tagger.string = text
    let options: NLTagger.Options = [
      .omitWhitespace, .omitPunctuation, .joinNames,
    ]
    let range = text.startIndex..<text.endIndex

    tagger.enumerateTags(
      in: range, unit: .word, scheme: .lexicalClass, options: options
    ) { tag, tokenRange in
      let surface = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
      guard surface.count >= minimumTokenLength else { return true }
      guard surface.rangeOfCharacter(from: .letters) != nil else { return true }

      let lemmaTag = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lemma).0
      let lemma = lemmaTag?.rawValue ?? surface
      let nameTag = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .nameType).0
      let tokenLanguage = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .language).0

      if let term = classify(
        surface: surface,
        lemma: lemma,
        lexicalClass: tag,
        nameTag: nameTag,
        tokenLanguageRaw: tokenLanguage?.rawValue,
        documentLanguage: documentLanguage,
        spellChecker: spellChecker
      ) {
        // Keep the first (or highest-priority) classification per lemma in this document.
        let key = term.lemma.lowercased()
        if let existing = results[key] {
          if term.category.injectionRank < existing.category.injectionRank {
            results[key] = term
          }
        } else {
          results[key] = term
        }
      }
      return true
    }

    return Array(results.values)
  }

  // MARK: - Classification

  private func classify(
    surface: String,
    lemma: String,
    lexicalClass: NLTag?,
    nameTag: NLTag?,
    tokenLanguageRaw: String?,
    documentLanguage: NLLanguage,
    spellChecker: NSSpellChecker
  ) -> ExtractedTerm? {
    let isCapitalized = surface.first?.isUppercase ?? false
    let isNERName = isPersonalNameTag(nameTag)
    let documentLangCode = languageCode(for: documentLanguage)
    let isOOVInDocLanguage = isOutOfDictionary(
      surface, languageCode: documentLangCode, spellChecker: spellChecker)

    // 1) Foreign: token's dominant language differs from the document AND it IS a real word there.
    if let tokenLanguageRaw,
      let tokenLanguage = optionalLanguage(tokenLanguageRaw),
      tokenLanguage != documentLanguage,
      !isNERName
    {
      let tokenLangCode = languageCode(for: tokenLanguage)
      let isInOtherDictionary = !isOutOfDictionary(
        surface, languageCode: tokenLangCode, spellChecker: spellChecker)
      if isInOtherDictionary && isOOVInDocLanguage {
        return ExtractedTerm(lemma: lemma, surfaceForm: surface, category: .foreign)
      }
    }

    // 2) Name: OOV + capitalized, or a personal-name NER vote (NER only votes; OOV is the gate).
    if (isOOVInDocLanguage && isCapitalized) || (isNERName && isCapitalized) {
      return ExtractedTerm(lemma: lemma, surfaceForm: surface, category: .name)
    }

    // 3) Term: a rare in-dictionary noun. Frequency upstream decides if it sticks.
    if isNoun(lexicalClass), !isOOVInDocLanguage {
      // Skip extremely common short words; the cross-document frequency gate + decay handle the rest.
      return ExtractedTerm(lemma: lemma, surfaceForm: surface, category: .term)
    }

    // OOV non-capitalized: still useful as a term candidate (rare jargon, lowercase).
    if isOOVInDocLanguage, isNoun(lexicalClass) || lexicalClass == nil {
      return ExtractedTerm(lemma: lemma, surfaceForm: surface, category: .term)
    }

    return nil
  }

  // MARK: - Signals

  private func dominantLanguage(of text: String) -> NLLanguage? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    return recognizer.dominantLanguage
  }

  private func isPersonalNameTag(_ tag: NLTag?) -> Bool {
    guard let tag else { return false }
    return tag == .personalName || tag == .placeName || tag == .organizationName
  }

  private func isNoun(_ tag: NLTag?) -> Bool {
    tag == .noun
  }

  private func isOutOfDictionary(
    _ word: String, languageCode: String, spellChecker: NSSpellChecker
  ) -> Bool {
    let range = NSRange(location: 0, length: (word as NSString).length)
    let misspelledRange = spellChecker.checkSpelling(
      of: word,
      startingAt: 0,
      language: languageCode,
      wrap: false,
      inSpellDocumentWithTag: 0,
      wordCount: nil
    )
    _ = range
    // A non-empty misspelled range means the word is unknown for that language → OOV/rare.
    return misspelledRange.location != NSNotFound && misspelledRange.length > 0
  }

  private func languageCode(for language: NLLanguage) -> String {
    // NSSpellChecker expects BCP-47-ish codes; NLLanguage raw values already match (de, en, ...).
    language.rawValue
  }

  private func optionalLanguage(_ raw: String) -> NLLanguage? {
    let language = NLLanguage(rawValue: raw)
    return language == .undetermined ? nil : language
  }
}
