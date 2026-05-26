public struct IIIFExternal: Sendable {
  public let id: String
  public let type: String
  public let format: String?
  public let label: IIIFLanguageMap?
}

#if SERVER
  extension IIIFExternal: Codable {}
#endif
