public struct IIIFAnnotationPage: Sendable, Codable {
  public let id: String?
  public let type: String
  public let label: IIIFLanguageMap?
  public let items: [IIIFAnnotation]?
}
