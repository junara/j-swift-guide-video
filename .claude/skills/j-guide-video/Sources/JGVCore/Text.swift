// 文字 (CoreText)。フォントは CSS と同じ書き方の並び ('"Hiragino Sans", "Noto Sans JP", sans-serif') で指定し、
// 入っている最初のフォントを使う (無い字は後ろのフォントで補う)。太さは CSS の数値 (400 / 700 / 800 / 900)
import CoreGraphics
import CoreText
import Foundation

public enum FontBook {
  nonisolated(unsafe) private static var descCache: [String: CTFontDescriptor] = [:]
  nonisolated(unsafe) private static var fontCache: [String: CTFont] = [:]
  private static let lock = NSLock()

  static let generic: [String: [String]] = [
    "sans-serif": ["Helvetica Neue", "Hiragino Sans"],
    "serif": ["Times New Roman", "Hiragino Mincho ProN"],
    "monospace": ["Menlo"],
    "system-ui": ["Helvetica Neue", "Hiragino Sans"],
  ]

  /// CSS の font-family の並びを名前の配列にする
  public static func families(_ list: String) -> [String] {
    var out: [String] = []
    for part in list.split(separator: ",") {
      let name = part.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
      if name.isEmpty { continue }
      if let g = generic[name.lowercased()] { out += g } else { out.append(name) }
    }
    return out
  }

  /// その family の書体 (W3・W6 など) と、それぞれの太さ (OS/2 の usWeightClass)
  private static func faces(_ family: String) -> [(CTFontDescriptor, Double)] {
    let base = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
    guard let list = CTFontDescriptorCreateMatchingFontDescriptors(base, Set([kCTFontFamilyNameAttribute as String]) as CFSet) as? [CTFontDescriptor] else { return [] }
    return list.compactMap { d in
      guard let fam = CTFontDescriptorCopyAttribute(d, kCTFontFamilyNameAttribute) as? String, fam.caseInsensitiveCompare(family) == .orderedSame else { return nil }
      // 斜体は使わない
      if let traits = CTFontDescriptorCopyAttribute(d, kCTFontTraitsAttribute) as? [CFString: Any],
         let sym = traits[kCTFontSymbolicTrait] as? UInt32, sym & CTFontSymbolicTraits.traitItalic.rawValue != 0 { return nil }
      // 幅の狭い・広い書体 (Condensed など) は使わない (CSS の font-stretch: normal)
      if let traits = CTFontDescriptorCopyAttribute(d, kCTFontTraitsAttribute) as? [CFString: Any],
         let width = traits[kCTFontWidthTrait] as? Double, abs(width) > 0.05 { return nil }
      if let name = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String,
         name.range(of: "Condensed|Compressed|Narrow|Expanded|Wide", options: .regularExpression) != nil { return nil }
      return (d, weightClass(d))
    }
  }

  private static func weightClass(_ d: CTFontDescriptor) -> Double {
    let f = CTFontCreateWithFontDescriptor(d, 12, nil)
    if let table = CTFontCopyTable(f, CTFontTableTag(kCTFontTableOS2), []) as Data?, table.count >= 6 {
      let w = Double(UInt16(table[4]) << 8 | UInt16(table[5]))
      if w >= 1 && w <= 1000 { return w }
    }
    if let traits = CTFontDescriptorCopyAttribute(d, kCTFontTraitsAttribute) as? [CFString: Any], let w = traits[kCTFontWeightTrait] as? Double {
      // CoreText の太さ (-1〜1) を CSS の数値に近づける
      let table: [(Double, Double)] = [(-0.8, 100), (-0.6, 200), (-0.4, 300), (0, 400), (0.23, 500), (0.3, 600), (0.4, 700), (0.56, 800), (0.62, 900)]
      return table.min { abs($0.0 - w) < abs($1.0 - w) }!.1
    }
    return 400
  }

