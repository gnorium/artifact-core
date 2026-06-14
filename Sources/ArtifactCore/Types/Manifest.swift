public struct Manifest: Sendable {
  public let id: String
  public let type: String
  public let label: LanguageMap?
  public let metadata: [MetadataEntry]?
  public let summary: LanguageMap?
  public let requiredStatement: RequiredStatement?
  public let rights: String?
  public let thumbnail: [Thumbnail]?
  public let provider: [Agent]?
  public let seeAlso: [External]?
  public let homepage: [External]?
  public let rendering: [External]?
  public let service: [Service]?
  public let items: [Canvas]?
  public let structures: [Range]?
  public let annotations: [AnnotationPage]?
  public let viewingDirection: String?
  public let behavior: [String]?
}

#if SERVER
  extension Manifest: Codable {}
#endif
