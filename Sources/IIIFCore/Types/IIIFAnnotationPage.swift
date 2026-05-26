public struct IIIFAnnotationPage: Sendable {
  public let id: String?
  public let type: String
  public let label: IIIFLanguageMap?
  public let items: [IIIFAnnotation]?
}

#if SERVER
  extension IIIFAnnotationPage: Codable {}
#endif
