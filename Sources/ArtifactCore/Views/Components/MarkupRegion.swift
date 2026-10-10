#if CLIENT
  import EmbeddedSwiftUtilities

  /// The region of the canvas a page's markup names where a caret stands
  /// (or a pointer rests) in its code, in the 0–1000 space over the whole
  /// image: x y its top-left corner, width and height its size.
  ///
  /// The element the caret is on (its start tag, its end tag, or its
  /// content), or the nearest element around it that names one, names it:
  /// by `bbox="x y w h"` (the explication prompt's rule: four whole numbers,
  /// inside the image), by `facs="#…"` (a zone of the document's facsimile,
  /// handed in as `zones`), or as a `<zone>` itself (its `xml:id` among
  /// `zones`, else its own corners). An element that names one wrongly (a
  /// partial or invalid bbox, typed as it is) names nothing, and the
  /// elements around it are not asked.
  ///
  /// Read from the code's UTF-8 bytes alone: no String comparison or
  /// normalization in the client.
  struct MarkupRegion {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    /// Where the `bbox` value that names it stands in the text (its first
    /// byte, and the byte after its last), when a bbox names it; -1 else.
    /// The region can be edited there.
    var valueStart = -1
    var valueEnd = -1

    init(x: Int, y: Int, width: Int, height: Int, valueStart: Int = -1, valueEnd: Int = -1) {
      self.x = x
      self.y = y
      self.width = width
      self.height = height
      self.valueStart = valueStart
      self.valueEnd = valueEnd
    }

    /// Whether a bbox names it, so it can be edited where it is written.
    var editable: Bool { valueStart >= 0 }

    /// Whether a point of the text stands inside its bbox's value.
    func holds(_ caret: Int) -> Bool { editable && caret >= valueStart && caret <= valueEnd }

    /// As a bbox writes it: "x y w h".
    var bbox: String {
      stringJoin([intToString(x), intToString(y), intToString(width), intToString(height)], separator: " ")
    }

    func isSame(as other: MarkupRegion) -> Bool {
      x == other.x && y == other.y && width == other.width && height == other.height
    }

    /// `zones`: "id x y w h" in the 0–1000 space, one a ";" (`TEIView`'s
    /// `data-zones` on a page).
    static func at(_ text: [UInt8], caret: Int, zones: String) -> MarkupRegion? {
      var stack: [Tag] = []
      var candidates: [Tag] = []
      var onTag = false
      for tag in tags(text) {
        // Touching a tag, either side of it, is being on it.
        if caret >= tag.start && caret <= tag.end + 1 {
          switch tag.kind {
          case .open, .empty:
            candidates = [tag] + stack.reversed()
          case .close:
            if let index = stack.lastIndex(where: { sameName($0, tag, in: text) }) {
              candidates = Array(stack[0...index].reversed())
            } else {
              candidates = stack.reversed()
            }
          }
          onTag = true
          break
        }
        if tag.start >= caret { break }
        switch tag.kind {
        case .open: stack.append(tag)
        case .empty: break
        case .close:
          if let index = stack.lastIndex(where: { sameName($0, tag, in: text) }) {
            stack.removeSubrange(index..<stack.count)
          }
        }
      }
      if !onTag { candidates = stack.reversed() }
      for tag in candidates {
        switch named(by: tag, in: text, zones: zones) {
        case .nothing: continue
        case .invalid: return nil
        case .region(let region): return region
        }
      }
      return nil
    }

    // MARK: - Tags

    struct Tag {
      enum Kind { case open, close, empty }
      let kind: Kind
      /// Its `<`, and its `>` (the text's last byte for a tag left open).
      let start: Int
      let end: Int
      let nameStart: Int
      let nameEnd: Int
    }

    /// The element tags of the text, in order; comments, declarations and
    /// processing instructions passed over.
    static func tags(_ text: [UInt8]) -> [Tag] {
      var found: [Tag] = []
      let count = text.count
      var i = 0
      while i < count {
        guard text[i] == 60 else {  // "<"
          i += 1
          continue
        }
        let next = i + 1 < count ? text[i + 1] : 0
        if next == 33 || next == 63 {  // "!" or "?"
          let comment = i + 3 < count && text[i + 2] == 45 && text[i + 3] == 45
          var j = i + 2
          while j < count {
            if comment {
              if text[j] == 62 && text[j - 1] == 45 && text[j - 2] == 45 && j - 2 > i + 3 { break }
            } else if text[j] == 62 {
              break
            }
            j += 1
          }
          i = j + 1
          continue
        }
        let closing = next == 47  // "/"
        let nameStart = closing ? i + 2 : i + 1
        var nameEnd = nameStart
        while nameEnd < count, !isSpace(text[nameEnd]), text[nameEnd] != 47, text[nameEnd] != 62, text[nameEnd] != 60 {
          nameEnd += 1
        }
        // The tag's end, past any quoted value; a "<" outside quotes ends a
        // tag left unfinished before it.
        var j = nameEnd
        var quote: UInt8 = 0
        var end = count - 1
        var resume = count
        while j < count {
          let byte = text[j]
          if quote != 0 {
            if byte == quote { quote = 0 }
          } else if byte == 34 || byte == 39 {
            quote = byte
          } else if byte == 62 {
            end = j
            resume = j + 1
            break
          } else if byte == 60 {
            end = j - 1
            resume = j
            break
          }
          j += 1
        }
        let kind: Tag.Kind =
          closing ? .close : (end > i && text[end] == 62 && text[end - 1] == 47 ? .empty : .open)
        found.append(Tag(kind: kind, start: i, end: end, nameStart: nameStart, nameEnd: nameEnd))
        i = resume
      }
      return found
    }

    static func sameName(_ a: Tag, _ b: Tag, in text: [UInt8]) -> Bool {
      guard a.nameEnd - a.nameStart == b.nameEnd - b.nameStart else { return false }
      var offset = 0
      while offset < a.nameEnd - a.nameStart {
        if text[a.nameStart + offset] != text[b.nameStart + offset] { return false }
        offset += 1
      }
      return true
    }

    static func isSpace(_ byte: UInt8) -> Bool {
      byte == 32 || byte == 9 || byte == 10 || byte == 13
    }

    // MARK: - What a tag names

    enum Named {
      case nothing
      case invalid
      case region(MarkupRegion)
    }

    static func named(by tag: Tag, in text: [UInt8], zones: String) -> Named {
      guard tag.kind != .close else { return .nothing }
      let attributes = self.attributes(of: tag, in: text)
      if let bbox = value(of: "bbox", in: attributes) {
        guard let bbox, let box = numbers(bbox.bytes), box.count == 4 else { return .invalid }
        let named = checked(x: box[0], y: box[1], width: box[2], height: box[3])
        guard case .region(let region) = named else { return named }
        return .region(
          MarkupRegion(
            x: region.x, y: region.y, width: region.width, height: region.height, valueStart: bbox.start,
            valueEnd: bbox.start + bbox.bytes.count))
      }
      if let facs = value(of: "facs", in: attributes) {
        // A page break's facs is its image, not a zone.
        guard let facs, !facs.bytes.isEmpty, facs.bytes[0] == 35 else { return .nothing }  // "#"
        return zone(String(decoding: facs.bytes[1...], as: UTF8.self), in: zones)
      }
      let name = String(decoding: text[tag.nameStart..<tag.nameEnd], as: UTF8.self)
      guard stringEquals(name, "zone") else { return .nothing }
      if let id = value(of: "xml:id", in: attributes), let id {
        let listed = zone(String(decoding: id.bytes, as: UTF8.self), in: zones)
        if case .region = listed { return listed }
      }
      guard let ulx = value(of: "ulx", in: attributes), let ulx, let left = numbers(ulx.bytes), left.count == 1,
        let uly = value(of: "uly", in: attributes), let uly, let top = numbers(uly.bytes), top.count == 1,
        let lrx = value(of: "lrx", in: attributes), let lrx, let right = numbers(lrx.bytes), right.count == 1,
        let lry = value(of: "lry", in: attributes), let lry, let bottom = numbers(lry.bytes), bottom.count == 1
      else { return .invalid }
      return checked(x: left[0], y: top[0], width: right[0] - left[0], height: bottom[0] - top[0])
    }

    /// A box inside the image, of some size; anything else names nothing.
    static func checked(x: Int, y: Int, width: Int, height: Int) -> Named {
      guard x >= 0, y >= 0, width > 0, height > 0, x + width <= 1000, y + height <= 1000 else { return .invalid }
      return .region(MarkupRegion(x: x, y: y, width: width, height: height))
    }

    /// A zone the page names, from its `data-zones`.
    static func zone(_ id: String, in zones: String) -> Named {
      for entry in stringSplit(zones, separator: ";") {
        let fields = stringSplit(entry, separator: " ").filter { !stringIsEmpty($0) }
        guard fields.count == 5, stringEquals(fields[0], id) else { continue }
        guard let x = parseInt(fields[1]), let y = parseInt(fields[2]), let width = parseInt(fields[3]),
          let height = parseInt(fields[4])
        else { return .invalid }
        return checked(x: x, y: y, width: width, height: height)
      }
      return .invalid
    }

    /// The tag's attributes, each its name and its value (nil: a value
    /// still being typed, its quote not closed).
    static func attributes(of tag: Tag, in text: [UInt8]) -> [(name: [UInt8], value: Value?)] {
      var found: [(name: [UInt8], value: Value?)] = []
      var i = tag.nameEnd
      let end = min(tag.end + 1, text.count)
      while i < end {
        while i < end, isSpace(text[i]) || text[i] == 47 || text[i] == 62 { i += 1 }
        let nameStart = i
        while i < end, !isSpace(text[i]), text[i] != 61, text[i] != 62, text[i] != 47 { i += 1 }
        guard i > nameStart else { break }
        let name = Array(text[nameStart..<i])
        while i < end, isSpace(text[i]) { i += 1 }
        guard i < end, text[i] == 61 else {  // "="
          found.append((name, Value(bytes: [], start: i)))
          continue
        }
        i += 1
        while i < end, isSpace(text[i]) { i += 1 }
        guard i < end, text[i] == 34 || text[i] == 39 else {
          found.append((name, nil))
          continue
        }
        let quote = text[i]
        i += 1
        let valueStart = i
        while i < end, text[i] != quote { i += 1 }
        if i < end {
          found.append((name, Value(bytes: Array(text[valueStart..<i]), start: valueStart)))
          i += 1
        } else {
          found.append((name, nil))
        }
      }
      return found
    }

    /// An attribute's value: its bytes, and where the first stands.
    struct Value {
      let bytes: [UInt8]
      let start: Int
    }

    /// The attribute's value: absent (nil), being typed (`.some(nil)`), or
    /// its bytes.
    static func value(of name: StaticString, in attributes: [(name: [UInt8], value: Value?)]) -> Value?? {
      let wanted = name.withUTF8Buffer { Array($0) }
      for attribute in attributes where attribute.name == wanted {
        return .some(attribute.value)
      }
      return nil
    }

    /// Whole numbers separated by spaces; nil for anything else.
    static func numbers(_ bytes: [UInt8]) -> [Int]? {
      var values: [Int] = []
      var current = -1
      for byte in bytes {
        if byte >= 48 && byte <= 57 {
          current = (current < 0 ? 0 : current * 10) + Int(byte - 48)
          if current > 1_000_000 { return nil }
        } else if isSpace(byte) {
          if current >= 0 { values.append(current) }
          current = -1
        } else {
          return nil
        }
      }
      if current >= 0 { values.append(current) }
      return values
    }
  }
#endif
