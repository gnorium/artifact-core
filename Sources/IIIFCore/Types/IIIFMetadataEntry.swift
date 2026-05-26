public struct IIIFMetadataEntry: Sendable {
  public let label: IIIFLanguageMap
  public let value: IIIFLanguageMap
}

#if SERVER
  extension IIIFMetadataEntry: Codable {}
#endif
