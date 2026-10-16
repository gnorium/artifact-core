import EmbeddedSwiftUtilities

public enum TileURL {
  public static func infoURL(from serviceID: String) -> String {
    stringEndsWith(serviceID, "/") ? "\(serviceID)info.json" : "\(serviceID)/info.json"
  }

  public static func url(
    serviceID: String,
    region: Region = .full,
    size: TileSize,
    rotation: String = "0",
    quality: String = "default",
    format: String = "jpg"
  ) -> String {
    let base = stringEndsWith(serviceID, "/") ? stringRemoveSuffix(serviceID, "/") : serviceID
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
    // The tile at its level: the region's width over the scale factor,
    // rounded up (IIIF's canonical tile size). The region's full width
    // was an upscale the server refuses, or renders at `scaleFactor`
    // times the pixels.
    return url(
      serviceID: serviceID,
      region: .xywh(regionX, regionY, regionW, regionH),
      size: .exact((regionW + scaleFactor - 1) / scaleFactor, nil),
      quality: "default",
      format: format
    )
  }
}
