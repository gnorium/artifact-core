public struct IIIFRequiredStatement: Sendable {
  public let label: IIIFLanguageMap
  public let value: IIIFLanguageMap
}

#if SERVER
  extension IIIFRequiredStatement: Codable {}
#endif
