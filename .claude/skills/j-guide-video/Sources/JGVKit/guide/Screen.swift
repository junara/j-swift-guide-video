// 画面操作型 (layout: "guide-screen") の部品: スマホ / ブラウザの枠、カーソル・タップ、スポットライト、ズーム、UI 部品。
// 画面の中身は「設計座標」(スマホ 390x844 / ブラウザ 1280x720) で描き、枠が実寸に縮小する。
import Foundation

public let PHONE = (w: 390.0, h: 844.0)
public let BROWSER = (w: 1280.0, h: 720.0, bar: 56.0)

/// 設計座標と画面座標の対応。x, y = 枠の左上、w, h = 画面 (中身) の実寸 px、k = 倍率
public struct ScreenSpace {
  public var x: Double
  public var y: Double
  public var w: Double
  public var h: Double
  public var k: Double
  /// 設計座標の点 → 画面座標 (Tap / Cursor / moveAlong の位置に)
  public func pt(_ p: Pt) -> Pt { Pt(x + p.x * k, y + p.y * k) }
  /// 設計座標の矩形 → 画面座標の矩形 (Spotlight の rect に)
  public func rect(_ r: Box) -> Box { Box(x: x + r.x * k, y: y + r.y * k, w: r.w * k, h: r.h * k) }
  /// 設計座標の矩形 (UIButton の x y w h など) の中心 → 画面座標。h を省くと 52 (UIButton の既定)
  public func center(x rx: Double, y ry: Double, w rw: Double, h rh: Double = 52) -> Pt { pt(Pt(rx + rw / 2, ry + rh / 2)) }
  public func center(_ r: Box) -> Pt { center(x: r.x, y: r.y, w: r.w, h: r.h) }
  /// 画面の範囲 (Spotlight の area に)
  public var box: Box { Box(x: x, y: y, w: w, h: h) }
}

private func screenSpace(_ x: Double, _ y: Double, _ k: Double, _ w: Double, _ h: Double) -> ScreenSpace {
  ScreenSpace(x: x, y: y, w: w * k, h: h * k, k: k)
}

/// スマホの設計座標 (390x844) → 画面座標。PhoneFrame(x: ph.x, y: ph.y, h: ph.h) と同じ変換。
/// 例: let ph = phoneSpace(x: 560, y: 226, h: 652); let p = ph.center(SAVE_BTN); Tap(x: p.x, y: p.y)
public func phoneSpace(x: Double, y: Double, h: Double) -> ScreenSpace { screenSpace(x, y, h / PHONE.h, PHONE.w, PHONE.h) }

/// ブラウザの設計座標 (1280x720、アドレスバーの下が y 56) → 画面座標。BrowserFrame(x: br.x, y: br.y, w: br.w) と同じ変換
public func browserSpace(x: Double, y: Double, w: Double) -> ScreenSpace { screenSpace(x, y, w / BROWSER.w, BROWSER.w, BROWSER.h) }

/// スマホ。x, y = 左上、h = 画面の高さ (px)。中身は 390x844 の設計座標で描く
public func PhoneFrame(x: Double, y: Double, h: Double, time: String = "9:41", dark: Bool = false, _ content: () -> Void = {}) {
  let palette = useGuide().palette
  let k = h / PHONE.h
  let fg: Paint = dark ? "#fff" : "#1f2422"
  g(transform: [.translate(x, y), .scale(k)]) {
    rect(x: -18, y: -18, width: PHONE.w + 36, height: PHONE.h + 36, rx: 66, fill: "#1f2422", stroke: palette.ink, strokeWidth: 6 / k)
    g(clip: .rect(x: 0, y: 0, width: PHONE.w, height: PHONE.h, rx: 50)) {
      rect(width: PHONE.w, height: PHONE.h, fill: dark ? "#111" : "#fbf9f4")
      content()
      // ステータスバー
      text(time, x: 40, y: 32, fontSize: 17, fontWeight: 700, fill: fg)
      rect(x: 320, y: 20, width: 30, height: 14, rx: 4, fill: "none", stroke: fg, strokeWidth: 2)
      rect(x: 323, y: 23, width: 20, height: 8, rx: 2, fill: fg)
      rect(x: 140, y: 10, width: 110, height: 32, rx: 16, fill: "#1f2422")
      rect(x: 130, y: PHONE.h - 14, width: 130, height: 5, rx: 3, fill: fg, opacity: 0.5)
    }
  }
}