  /// CSS の太さの選び方 (font-weight のマッチング) で書体を選ぶ
  private static func pick(_ faces: [(CTFontDescriptor, Double)], _ want: Double) -> CTFontDescriptor? {
    guard !faces.isEmpty else { return nil }
    if let exact = faces.first(where: { $0.1 == want }) { return exact.0 }
    let up = faces.filter { $0.1 > want }.sorted { $0.1 < $1.1 }
    let down = faces.filter { $0.1 < want }.sorted { $0.1 > $1.1 }
    if want >= 400 && want <= 500 {
      if let f = up.first(where: { $0.1 <= 500 }) { return f.0 }
      if let f = down.first { return f.0 }
      return up.first?.0
    }
    if want < 400 { return (down.first ?? up.first)?.0 }
    return (up.first ?? down.first)?.0
  }

  /// フォントの並びと太さに合う書体 (足りない字を補うフォントの並び付き)
  public static func descriptor(_ list: String, weight: Double) -> CTFontDescriptor {
    let key = "\(list)|\(weight)"
    lock.lock()
    if let d = descCache[key] { lock.unlock(); return d }
    lock.unlock()
    let names = families(list)
    var picked: [CTFontDescriptor] = []
    for n in names {
      if let d = pick(faces(n), weight) { picked.append(d) }
    }
    if picked.isEmpty, let d = pick(faces("Hiragino Sans"), weight) { picked.append(d) }
    var desc = picked.first ?? CTFontDescriptorCreateWithNameAndSize("Helvetica" as CFString, 12)
    if picked.count > 1 {
      desc = CTFontDescriptorCreateCopyWithAttributes(desc, [kCTFontCascadeListAttribute: Array(picked.dropFirst())] as CFDictionary)
    }
    lock.lock()
    descCache[key] = desc
    lock.unlock()
    return desc
  }

  public static func font(_ list: String, weight: Double, size: Double) -> CTFont {
    let key = "\(list)|\(weight)|\(size)"
    lock.lock()
    if let f = fontCache[key] { lock.unlock(); return f }
    lock.unlock()
    let f = CTFontCreateWithFontDescriptor(descriptor(list, weight: weight), size, nil)
    lock.lock()
    if fontCache.count > 4000 { fontCache.removeAll(keepingCapacity: true) }
    fontCache[key] = f
    lock.unlock()
    return f
  }

  /// 既定のフォントの並び (日本語)
  public static let defaultFamily = "\"Hiragino Sans\", \"Hiragino Kaku Gothic ProN\", \"Noto Sans JP\", sans-serif"
}

/// 1 行の文字の形と幅
public struct TextLine {
  public let line: CTLine
  public let width: Double
  public let ascent: Double
  public let descent: Double
  public let font: CTFont

  public init(_ s: String, family: String, size: Double, weight: Double, letterSpacing: Double = 0) {
    let f = FontBook.font(family, weight: weight, size: size)
    var attrs: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): f,
      NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
    ]
    if letterSpacing != 0 { attrs[NSAttributedString.Key(kCTKernAttributeName as String)] = letterSpacing }
    let str = NSMutableAttributedString(string: s, attributes: attrs)
    // 隣り合う約物 (「、「」「。」」など) の間を半角ぶん詰める (Chrome の text-spacing-trim: normal と同じ)
    let trim = TextLine.trimmedPunctuation(s)
    for r in trim {
      // 詰める位置の直前の字の後ろの字間を半角ぶん減らす
      str.addAttribute(NSAttributedString.Key(kCTKernAttributeName as String), value: letterSpacing - size / 2, range: r)
    }
    let line = CTLineCreateWithAttributedString(str)
    var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
    let w = CTLineGetTypographicBounds(line, &a, &d, &l)
    self.line = line
    self.width = w
    self.ascent = CTFontGetAscent(f)
    self.descent = CTFontGetDescent(f)
    self.font = f
  }
}

extension TextLine {
  static let opening = Set("「『（〔［｛〈《【（".utf16)
  static let closing = Set("」』）〕］｝〉》】、。，．".utf16)

