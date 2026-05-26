public struct IIIFSize: Sendable {
  public let width: Int
  public let height: Int
}

#if SERVER
  extension IIIFSize: Codable {}
#endif