/// ブラウザ。x, y = 左上、w = 幅 (px)。中身は 1280x720 の設計座標 (アドレスバーの下が y = 56)
public func BrowserFrame(x: Double, y: Double, w: Double, url: String = "", _ content: () -> Void = {}) {
  let palette = useGuide().palette
  let k = w / BROWSER.w
  g(transform: [.translate(x, y), .scale(k)]) {
    g(clip: .rect(x: 0, y: 0, width: BROWSER.w, height: BROWSER.h, rx: 18)) {
      rect(width: BROWSER.w, height: BROWSER.h, fill: "#fbf9f4")
      content()
      rect(width: BROWSER.w, height: BROWSER.bar, fill: "#ece7dc")
      for (i, c) in ["#e57b6b", "#e8b65a", "#79b77a"].enumerated() {
        circle(cx: 28 + Double(i) * 24, cy: 28, r: 8, fill: Paint(c))
      }
      rect(x: 110, y: 13, width: 760, height: 30, rx: 15, fill: "#fff")
      text(url, x: 130, y: 34, fontSize: 17, fontFamily: "\"SF Mono\", Menlo, monospace", fill: "#6b6f68")
    }
    rect(width: BROWSER.w, height: BROWSER.h, rx: 18, fill: "none", stroke: palette.ink, strokeWidth: 5 / k)
  }
}

/// ズーム: focus (画面座標) を中心に zoom 倍。中身全体に掛ける
public func Camera(focus: Pt, zoom: Double, _ content: () -> Void) {
  g(transform: [.translate(focus.x, focus.y), .scale(zoom), .translate(-focus.x, -focus.y)], content)
}

/// スポットライト: area (既定はコンテンツ領域) のうち rect 以外を暗くする (見出し・字幕バーは暗くしない)。
/// 画面操作型では area: PH.box (phoneSpace の戻り値の範囲) を渡して、スマホの画面の中だけを暗くする (右のポイントメモを暗くしない)
public func Spotlight(rect r0: Box, opacity: Double, r: Double = 16, area: Box? = nil) {
  let layout = useGuide().layout
  if opacity <= 0 { return }
  let x = r0.x, y = r0.y, w = r0.w, h = r0.h
  // area を渡したときはその範囲だけ (はみ出さない)、既定はコンテンツ領域より少し広く
  let c = area ?? Box(x: layout.content.x - 20, y: layout.content.y - 10, w: layout.content.w + 40, h: layout.content.h + 20)
  let d = "M \(c.x) \(c.y) H \(c.x + c.w) V \(c.y + c.h) H \(c.x) Z M \(x + r) \(y) H \(x + w - r) Q \(x + w) \(y) \(x + w) \(y + r) V \(y + h - r) Q \(x + w) \(y + h) \(x + w - r) \(y + h) H \(x + r) Q \(x) \(y + h) \(x) \(y + h - r) V \(y + r) Q \(x) \(y) \(x + r) \(y) Z"
  path(d, fill: "#1f2422", opacity: 0.4 * opacity, fillRule: .evenodd)
  rect(x: x, y: y, width: w, height: h, rx: r, fill: "none", stroke: "#f2c14e", strokeWidth: 5, opacity: opacity)
}

/// マウスカーソル (click 0〜1 で波紋)
public func Cursor(x: Double, y: Double, click: Double = 0, scale: Double = 1) {
  g(transform: [.translate(x, y), .scale(scale)]) {
    if click > 0 && click < 1 { circle(r: 14 + click * 34, fill: "none", stroke: "#315e4a", strokeWidth: 4, opacity: 1 - click) }
    path("M 0 0 L 0 34 L 9 26 L 16 41 L 23 38 L 16 23 L 28 22 Z", fill: "#fff", stroke: "#353b35", strokeWidth: 3, strokeLinejoin: .round)
  }
}

/// 指のタップ (press 0〜1: 押し込み、波紋)
public func Tap(x: Double, y: Double, press: Double = 0, scale: Double = 1) {
  g(transform: [.translate(x, y), .scale(scale)]) {
    if press > 0 && press < 1 { circle(r: 20 + press * 40, fill: "none", stroke: "#f2c14e", strokeWidth: 5, opacity: 1 - press) }
    circle(r: 26 - (press > 0 && press < 0.5 ? 6 : 0), fill: "#f1bc98", stroke: "#353b35", strokeWidth: 3, opacity: 0.85)
  }
}

