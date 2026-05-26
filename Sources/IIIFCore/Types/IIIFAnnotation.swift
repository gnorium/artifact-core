public struct IIIFAnnotation: Sendable, Codable {
  public let id: String?
  public let type: String
  public let motivation: String?
  public let body: IIIFContentResource?
  public let target: String?
}
