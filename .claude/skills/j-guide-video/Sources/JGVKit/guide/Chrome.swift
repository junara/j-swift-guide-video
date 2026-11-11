// ガイドレイアウトの背景 (型ごと) と画面の枠 (タイトル・工程バッジ・字幕バー・進捗・クレジット)。
// 配置は useGuide().layout (横型 / 縦型) に従う。
import CoreText
import Foundation

/// room: 部屋の背景 (壁・丸窓・観葉植物・カウンター)
public func GuideRoom() {
  let frame = useCurrentFrame()
  let cfg = useVideoConfig()
  let gd = useGuide()
  let palette = gd.palette, layout = gd.layout
  let sway = sin((frame / cfg.fps) * 1.3) * 2.5
  let cy = layout.counterY
  let w = layout.window
  let px = layout.plantX
  g(fontFamily: gd.font) {
    rect(width: cfg.width, height: cfg.height, fill: .linear(LinearGradient(x2: 0, y2: 1, stops: [(0, palette.wallTop), (1, palette.wallBottom)])))
    circle(cx: w.x, cy: w.y, r: w.r, fill: palette.windowRing)
    rect(x: w.x - w.r * 0.6, y: w.y - w.r * 0.6, width: w.r * 1.2, height: w.r, rx: w.r * 0.6, fill: palette.windowGlass)
    path("M \(w.x) \(w.y - w.r * 0.6) V \(w.y + w.r * 0.4) M \(w.x - w.r * 0.6) \(w.y - w.r * 0.06) H \(w.x + w.r * 0.6)", stroke: palette.windowRing, strokeWidth: 12)
    g(fill: Paint.none, stroke: palette.primary, strokeWidth: 16, strokeLinecap: .round, opacity: 0.75, transform: [.rotate(sway, px, cy - 80)]) {
      path("M \(px) \(cy - 80) Q \(px - 40) \(cy - 270) \(px + 25) \(cy - 355)")
      path("M \(px) \(cy - 190) Q \(px + 90) \(cy - 300) \(px + 80) \(cy - 245)")
      path("M \(px - 10) \(cy - 225) Q \(px - 90) \(cy - 325) \(px - 75) \(cy - 260)")
    }
    path("M \(px - 55) \(cy - 115) H \(px + 60) L \(px + 35) \(cy) H \(px - 30) Z", fill: "#c3b39b", opacity: 0.85)
    rect(y: cy, width: cfg.width, height: layout.counterH, fill: palette.counter)
    rect(y: cy, width: cfg.width, height: 16, fill: palette.counterEdge)
    rect(y: cy + layout.counterH, width: cfg.width, height: cfg.height - cy - layout.counterH, fill: palette.floor)
  }
}

/// screen: 画面操作の背景 (やわらかい壁色と水玉)
public func ScreenBackdrop() {
  let cfg = useVideoConfig()
  let palette = useGuide().palette
  rect(width: cfg.width, height: cfg.height, fill: .linear(LinearGradient(x1: 0, y1: 0, x2: 1, y2: 1, stops: [(0, palette.wallTop), (1, palette.wallBottom)])))
  // 水玉の模様 (36px 間隔)
  let dot = palette.primary
  var y = 18.0
  while y < cfg.height + 18 {
    var x = 18.0
    while x < cfg.width + 18 {
      circle(cx: x, cy: y, r: 2.5, fill: dot, opacity: 0.08)
      x += 36
    }
    y += 36
  }
  circle(cx: cfg.width * 0.88, cy: cfg.height * 0.2, r: min(cfg.width, cfg.height) * 0.28, fill: palette.windowRing, opacity: 0.6)
}

/// topdown: 真上から見た作業台 (木目)。見出しの下には読みやすいよう座布団を敷く
public func TableTop() {
  let cfg = useVideoConfig()
  let gd = useGuide()
  let h = gd.layout.header
  let plank = 150.0
  rect(width: cfg.width, height: cfg.height, fill: "#d8b98e")
  let count = Int((cfg.height / plank).rounded(.up)) + 1
  for i in 0 ..< count {
    let top = Double(i) * plank
    rect(y: top, width: cfg.width, height: plank, fill: i % 2 == 1 ? "#d4b387" : "#dbbf95")
    line(x1: 0, y1: top, x2: cfg.width, y2: top, stroke: "#b89566", strokeWidth: 4)
    for k in 0 ..< 5 {
      let y = top + 20 + random("g\(i)\(k)") * (plank - 40)
      let x = random("gx\(i)\(k)") * cfg.width
      path("M \(x) \(y) q 120 \(-8 + random("gq\(i)\(k)") * 16) 260 0", fill: Paint.none, stroke: "#c4a173", strokeWidth: 3, opacity: 0.7)
    }
  }
  rect(x: h.x - 30, y: h.kickerY - 40, width: max(700, Double(gd.title.unicodeScalars.count) * h.titleSize * 0.95 + 80), height: h.badgeY - h.kickerY + 76, rx: 24, fill: gd.palette.cream, opacity: 0.94)
}

