public struct MetadataEntry: Sendable {
  public let label: LanguageMap
  public let value: LanguageMap
}

#if SERVER
  extension MetadataEntry: Codable {}
#endif
