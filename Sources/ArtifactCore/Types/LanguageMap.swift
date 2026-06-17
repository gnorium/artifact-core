import EmbeddedSwiftUtilities

public struct LanguageMap: Sendable {
  // Array instead of [String: [String]] — Dictionary<String, _> requires
  // String.hashValue, which pulls in Unicode normalization tables unavailable
  // in embedded Swift WASM. Entry counts here are always small (a handful of
  // languages), so a linear scan with stringEquals is the safe substitute.
  public struct Entry: Sendable {
    public let language: String
    public let values: [String]
  }

  private var entries: [Entry]

  public init(_ storage: [String: [String]] = [:]) {
    self.entries = storage.map { Entry(language: $0.key, values: $0.value) }
  }

  public init(_ entries: [Entry]) {
    self.entries = entries
  }

  #if SERVER
    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      let storage = try container.decode([String: [String]].self)
      entries = storage.map { Entry(language: $0.key, values: $0.value) }
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      var storage: [String: [String]] = [:]
      for entry in entries { storage[entry.language] = entry.values }
      try container.encode(storage)
    }
  #endif

  private func entry(for lang: String) -> Entry? {
    entries.first { stringEquals($0.language, lang) }
  }

  public var best: String {
    if let en = entry(for: "en")?.values.first { return en }
    if let none = entry(for: "none")?.values.first { return none }
    return entries.first?.values.first ?? ""
  }

  public func best(for lang: String) -> String {
    entry(for: lang)?.values.first ?? best
  }

  public subscript(lang: String) -> [String]? {
    entry(for: lang)?.values
  }

  public var allLanguages: [String] { entries.map { $0.language } }
}

#if SERVER
  extension LanguageMap: Codable {}
#endif
