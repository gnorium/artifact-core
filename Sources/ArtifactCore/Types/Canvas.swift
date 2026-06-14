public struct Canvas: Sendable {
  public let id: String
  public let type: String
  public let label: LanguageMap?
  public let width: Int?
  public let height: Int?
  public let duration: Double?
  public let items: [AnnotationPage]
  public let annotations: [AnnotationPage]?
  public let metadata: [MetadataEntry]?
  public let thumbnail: [Thumbnail]?
  public let rendering: [External]?
  public let seeAlso: [External]?
}

#if SERVER
  extension Canvas: Codable {}
#endif
