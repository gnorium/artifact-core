public struct IIIFService: Sendable {
  public let id: String?
  public let type: String
  public let profile: String?
}

#if SERVER
  extension IIIFService: Codable {}
#endif
