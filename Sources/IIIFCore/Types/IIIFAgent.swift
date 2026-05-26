public struct IIIFAgent: Sendable, Codable {
  public let id: String
  public let type: String
  public let label: IIIFLanguageMap?
  public let homepage: [IIIFExternal]?
  public let logo: [IIIFThumbnail]?
}