/// manual: 組み立て説明書の白い紙 (方眼)
public func PaperBackdrop() {
  let cfg = useVideoConfig()
  rect(width: cfg.width, height: cfg.height, fill: "#fcfcfb")
  var d = ""
  var x = 0.0
  while x <= cfg.width { d += "M \(x) 0 V \(cfg.height) "; x += 40 }
  var y = 0.0
  while y <= cfg.height { d += "M 0 \(y) H \(cfg.width) "; y += 40 }
  path(d, fill: Paint.none, stroke: "#e6e8ea", strokeWidth: 1.5)
}

/// 型に応じた背景
public func GuideBackdrop() {
  switch useGuide().variant {
  case .screen: ScreenBackdrop()
  case .topdown: TableTop()
  case .manual: PaperBackdrop()
  case .room: GuideRoom()
  }
}

/// 全体の枠: シリーズ名・タイトル・字幕バー・進捗・クレジット
public func GuideFrame(scenes: [(start: Double, end: Double)]) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let gd = useGuide()
  let palette = gd.palette, layout = gd.layout
  let h = layout.header
  let sub = layout.subtitle
  let n = Double(scenes.count)
  let gap = 14.0
  let segW = (sub.w - gap * (n - 1)) / max(1, n)
  let sec = frame / fps
  // 木目の上では進捗とクレジットの色を濃くする
  let panel = gd.variant == .topdown
  g(fontFamily: gd.font) {
    LayoutProbe.group(.chrome, "見出し") {
      if !gd.kicker.isEmpty {
        text(gd.kicker, x: h.x, y: h.kickerY, fontSize: 22, fontWeight: 800, fill: palette.primary, letterSpacing: 4)
      }
      text(gd.title, x: h.x, y: h.titleY, fontSize: h.titleSize, fontWeight: 800, fill: palette.ink)
    }
    if gd.captions {
      LayoutProbe.group(.chrome, "字幕バー", rect: CGRect(x: sub.x, y: sub.y, width: sub.w, height: sub.h)) {}
      rect(x: sub.x, y: sub.y, width: sub.w, height: sub.h, rx: 18, fill: palette.cream, stroke: "#ddd5c4", strokeWidth: 2)
    }
    LayoutProbe.group(.chrome, "進捗バー", rect: CGRect(x: sub.x, y: layout.progressY, width: sub.w, height: 6)) {}
    for (i, s) in scenes.enumerated() {
      let p = interpolate(sec, [s.start, s.end], [0, 1], .clamp)
      let x = sub.x + Double(i) * (segW + gap)
      rect(x: x, y: layout.progressY, width: segW, height: 6, rx: 3, fill: panel ? "#b89566" : "#d9d4c6")
      rect(x: x, y: layout.progressY, width: segW * p, height: 6, rx: 3, fill: palette.primary)
    }
    if !gd.credit.isEmpty {
      LayoutProbe.group(.chrome, "クレジット") {
        text(gd.credit, x: sub.x + sub.w, y: layout.creditY, fontSize: 20, fill: panel ? "#6b5534" : "#8a8a7c", textAnchor: .end)
      }
    }
  }
}

/// 工程バッジ (STEP 01 + 工程名)。シーンごとに表示
public func GuideStepBadge(index: Int, label: String, total: Int? = nil) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let gd = useGuide()
  let palette = gd.palette
  let s = spring(frame: frame, fps: fps, damping: 200)
  let h = gd.layout.header
  let step = "STEP \(String(format: "%02d", index + 1))" + (total.map { " / \(String(format: "%02d", $0))" } ?? "")
  let bw: Double = total != nil ? 190 : 124
  g(opacity: s, fontFamily: gd.font, transform: [.translate((1 - s) * -30, 0)]) {
    LayoutProbe.group(.chrome, "工程バッジ") {
      rect(x: h.x, y: h.badgeY - 22, width: bw, height: 44, rx: 22, fill: palette.primary)
      text(step, x: h.x + bw / 2, y: h.badgeY + 8, fontSize: 22, fontWeight: 800, fill: "#fff", textAnchor: .middle, letterSpacing: 1)
      text(label, x: h.x + bw + 20, y: h.badgeY + 11, fontSize: 34, fontWeight: 800, fill: palette.ink)
    }
  }
}

