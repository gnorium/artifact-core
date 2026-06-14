public struct AnnotationPage: Sendable {
  public let id: String?
  public let type: String
  public let label: LanguageMap?
  public let items: [Annotation]?
}

#if SERVER
  extension AnnotationPage: Codable {}
#endif