/// カーソル / 指の移動: points を順にたどる (各区間 0.4 秒で滑らかに移動)
public func moveAlong(_ frame: Double, _ fps: Double, _ points: [(at: Double, p: Pt)]) -> Pt {
  guard let first = points.first else { return Pt(0, 0) }
  var cur = first.p
  for i in 1 ..< points.count {
    let at = points[i].at, p = points[i].p
    let t = min(1, max(0, (frame - at) / (fps * 0.4)))
    let e = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    cur = Pt(cur.x + (p.x - cur.x) * e, cur.y + (p.y - cur.y) * e)
  }
  return cur
}

/// クリック / タップの進み (at から 0.35 秒で 0→1)。pressed は押下中
public func pressAt(_ frame: Double, _ fps: Double, _ at: Double) -> (t: Double, pressed: Bool, done: Bool) {
  let t = (frame - at) / (fps * 0.35)
  return (t > 0 && t < 1 ? t : 0, t >= 0 && t < 0.4, t >= 0.4)
}

/// 文字列を at から cps 文字/秒でタイプした途中
public func typed(_ text: String, _ frame: Double, _ at: Double, _ fps: Double, _ cps: Double = 14) -> String {
  let chars = Array(text.unicodeScalars)
  let n = max(0, min(chars.count, Int((((frame - at) / fps) * cps).rounded(.down))))
  var s = String.UnicodeScalarView()
  s.append(contentsOf: chars[0 ..< n])
  return String(s)
}

// ---------- UI 部品 (設計座標で使う) ----------

public func UIText(_ content: String, x: Double, y: Double, size: Double = 18, weight: Double = 600, color: Paint = "#2b302d", anchor: TextAnchor = .start, mono: Bool = false) {
  let font = useGuide().font
  text(content, x: x, y: y, fontSize: size, fontWeight: weight, fontFamily: mono ? "\"SF Mono\", Menlo, monospace" : font, fill: color, textAnchor: anchor, dominantBaseline: .central)
}

public func UIButton(x: Double, y: Double, w: Double, h: Double = 52, label: String, pressed: Bool = false, outline: Bool = false, color: Paint? = nil, size: Double = 19) {
  let palette = useGuide().palette
  let s = pressed ? 0.94 : 1
  let cx = x + w / 2
  let cy = y + h / 2
  let c = color ?? palette.primary
  g(transform: [.translate(cx, cy), .scale(s), .translate(-cx, -cy)]) {
    rect(x: x, y: y, width: w, height: h, rx: h / 2.6, fill: outline ? "#fff" : c, stroke: outline ? "#cfc8b8" : "none", strokeWidth: 2)
    UIText(label, x: cx, y: cy, size: size, weight: 800, color: outline ? "#5b625b" : "#fff", anchor: .middle)
  }
}

public func UIField(x: Double, y: Double, w: Double, h: Double = 46, label: String? = nil, value: String? = nil, placeholder: String? = nil, focus: Bool = false,
                    caret: Bool = false, mono: Bool = false, select: Bool = false, size: Double = 18) {
  let palette = useGuide().palette
  if let label, !label.isEmpty { UIText(label, x: x, y: y - 14, size: size * 0.8, color: "#6b6f68") }
  rect(x: x, y: y, width: w, height: h, rx: 10, fill: "#fff", stroke: focus ? palette.primary : "#d6cfbf", strokeWidth: focus ? 3.5 : 2)
  let hasValue = !(value ?? "").isEmpty
  UIText((hasValue ? value! : (placeholder ?? "")) + (caret ? "▍" : ""), x: x + 14, y: y + h / 2, size: size, weight: hasValue ? 600 : 500, color: hasValue ? "#2b302d" : "#b0a998", mono: mono)
  if select { path("M \(x + w - 30) \(y + h / 2 - 4) l 8 9 l 8 -9", fill: "none", stroke: "#6b6f68", strokeWidth: 2.5, strokeLinecap: .round) }
}

/// アプリの上部バー (タイトル + 戻る)
public func UIAppBar(title: String, width: Double, back: Bool = false, y: Double = 50) {
  let palette = useGuide().palette
  rect(y: 0, width: width, height: y + 50, fill: palette.primary)
  if back { path("M 28 \(y + 25) l 12 -12 M 28 \(y + 25) l 12 12", stroke: "#fff", strokeWidth: 3.5, strokeLinecap: .round) }
  UIText(title, x: width / 2, y: y + 25, size: 20, weight: 800, color: "#fff", anchor: .middle)
}

