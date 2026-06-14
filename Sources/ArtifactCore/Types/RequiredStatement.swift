public struct RequiredStatement: Sendable {
  public let label: LanguageMap
  public let value: LanguageMap
}

#if SERVER
  extension RequiredStatement: Codable {}
#endif
