public struct LanguageMap: Sendable {
  private var storage: [String: [String]]

  public init(_ storage: [String: [String]] = [:]) {
    self.storage = storage
  }

  #if SERVER
    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      storage = try container.decode([String: [String]].self)
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(storage)
    }
  #endif

  public var best: String {
    if let en = storage["en"]?.first { return en }
    if let none = storage["none"]?.first { return none }
    return storage.values.first?.first ?? ""
  }

  public func best(for lang: String) -> String {
    storage[lang]?.first ?? best
  }

  public subscript(lang: String) -> [String]? {
    storage[lang]
  }

  public var allLanguages: [String] { Array(storage.keys) }
}

#if SERVER
  extension LanguageMap: Codable {}
#endif
