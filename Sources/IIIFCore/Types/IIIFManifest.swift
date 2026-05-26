public struct IIIFManifest: Sendable {
  public let id: String
  public let type: String
  public let label: IIIFLanguageMap?
  public let metadata: [IIIFMetadataEntry]?
  public let summary: IIIFLanguageMap?
  public let requiredStatement: IIIFRequiredStatement?
  public let rights: String?
  public let thumbnail: [IIIFThumbnail]?
  public let provider: [IIIFAgent]?
  public let seeAlso: [IIIFExternal]?
  public let homepage: [IIIFExternal]?
  public let rendering: [IIIFExternal]?
  public let service: [IIIFService]?
  public let items: [IIIFCanvas]?
  public let structures: [IIIFRange]?
  public let annotations: [IIIFAnnotationPage]?
  public let viewingDirection: String?
  public let behavior: [String]?
}

#if SERVER
  extension IIIFManifest: Codable {}
#endif
