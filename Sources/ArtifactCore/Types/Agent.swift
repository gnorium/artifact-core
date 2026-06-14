public struct Agent: Sendable {
  public let id: String
  public let type: String
  public let label: LanguageMap?
  public let homepage: [External]?
  public let logo: [Thumbnail]?
}

#if SERVER
  extension Agent: Codable {}
#endif