  /// 後ろを半角ぶん詰める字の範囲 (UTF-16)。約物の後に開き括弧が続くとき、閉じ括弧・句読点の後に閉じ括弧・句読点が続くとき
  static func trimmedPunctuation(_ s: String) -> [NSRange] {
    let u = Array(s.utf16)
    var out: [NSRange] = []
    guard u.count >= 2 else { return out }
    for i in 1 ..< u.count {
      let a = u[i - 1], b = u[i]
      if opening.contains(b) && (opening.contains(a) || closing.contains(a)) {
        out.append(NSRange(location: i - 1, length: 1))
      } else if closing.contains(a) && closing.contains(b) {
        out.append(NSRange(location: i - 1, length: 1))
      }
    }
    return out
  }
}

/// 文字の幅 (実際のフォントで測る)
public func measureText(_ s: String, size: Double, weight: Double = 400, family: String? = nil, letterSpacing: Double = 0) -> Double {
  let fam = family ?? RenderContext.currentOrNil?.style.fontFamily ?? FontBook.defaultFamily
  return TextLine(s, family: fam, size: size, weight: weight, letterSpacing: letterSpacing).width
}

/// SVG の <text> (1 行)。y は dominantBaseline の位置 (既定はベースライン、.central で文字の上下の中央)
public func text(
  _ s: String,
  x: Double = 0, y: Double = 0,
  fontSize: Double? = nil, fontWeight: Double? = nil, fontFamily: String? = nil,
  fill: Paint? = nil, stroke: Paint? = nil, strokeWidth: Double? = nil,
  textAnchor: TextAnchor? = nil, dominantBaseline: DominantBaseline? = nil, letterSpacing: Double? = nil,
  opacity: Double = 1, transform: [Tf] = []
) {
  if !(opacity > 0) || s.isEmpty { return }
  let c = RenderContext.current
  let st = c.style
  let cg = c.cg
  let size = fontSize ?? st.fontSize
  let fam = fontFamily ?? st.fontFamily ?? FontBook.defaultFamily
  let tl = TextLine(s, family: fam, size: size, weight: fontWeight ?? st.fontWeight, letterSpacing: letterSpacing ?? st.letterSpacing)
  let fillP = fill ?? st.fill
  let strokeP = stroke ?? st.stroke
  let sw = strokeWidth ?? st.strokeWidth
  let hasFill = !fillP.isNone
  let hasStroke = !strokeP.isNone && sw > 0
  if !hasFill && !hasStroke { return }

  var dx = 0.0
  switch textAnchor ?? st.textAnchor {
  case .start: dx = 0
  case .middle: dx = -tl.width / 2
  case .end: dx = -tl.width
  }
  var baseline = y
  switch dominantBaseline ?? st.dominantBaseline {
  case .alphabetic: baseline = y
  case .central: baseline = y + (tl.ascent - tl.descent) / 2
  case .middle: baseline = y + CTFontGetXHeight(tl.font) / 2
  case .hanging, .textTop: baseline = y + tl.ascent
  case .textBottom: baseline = y - tl.descent
  }

  cg.saveGState()
  defer { cg.restoreGState() }
  applyTransforms(cg, transform)
  if LayoutProbe.active {
    LayoutProbe.text(s, rect: CGRect(x: x + dx, y: baseline - tl.ascent, width: tl.width, height: tl.ascent + tl.descent), opacity: opacity)
  }
  let layered = opacity < 1 && hasFill && hasStroke
  var alpha = opacity
  if layered {
    cg.setAlpha(opacity)
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    alpha = 1
  }
  if let col = fillP.rgba { cg.setFillColor(RGBA(col.r, col.g, col.b, col.a * alpha).cgColor) }
  if hasStroke, let col = strokeP.rgba {
    cg.setStrokeColor(RGBA(col.r, col.g, col.b, col.a * alpha).cgColor)
    cg.setLineWidth(sw)
    cg.setLineJoin(.round)
  }
  cg.setTextDrawingMode(hasFill && hasStroke ? .fillStroke : hasStroke ? .stroke : .fill)
  // 描き先は y が下向きなので、文字だけ上下を戻す
  cg.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
  cg.textPosition = CGPoint(x: x + dx, y: baseline)
  CTLineDraw(tl.line, cg)
  if layered { cg.endTransparencyLayer() }
}
