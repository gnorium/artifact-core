public struct Service: Sendable {
  public let id: String?
  public let type: String
  public let profile: String?
}

#if SERVER
  extension Service: Codable {}
#endif
