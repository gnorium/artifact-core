public struct ContentResource: Sendable {
  public let id: String
  public let type: String
  public let format: String?
  public let width: Int?
  public let height: Int?
  public let duration: Double?
  public let label: LanguageMap?
  public let service: [ImageService]?
  public let language: String?
}

#if SERVER
  extension ContentResource: Codable {}
#endif
