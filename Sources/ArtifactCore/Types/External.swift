public struct External: Sendable {
  public let id: String
  public let type: String
  public let format: String?
  public let label: LanguageMap?
}

#if SERVER
  extension External: Codable {}
#endif
