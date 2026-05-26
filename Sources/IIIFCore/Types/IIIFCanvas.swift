public struct IIIFCanvas: Sendable, Codable {
  public let id: String
  public let type: String
  public let label: IIIFLanguageMap?
  public let width: Int?
  public let height: Int?
  public let duration: Double?
  public let items: [IIIFAnnotationPage]
  public let annotations: [IIIFAnnotationPage]?
  public let metadata: [IIIFMetadataEntry]?
  public let thumbnail: [IIIFThumbnail]?
  public let rendering: [IIIFExternal]?
  public let seeAlso: [IIIFExternal]?
}
