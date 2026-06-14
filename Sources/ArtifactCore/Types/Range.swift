public struct Range: Sendable {
  public let id: String
  public let type: String
  public let label: LanguageMap?
  public let items: [RangeItem]?
  public let behavior: String?
}

#if SERVER
  extension Range: Codable {}
#endif
