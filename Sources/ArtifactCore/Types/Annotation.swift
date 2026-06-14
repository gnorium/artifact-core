public struct Annotation: Sendable {
  public let id: String?
  public let type: String
  public let motivation: String?
  public let body: ContentResource?
  public let target: String?
}

#if SERVER
  extension Annotation: Codable {}
#endif