/// 字幕バーの中の文字 (中央揃え・各行の幅がそろうように折り返す)
public func GuideCaption(text content: String, fontFamily: String? = nil, fontSize: Double? = nil) {
  let frame = useCurrentFrame()
  let gd = useGuide()
  let sub = gd.layout.subtitle
  let o = interpolate(frame, [0, 4], [0, 1], InterpolateOptions(right: .clamp))
  let fam = fontFamily ?? gd.font
  let size = fontSize ?? sub.size
  let maxW = sub.w - 48
  let lines = balancedLines(content, maxWidth: maxW) { measureText($0, size: size, weight: 700, family: fam) }
  let lineH = size * 1.25
  let top = sub.y + (sub.h - lineH * Double(lines.count)) / 2
  let probe = TextLine("あ", family: fam, size: size, weight: 700)
  g(opacity: o) {
    LayoutProbe.group(.chrome, "字幕") {
      for (i, l) in lines.enumerated() {
        let baseline = top + Double(i) * lineH + (lineH - (probe.ascent + probe.descent)) / 2 + probe.ascent
        text(l, x: sub.x + sub.w / 2, y: baseline, fontSize: size, fontWeight: 700, fontFamily: fam, fill: gd.palette.ink, stroke: Paint.none, textAnchor: .middle)
      }
    }
  }
}

// ---------- 字幕の折り返し ----------

/// 折り返してよい位置で区切った塊 (空白のある言語は語、日本語・中国語は文節に近い塊)
public func breakUnits(_ s: String) -> [String] {
  if s.contains(" ") {
    // 空白の後で折る (空白は前の塊に付ける)
    var out: [String] = []
    var cur = ""
    for ch in s {
      cur.append(ch)
      if ch == " " { out.append(cur); cur = "" }
    }
    if !cur.isEmpty { out.append(cur) }
    return out
  }
  // 形態素の区切りのうち、前がひらがな・句読点で終わり、次が漢字・カタカナ・英数字で始まる所 (文節の始まり) で折る
  let ns = s as NSString
  let tok = CFStringTokenizerCreate(nil, ns, CFRangeMake(0, ns.length), kCFStringTokenizerUnitWordBoundary, Locale(identifier: "ja_JP") as CFLocale)
  var bounds: [Int] = []
  while CFStringTokenizerAdvanceToNextToken(tok).rawValue != 0 {
    let r = CFStringTokenizerGetCurrentTokenRange(tok)
    bounds.append(r.location)
  }
  func isHira(_ c: unichar) -> Bool { c >= 0x3041 && c <= 0x309F }
  func isNoStart(_ c: unichar) -> Bool {
    // 行頭に来てはいけない字 (句読点・閉じ括弧・長音・小書き)
    let str = String(utf16CodeUnits: [c], count: 1)
    return "、。，．,.!?！？)）」』〕]・ーっゃゅょァィゥェォッャュョぁぃぅぇぉ％%".contains(str)
  }
  var cuts: [Int] = []
  for b in bounds where b > 0 && b < ns.length {
    let prev = ns.character(at: b - 1)
    let next = ns.character(at: b)
    if isNoStart(next) { continue }
    if isHira(next) && isHira(prev) { continue }
    if isHira(next) && !isNoStart(prev) && !(prev == 0x3001 || prev == 0x3002) { continue }
    cuts.append(b)
  }
  var out: [String] = []
  var last = 0
  for c in cuts { out.append(ns.substring(with: NSRange(location: last, length: c - last))); last = c }
  out.append(ns.substring(from: last))
  return out.filter { !$0.isEmpty }
}

/// 幅 maxWidth に収まるよう塊を折り返し、行数を変えずに各行の幅ができるだけそろう幅で折り直す (CSS の text-wrap: balance)
public func balancedLines(_ s: String, maxWidth: Double, measure: (String) -> Double) -> [String] {
  let units = breakUnits(s)
  func wrap(_ w: Double) -> [String] {
    var lines: [String] = []
    var cur = ""
    for u in units {
      let next = cur + u
      if !cur.isEmpty && measure(next.trimmingCharacters(in: .whitespaces)) > w {
        lines.append(cur.trimmingCharacters(in: .whitespaces))
        cur = u
      } else {
        cur = next
      }
    }
    if !cur.isEmpty { lines.append(cur.trimmingCharacters(in: .whitespaces)) }
    return lines
  }
  let base = wrap(maxWidth)
  if base.count <= 1 { return base }
  var lo = 0.0, hi = maxWidth
  for _ in 0 ..< 16 {
    let mid = (lo + hi) / 2
    if wrap(mid).count <= base.count { hi = mid } else { lo = mid }
  }
  return wrap(hi)
}
