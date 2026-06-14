public struct Size: Sendable {
  public let width: Int
  public let height: Int
}

#if SERVER
  extension Size: Codable {}
#endif
