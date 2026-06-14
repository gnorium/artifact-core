#if CLIENT
  import EmbeddedSwiftUtilities
#endif

public enum TileURL {
  public static func infoURL(from serviceID: String) -> String {
    serviceID.hasSuffix("/") ? "\(serviceID)info.json" : "\(serviceID)/info.json"
  }

  public static func url(
    serviceID: String,
    region: Region = .full,
    size: TileSize,
    rotation: String = "0",
    quality: String = "default",
    format: String = "jpg"
  ) -> String {
    let base = serviceID.hasSuffix("/") ? String(serviceID.dropLast()) : serviceID
    return "\(base)/\(region.stringValue)/\(size.stringValue)/\(rotation)/\(quality).\(format)"
  }

  public static func bestTile(
    serviceID: String,
    tileWidth: Int,
    scaleFactor: Int,
    x: Int, y: Int,
    imageWidth: Int,
    imageHeight: Int,
    format: String = "jpg"
  ) -> String {
    let scaledW = tileWidth * scaleFactor
    let scaledH = tileWidth * scaleFactor
    let regionX = x * scaledW
    let regionY = y * scaledH
    let regionW = min(scaledW, imageWidth - regionX)
    let regionH = min(scaledH, imageHeight - regionY)
    return url(
      serviceID: serviceID,
      region: .xywh(regionX, regionY, regionW, regionH),
      size: .exact(scaledW, nil),
      quality: "default",
      format: format
    )
  }
}