/// 一覧の 1 行
public func UIListRow(x: Double, y: Double, w: Double, title: String, sub: String? = nil, right: String? = nil, badge: (text: String, color: Paint)? = nil, highlight: Double = 0, h: Double = 72) {
  let palette = useGuide().palette
  let hasSub = !(sub ?? "").isEmpty
  rect(x: x, y: y, width: w, height: h, fill: highlight > 0 ? palette.primary : "#fff", opacity: highlight > 0 ? 0.12 * highlight + 0.0 : 1)
  if highlight > 0 { rect(x: x, y: y, width: w, height: h, fill: "#fff", opacity: 1 - highlight * 0.12) }
  UIText(title, x: x + 18, y: y + (hasSub ? h * 0.36 : h / 2), size: 18, weight: 700)
  if hasSub { UIText(sub!, x: x + 18, y: y + h * 0.68, size: 14, color: "#8a8a7c") }
  if let right, !right.isEmpty { UIText(right, x: x + w - 18, y: y + (badge != nil ? h * 0.36 : h / 2), size: 18, weight: 800, anchor: .end) }
  if let badge {
    let bw = textWidth(badge.text, 13) + 20
    rect(x: x + w - 18 - bw, y: y + h * 0.56, width: bw, height: 22, rx: 11, fill: badge.color)
    UIText(badge.text, x: x + w - 18 - bw / 2, y: y + h * 0.56 + 11, size: 13, weight: 800, color: "#fff", anchor: .middle)
  }
  line(x1: x + 18, y1: y + h, x2: x + w, y2: y + h, stroke: "#ebe5d8", strokeWidth: 1.5)
}

/// 上から降りてくる通知バナー / トースト (show 0〜1)
public func UIBanner(x: Double, y: Double, w: Double, title: String, body: String? = nil, show: Double, color: Paint = "#fff") {
  let hasBody = !(body ?? "").isEmpty
  g(opacity: min(1, show * 2), transform: [.translate(0, (1 - show) * -60)]) {
    rect(x: x, y: y, width: w, height: hasBody ? 78 : 54, rx: 18, fill: color, stroke: "#d6cfbf", strokeWidth: 1.5, filter: .shadow)
    rect(x: x + 14, y: y + 14, width: 26, height: 26, rx: 7, fill: "#315e4a")
    UIText(title, x: x + 52, y: y + 27, size: 15, weight: 800)
    if hasBody { UIText(body!, x: x + 52, y: y + 54, size: 14, color: "#5b625b") }
  }
}

/// 画面の横に並べる「ポイントメモ」。items が at フレームで順に現れ、次の項目が来るとチェックが付く。
/// 画面操作型で、いま何をしているかを大きな文字で補う。
public func StepNotes(x: Double, y: Double, w: Double, items: [(label: String, at: Double)], size: Double = 34) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let n = useNarration()
  let gd = useGuide()
  let palette = gd.palette
  let marks = Array("①②③④⑤⑥⑦⑧⑨")
  let rowH = size * 2.4
  guard gd.notes else { return }
  for (i, it) in items.enumerated() {
    let s = spring(frame: frame - it.at, fps: fps, damping: 200)
    let next = i + 1 < items.count ? items[i + 1].at : n.durationInFrames - 8
    let done = interpolate(frame, [next - 4, next + 6], [0, 1], .clamp)
    let active = frame >= it.at && frame < next
    let yy = y + Double(i) * rowH
    g(opacity: s, transform: [.translate((1 - s) * 40, 0)]) {
      LayoutProbe.group(.chrome, "ポイントメモ", rect: CGRect(x: x, y: yy, width: w, height: rowH - 16)) {
        rect(x: x, y: yy, width: w, height: rowH - 16, rx: 20, fill: active ? "#fff" : palette.cream, stroke: active ? palette.primary : "#ddd5c4", strokeWidth: active ? 4 : 2)
        T(i < marks.count ? String(marks[i]) : String(i + 1), x: x + 30, y: yy + (rowH - 16) / 2, size: size, weight: 900, color: palette.primary, anchor: .start)
        T(it.label.replacingOccurrences(of: "^\\s*[①-⑳]\\s*", with: "", options: .regularExpression), x: x + 30 + size * 1.4, y: yy + (rowH - 16) / 2,
          size: size * 0.82, weight: active ? 900 : 700, color: palette.ink, anchor: .start)
        if done > 0 {
          g(opacity: done) {
            circle(cx: x + w - 40, cy: yy + (rowH - 16) / 2, r: 18, fill: palette.primary)
            path("M \(x + w - 49) \(yy + (rowH - 16) / 2) l 6 7 l 12 -13", fill: "none", stroke: "#fff", strokeWidth: 4, strokeLinecap: .round, strokeLinejoin: .round)
          }
        }
      }
    }
  }
}
