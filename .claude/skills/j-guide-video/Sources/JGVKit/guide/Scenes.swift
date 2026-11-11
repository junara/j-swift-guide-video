// よくあるシーンの型 (用意するもの・注意点・ビフォーアフター・まとめ)。どの型 (layout) でも、縦型でも使える。
// Stage の中に置き、Presenter など他の部品と組み合わせる。at はシーン先頭からのフレーム (n.at() / n.atPhrase() の戻り値)。
// 文言は呼び出し側が n.t() で渡す。長い文 (英語・ベトナム語など) は文字を小さくするか 2 行に折って枠に収める。
// style.notes: false のときは説明の文字 (ラベル・カードの文) を消し、絵・記号だけで伝わる形にする。
import Foundation

public typealias SceneBox = Box

private let NG_RED: Paint = "#d14b3b"
private let NG_TEXT: Paint = "#b8402f"
private let WARN: Paint = "#e0a83a"
private let INFO: Paint = "#4b8bbe"
private let MUTED: Paint = "#ddd5c4"

// ---------- 共通 ----------

private func isKata(_ c: Character) -> Bool { c.unicodeScalars.allSatisfy { ($0.value >= 0x30A1 && $0.value <= 0x30F6) || $0.value == 0x30FC } }
private func isLatin(_ c: Character) -> Bool { c.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0)) } }
// 同じ種類の文字が続く間 (カタカナ語・英数字の語) では折らない
private func sameRun(_ a: Character?, _ b: String) -> Bool {
  guard let a, let bc = b.first else { return false }
  return (isKata(a) && isKata(bc)) || (isLatin(a) && isLatin(bc))
}

/// 文を k 行に分ける (空白があれば単語の切れ目、無ければ文字の切れ目で、各行の幅がおおよそそろうように)。
/// 句読点・閉じ括弧・長音では次の行を始めない
private func splitLines(_ text: String, _ k: Int) -> [String] {
  let spaced = text.contains(" ")
  let units: [String] = spaced ? text.components(separatedBy: " ") : text.unicodeScalars.map { String($0) }
  let sep = spaced ? " " : ""
  let target = textWidth(text, 1) / Double(k)
  var lines: [String] = []
  var cur: [String] = []
  for u in units {
    let next = (cur + [u]).joined(separator: sep)
    let prev = cur.last?.last
    let noBreak = !spaced && ("、。，．,.！？!?）」』〕ー・".contains(u) || sameRun(prev, u))
    if !cur.isEmpty && !noBreak && lines.count < k - 1 && textWidth(next, 1) > target * 1.05 {
      // 超えた分が小さければこの行に含め、大きければ次の行へ
      let over = textWidth(next, 1) - target
      let under = target - textWidth(cur.joined(separator: sep), 1)
      if over > under {
        lines.append(cur.joined(separator: sep))
        cur = [u]
        continue
      }
      lines.append(next)
      cur = []
      continue
    }
    cur.append(u)
  }
  if !cur.isEmpty { lines.append(cur.joined(separator: sep)) }
  return lines
}

/// fitText の結果 (文字の大きさと行)
public struct FitResult {
  public var size: Double
  public var lines: [String]
}

/// 幅 maxW・高さ maxH に収まる文字サイズと行 (1 行に縮めるか、maxLines 行までに折るか、大きく読めるほうを選ぶ)。
/// size は最大の文字サイズ、min は最小 (これより小さくはせず、少しはみ出すのを許す)
public func fitText(_ text: String, _ maxW: Double, _ maxH: Double, _ size: Double, _ minSize: Double, _ maxLines: Int = 2) -> FitResult {
  // 呼び出し側が \n で改行した文は、その行のまま大きさだけ合わせる
  if text.contains("\n") {
    let lines = text.components(separatedBy: "\n")
    let sz = min(size, maxW / max(1, lines.map { textWidth($0, 1) }.max() ?? 1), maxH / (1.15 + Double(lines.count - 1) * 1.3))
    return FitResult(size: max(minSize, sz), lines: lines)
  }
  // 空白の無い文 (日本語など) は語の途中で折れやすいので、折るのは縮めるより十分大きく読めるときだけ
  let bias = text.contains(" ") ? 1.12 : 1.3
  var best = FitResult(size: min(size, (size * maxW) / max(1, textWidth(text, size)), maxH / 1.15), lines: [text])
  if maxLines >= 2 {
    for k in 2 ... maxLines {
      let lines = splitLines(text, k)
      if lines.count < k { break }
      let sz = min(size, maxW / max(1, lines.map { textWidth($0, 1) }.max() ?? 1), maxH / (1.15 + Double(k - 1) * 1.3))
      if sz > best.size * bias { best = FitResult(size: sz, lines: lines) }
    }
  }
  return FitResult(size: max(minSize, best.size), lines: best.lines)
}

/// fitText の結果を、中心 (x か左端, cy) に描く
public func FitT(x: Double, cy: Double, fit: FitResult, weight: Double = 800, color: Paint = "#353b35", anchor: TextAnchor = .middle) {
  T(fit.lines.joined(separator: "\n"), x: x, y: cy - (Double(fit.lines.count - 1) * fit.size * 1.3) / 2, size: fit.size, weight: weight, color: color, anchor: anchor)
}

/// シーン型の部品を置く既定の範囲 (部屋の横型は人物の右から観葉植物の手前まで、部屋の縦型はカウンターの下、ほかの型はコンテンツ領域の中央)。
/// 部品の外 (shared.swift など) で使うときは sceneBox(LAYOUT_LANDSCAPE, .room) のように配置と型を渡す
public func sceneBox(_ layout: GuideLayout, _ variant: GuideVariant) -> SceneBox {
  let c = layout.content
  let portrait = c.h > c.w
  if variant == .room {
    if portrait { return layout.closeUp }
    let x = layout.presenter.x + 320
    let right = min(c.x + c.w - 20, layout.plantX - 80)
    return Box(x: x, y: c.y + 20, w: right - x, h: layout.counterY + layout.counterH - 30 - (c.y + 20))
  }
  return portrait ? Box(x: c.x, y: c.y + 40, w: c.w, h: c.h - 80) : Box(x: c.x + 160, y: c.y + 20, w: c.w - 320, h: c.h - 40)
}

/// 今の配置と型での sceneBox
public func useSceneBox() -> SceneBox {
  let gd = useGuide()
  return sceneBox(gd.layout, gd.variant)
}

/// 今いちばん新しく登場した項目 (at が来ている中で at が最大のもの) の番号。無ければ -1
private func activeIndex(_ frame: Double, _ ats: [Double]) -> Int {
  var acc = -1
  for (i, a) in ats.enumerated() where frame >= a && (acc < 0 || a >= ats[acc]) { acc = i }
  return acc
}

// ---------- 用意するもの ----------

public struct PrepareItem {
  /// 道具の名前 (札に出す)
  public var label: String
  /// 登場するフレーム (名詞が読まれる句: n.atPhrase(行, 句))
  public var at: Double
  /// 道具を描く: { x, y, s in Mug(x: x, y: y, scale: s) } (底の中心 x, 底の y, 倍率)
  public var draw: (Double, Double, Double) -> Void
  /// scale 1 での幅・高さ (既定 240 × 230 = マグくらい)。幅は原点から遠いほうの端までの 2 倍 (注ぎ口・取っ手を含める)。並べる間隔と倍率に使う
  public var w: Double?
  public var h: Double?
  /// draw に渡す y: .bottom = 底 (横から見た道具)、.center = 中心 (真上から見た道具)。既定は手元俯瞰型なら .center、ほかは .bottom
  public var origin: Origin?
  public enum Origin { case bottom, center }
  public init(label: String, at: Double, w: Double? = nil, h: Double? = nil, origin: Origin? = nil, draw: @escaping (Double, Double, Double) -> Void) {
    self.label = label; self.at = at; self.w = w; self.h = h; self.origin = origin; self.draw = draw
  }
}

/// prepareLayout の 1 つ分 (底の中心 x、置き場の幅 slot、全部に共通の倍率 scale)
public struct PrepareSpot {
  public var x: Double
  public var slot: Double
  public var scale: Double
}

/// counter の並び方 (PrepareItems と同じ計算)。道具ごとの底の中心 x と、全部に共通の倍率 scale を返す (底の y は counterY)。
/// 次の工程で道具を同じ位置・大きさから始めるため、shared.swift で
/// `prepareLayout([(380, nil), (260, 180)], sceneBox(LAYOUT_LANDSCAPE, .room))` のように求めて両方の工程で使う
public func prepareLayout(_ items: [(w: Double?, h: Double?)], _ box: SceneBox, maxScale: Double = 1) -> [PrepareSpot] {
  let count = Double(max(1, items.count))
  // 置き場の幅: 7 割は均等 (札の幅)、3 割は道具の幅に比例させ、全部を同じ倍率で描く (大きさの関係を保つ)
  let ws = items.map { $0.w ?? 240 }
  let sumW = ws.reduce(0, +) == 0 ? 1 : ws.reduce(0, +)
  let slots = ws.map { box.w * (0.7 / count + (0.3 * $0) / sumW) }
  var scale = maxScale
  for (i, it) in items.enumerated() { scale = min(scale, min((slots[i] - 24) / ws[i], (box.h - 30) / (it.h ?? 230))) }
  var x = box.x
  return slots.map { slot in
    defer { x += slot }
    return PrepareSpot(x: x + slot / 2, slot: slot, scale: scale)
  }
}

public enum PrepareVariant { case counter, cards }

/// 「用意するもの」。items が at に順に現れる。
/// variant .counter (部屋の横型の既定): 人物の右のカウンターに上から落ちて並び、天板の前面に名前の札が付く。
/// variant .cards (それ以外の既定): 範囲 box の中にカードを格子に並べ、カードの中に道具が落ちてくる (2〜8 個)。
/// いちばん新しい道具の札は色が付く。notes: false のときは札を出さない (道具だけ)
public func PrepareItems(items: [PrepareItem], variant: PrepareVariant? = nil, box boxIn: SceneBox? = nil, maxScale: Double = 1) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let st = useStage()
  let gd = useGuide()
  let palette = gd.palette
  let portrait = st.content.h > st.content.w
  let mode = variant ?? (gd.variant == .room && !portrait ? .counter : .cards)
  // 真上から見た道具 (原点 = 中心) は、底の位置から高さの半分だけ上を渡す
  let originLift = { (it: PrepareItem, s: Double) -> Double in
    (it.origin ?? (gd.variant == .topdown ? .center : .bottom)) == .center ? ((it.h ?? 230) * s) / 2 : 0
  }
  let box = boxIn ?? useSceneBox()
  let cur = activeIndex(frame, items.map { $0.at })
  let count = max(1, items.count)

  if mode == .counter {
    let spots = prepareLayout(items.map { ($0.w, $0.h) }, box, maxScale: maxScale)
    let s = spots.first?.scale ?? 1
    let tagY = st.counterY + st.counterH / 2
    for (i, it) in items.enumerated() {
      let w = it.w ?? 240
      let x = spots[i].x, slot = spots[i].slot
      let u = dropAt(frame, fps, it.at)
      let tag = spring(frame: frame - it.at - jsRound(fps * 0.25), fps: fps, damping: 200)
      let fit = fitText(it.label, slot - 30, st.counterH - 14, 26, 14, 3)
      let tagW = min(slot - 10, (fit.lines.map { textWidth($0, fit.size) }.max() ?? 0) + 30)
      let tagH = min(st.counterH - 8, fit.size * (1.7 + Double(fit.lines.count - 1) * 1.3))
      let active = i == cur
      if u <= 0.001 { continue }
      g(opacity: u) { Shadow(x: x, y: st.counterY + 4, w: w * s * 0.85) }
      g(opacity: min(1, u * 4)) { it.draw(x, st.counterY - 320 * (1 - u) - originLift(it, s), s) }
      if gd.notes && tag > 0.01 {
        // 天板の前面に下げた札
        g(opacity: tag, transform: [.translate(x, tagY + (1 - tag) * -14)]) {
          rect(x: -tagW / 2, y: -tagH / 2, width: tagW, height: tagH, rx: min(18, tagH / 2), fill: active ? palette.primary : palette.cream, stroke: palette.ink, strokeWidth: 3)
          FitT(x: 0, cy: 0, fit: fit, color: active ? "#ffffff" : palette.ink)
        }
      }
    }
    return
  }

  // カードの格子: 道具がいちばん大きく描ける列数を選ぶ
  let gap = 20.0
  let labelH: Double = gd.notes ? 64 : 0
  let maxW = max(items.map { $0.w ?? 240 }.max() ?? 1, 1)
  let maxH = max(items.map { $0.h ?? 230 }.max() ?? 1, 1)
  var cols = 1
  var bestS = -1.0
  for c in 1 ... count {
    let r = Double((count + c - 1) / c)
    let cw = min(420, (box.w - gap * Double(c - 1)) / Double(c))
    let ch = min(400, (box.h - gap * (r - 1)) / r)
    let sc = min((cw - 40) / maxW, (ch - labelH - 40) / maxH)
    if sc > bestS + 0.01 { cols = c; bestS = sc }
  }
  let rows = (count + cols - 1) / cols
  let cw = min(420, (box.w - gap * Double(cols - 1)) / Double(cols))
  let ch = min(400, (box.h - gap * Double(rows - 1)) / Double(rows))
  let gy = box.y + (box.h - (ch * Double(rows) + gap * Double(rows - 1))) / 2
  for (i, it) in items.enumerated() {
    let r = i / cols
    let inRow = r == rows - 1 ? count - cols * r : cols // 最後の段は中央に寄せる
    let rowW = cw * Double(inRow) + gap * Double(inRow - 1)
    let cx = box.x + (box.w - rowW) / 2 + Double(i % cols) * (cw + gap) + cw / 2
    let top = gy + Double(r) * (ch + gap)
    let w = it.w ?? 240
    let h = it.h ?? 230
    let s = min(maxScale, (cw - 40) / w, (ch - labelH - 40) / h)
    let ground = top + ch - labelH - 18
    let pop = spring(frame: frame - it.at, fps: fps, damping: 14, stiffness: 150)
    let u = dropAt(frame, fps, it.at + 3)
    let active = i == cur
    let fit = fitText(it.label, cw - 30, labelH - 10, 28, 15)
    if pop <= 0.001 { continue }
    g(opacity: min(1, pop * 2), transform: [.translate(cx, top + ch / 2), .scale(pop), .translate(-cx, -(top + ch / 2))]) {
      rect(x: cx - cw / 2, y: top, width: cw, height: ch, rx: 22, fill: "#ffffff", stroke: active ? palette.primary : palette.ink, strokeWidth: active ? 6 : 4, filter: .shadow)
      // w・h が実物より小さくても、道具がカードの外へはみ出さないように切り抜く
      g(clip: .rect(x: cx - cw / 2, y: top, width: cw, height: ch, rx: 22)) {
        g(opacity: u) { Shadow(x: cx, y: ground + 4, w: w * s * 0.85) }
        if u > 0.001 { g(opacity: min(1, u * 4)) { it.draw(cx, ground - 120 * (1 - u) - originLift(it, s), s) } }
      }
      if gd.notes {
        rect(x: cx - cw / 2 + 10, y: top + ch - labelH, width: cw - 20, height: labelH - 10, rx: 14, fill: active ? palette.primary : palette.cream)
        FitT(x: cx, cy: top + ch - labelH / 2 - 5, fit: fit, color: active ? "#ffffff" : palette.ink)
      }
    }
  }
}

// ---------- 注意点 ----------

/// ng = 赤い ✕ / ok = ✓ / warn = ⚠ / info = i
public enum NoteKind { case ng, ok, warn, info }

public struct NoteItem {
  public var text: String
  public var kind: NoteKind
  /// 登場するフレーム (1 行に 1 枚なら n.at(i, 0.1))
  public var at: Double
  /// 小さな絵。原点 = 絵の中心で、80 × 80 くらいに収まるように描く (カードの大きさに合わせて拡大・縮小される)
  public var icon: (() -> Void)?
  public init(text: String, kind: NoteKind, at: Double, icon: (() -> Void)? = nil) {
    self.text = text; self.kind = kind; self.at = at; self.icon = icon
  }
}

/// 種類ごとの丸い記号 (原点 = 中心、半径 r)。warn は三角
public func NoteMark(x: Double, y: Double, kind: NoteKind, r: Double = 22) {
  let palette = useGuide().palette
  let sw = r * 0.25
  if kind == .warn {
    let k = r * 1.25
    g(transform: [.translate(x, y)]) {
      path("M 0 \(-k) L \(k * 0.98) \(k * 0.72) L \(-k * 0.98) \(k * 0.72) Z", fill: WARN, stroke: palette.ink, strokeWidth: 3, strokeLinejoin: .round)
      path("M 0 \(-k * 0.42) V \(k * 0.18) M 0 \(k * 0.46) v 0.5", stroke: "#ffffff", strokeWidth: sw, strokeLinecap: .round)
    }
    return
  }
  let fill = kind == .ng ? NG_RED : kind == .ok ? palette.primary : INFO
  let d = r * 0.4
  g(transform: [.translate(x, y)]) {
    circle(r: r, fill: fill, stroke: palette.ink, strokeWidth: 3)
    switch kind {
    case .ng:
      path("M \(-d) \(-d) L \(d) \(d) M \(d) \(-d) L \(-d) \(d)", stroke: "#ffffff", strokeWidth: sw, strokeLinecap: .round)
    case .ok:
      path("M \(-r * 0.45) 0 L \(-r * 0.12) \(r * 0.34) L \(r * 0.5) \(-r * 0.36)", fill: "none", stroke: "#ffffff", strokeWidth: sw, strokeLinecap: .round, strokeLinejoin: .round)
    default:
      path("M 0 \(-r * 0.5) v 0.5 M 0 \(-r * 0.1) V \(r * 0.52)", stroke: "#ffffff", strokeWidth: sw, strokeLinecap: .round)
    }
  }
}

/// 「注意点」のカード。items が at に順に現れ、縦に積まれる (範囲 box の中で上下中央)。
/// 左に小さな絵 (icon) と種類の記号、右に文。いま読んでいるカード (いちばん新しいもの) は枠が太くなる。
/// notes: false のときは文を出さず、絵と記号だけの四角いタイルを横に並べる
public func NoteCards(items: [NoteItem], box boxIn: SceneBox? = nil, maxRow: Double = 116) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let gd = useGuide()
  let palette = gd.palette
  let box = boxIn ?? useSceneBox()
  let cur = activeIndex(frame, items.map { $0.at })
  let count = Double(max(1, items.count))
  let hasIcon = items.contains { $0.icon != nil }

  if !gd.notes {
    let tile = min(170, (box.w - 24 * (count - 1)) / count, box.h)
    let x0 = box.x + (box.w - (tile * count + 24 * (count - 1))) / 2
    let cy = box.y + box.h / 2
    for (i, it) in items.enumerated() {
      let s = spring(frame: frame - it.at, fps: fps, damping: 14, stiffness: 150)
      let cx = x0 + Double(i) * (tile + 24) + tile / 2
      if s <= 0.001 { continue }
      g(opacity: min(1, s * 2), transform: [.translate(cx, cy), .scale(s)]) {
        rect(x: -tile / 2, y: -tile / 2, width: tile, height: tile, rx: tile * 0.18, fill: "#ffffff", stroke: i == cur ? palette.primary : palette.ink, strokeWidth: i == cur ? 6 : 4, filter: .shadow)
        if let icon = it.icon {
          g(transform: [.scale(tile / 120)]) { icon() }
          NoteMark(x: tile * 0.32, y: -tile * 0.32, kind: it.kind, r: tile * 0.15)
        } else {
          NoteMark(x: 0, y: 0, kind: it.kind, r: tile * 0.3)
        }
      }
    }
    return
  }

  let rowH = min(maxRow, box.h / count)
  let cardH = rowH * 0.84
  let y0 = box.y + (box.h - rowH * count) / 2 + (rowH - cardH) / 2
  let iconW = hasIcon ? cardH * 1.05 : 0
  let markR = hasIcon ? cardH * 0.19 : cardH * 0.26
  let pad = cardH * 0.22
  let textX = box.x + pad + (hasIcon ? iconW + cardH * 0.12 : markR * 2 + cardH * 0.2)
  for (i, it) in items.enumerated() {
    let s = spring(frame: frame - it.at, fps: fps, damping: 14, stiffness: 150)
    let cy = y0 + Double(i) * rowH + cardH / 2
    let active = i == cur
    let fit = fitText(it.text, box.x + box.w - pad - textX, cardH - 12, min(36, cardH * 0.38), 18)
    let ix = box.x + pad + iconW / 2
    if s <= 0.001 { continue }
    g(opacity: min(1, s * 2), transform: [.translate((1 - s) * 60, 0)]) {
      rect(x: box.x, y: cy - cardH / 2, width: box.w, height: cardH, rx: min(24, cardH * 0.3), fill: "#ffffff", stroke: active ? palette.primary : palette.ink, strokeWidth: active ? 6 : 4, filter: .shadow)
      if let icon = it.icon { g(transform: [.translate(ix, cy), .scale(cardH / 100)]) { icon() } }
      if hasIcon && it.icon != nil {
        NoteMark(x: ix + iconW * 0.36, y: cy - cardH * 0.24, kind: it.kind, r: markR)
      } else if hasIcon {
        // ほかのカードに絵があってこのカードに無いときは、絵の枠の中央に記号を大きく描く
        NoteMark(x: ix, y: cy, kind: it.kind, r: cardH * 0.26)
      } else {
        NoteMark(x: box.x + pad + markR, y: cy, kind: it.kind, r: markR)
      }
      FitT(x: textX, cy: cy, fit: fit, weight: 900, color: it.kind == .ng ? NG_TEXT : palette.ink, anchor: .start)
    }
  }
}

// ---------- ビフォー・アフター ----------

public enum BeforeAfterMode { case split, wipe }

/// ビフォー・アフターの比較。before / after は描く範囲 (画面座標の SceneBox) を受け取って絵を描く関数。
/// mode .split: 2 枚のパネルを並べる (範囲が横長なら左右、縦長なら上下)。before は beforeAt に、after は at に現れ、間に矢印が伸びる。
/// mode .wipe: 1 枚のパネルで、at から dur 秒かけて仕切りが左から右へ動き、after が現れる。
/// 見出し (ビフォー / アフター) は lang に合わせて自動。labels で差し替えられる。見出しは構図の一部なので notes: false でも消さない
public func BeforeAfter(before: (SceneBox) -> Void, after: (SceneBox) -> Void, at: Double, mode: BeforeAfterMode = .split, beforeAt: Double? = nil,
                        box boxIn: SceneBox? = nil, dur: Double = 1.2, labels: (String, String)? = nil) {
  let n = useNarration()
  let gd = useGuide()
  let palette = gd.palette
  let box = boxIn ?? useSceneBox()
  let L = guideLabels(gd.lang)
  let (bLabel, aLabel) = labels ?? (L.before, L.after)
  let start = beforeAt ?? max(0, n.at(0, -0.4))
  let inS = spring(frame: n.frame - start, fps: n.fps, damping: 16, stiffness: 120)
  let pill = { (x: Double, y: Double, label: String, isAfter: Bool, opacity: Double) in
    let fit = fitText(label, 260, 44, 28, 18)
    let w = (fit.lines.map { textWidth($0, fit.size) }.max() ?? 0) + 40
    g(opacity: opacity) {
      rect(x: x, y: y, width: w, height: 48, rx: 24, fill: isAfter ? palette.primary : "#8a8577", stroke: palette.ink, strokeWidth: 3)
      FitT(x: x + w / 2, cy: y + 24, fit: fit, weight: 900, color: "#ffffff")
    }
  }
  let panel = { (b: SceneBox, content: () -> Void) in
    rect(x: b.x, y: b.y, width: b.w, height: b.h, rx: 24, fill: palette.cream, stroke: palette.ink, strokeWidth: 4, filter: .shadow)
    g(clip: .rect(x: b.x, y: b.y, width: b.w, height: b.h, rx: 24), content)
    rect(x: b.x, y: b.y, width: b.w, height: b.h, rx: 24, fill: "none", stroke: palette.ink, strokeWidth: 4)
  }
  let pop = { (s: Double, b: SceneBox, content: () -> Void) in
    let cx = b.x + b.w / 2
    let cy = b.y + b.h / 2
    if s <= 0.001 { return }
    g(opacity: min(1, s * 1.5), transform: [.translate(cx, cy), .scale(s), .translate(-cx, -cy)], content)
  }

  if mode == .wipe {
    let span = max(1, dur * n.fps) // dur が 0 でも入力範囲が増加するように
    let u = interpolate(n.frame, [at, at + span], [0, 1], .clamp(easing: Easing.inOut(Easing.cubic)))
    let dx = box.x + box.w * u
    let handle = interpolate(n.frame, [at - 8, at, at + span + 4, at + span + 14], [0, 1, 1, 0], .clamp)
    let lw = textWidth(aLabel, 28) + 80
    let bw = textWidth(bLabel, 28) + 80
    pop(inS, box) {
      panel(box) {
        before(box)
        if u > 0 {
          g(clip: .rect(x: box.x, y: box.y, width: dx - box.x, height: box.h)) {
            rect(x: box.x, y: box.y, width: box.w, height: box.h, fill: palette.cream)
            after(box)
          }
        }
      }
      pill(box.x + 20, box.y + 20, aLabel, true, interpolate(dx, [box.x + lw * 0.6, box.x + lw], [0, 1], .clamp))
      pill(box.x + box.w - 20 - (bw - 40), box.y + 20, bLabel, false, interpolate(dx, [box.x + box.w - bw, box.x + box.w - bw * 0.6], [1, 0], .clamp))
      if handle > 0 {
        g(opacity: handle) {
          line(x1: dx, y1: box.y + 4, x2: dx, y2: box.y + box.h - 4, stroke: palette.ink, strokeWidth: 12)
          line(x1: dx, y1: box.y + 4, x2: dx, y2: box.y + box.h - 4, stroke: "#ffffff", strokeWidth: 6)
          circle(cx: dx, cy: box.y + box.h / 2, r: 30, fill: "#ffffff", stroke: palette.ink, strokeWidth: 4)
          path("M \(dx - 8) \(box.y + box.h / 2 - 10) l -10 10 l 10 10 M \(dx + 8) \(box.y + box.h / 2 - 10) l 10 10 l -10 10",
               fill: "none", stroke: palette.ink, strokeWidth: 4, strokeLinecap: .round, strokeLinejoin: .round)
        }
      }
    }
    return
  }

  // split: 範囲が横長なら左右、縦長なら上下に並べる
  let horiz = box.w >= box.h * 1.1
  let gap = 90.0
  let pb = horiz ? Box(x: box.x, y: box.y, w: (box.w - gap) / 2, h: box.h) : Box(x: box.x, y: box.y, w: box.w, h: (box.h - gap) / 2)
  let pa = horiz ? Box(x: box.x + pb.w + gap, y: pb.y, w: pb.w, h: pb.h) : Box(x: pb.x, y: box.y + pb.h + gap, w: pb.w, h: pb.h)
  let aS = spring(frame: n.frame - at, fps: n.fps, damping: 14, stiffness: 140)
  let arrow = interpolate(n.frame, [at - 10, at + 4], [0, 1], .clamp)
  let ac = Pt(box.x + box.w / 2, box.y + box.h / 2)
  let rot: Double = horiz ? 0 : 90
  let len = 52 * arrow
  pop(inS, pb) {
    panel(pb) { before(pb) }
    pill(pb.x + 20, pb.y + 20, bLabel, false, 1)
  }
  if arrow > 0 {
    g(opacity: arrow, transform: [.translate(ac.x, ac.y), .rotate(rot)]) {
      path("M -26 0 L \(-26 + len) 0", stroke: palette.ink, strokeWidth: 16, strokeLinecap: .round)
      path("M -26 0 L \(-26 + len) 0", stroke: palette.accent, strokeWidth: 8, strokeLinecap: .round)
      if arrow > 0.6 { path("M 8 -18 L 28 0 L 8 18", fill: "none", stroke: palette.ink, strokeWidth: 8, strokeLinecap: .round, strokeLinejoin: .round) }
    }
  }
  pop(aS, pa) {
    panel(pa) { after(pa) }
    pill(pa.x + 20, pa.y + 20, aLabel, true, 1)
  }
  Burst(at: at + 4, x: pa.x + pa.w / 2, y: pa.y + pa.h / 2, r: min(160, min(pa.w, pa.h) * 0.55), count: 14, color: palette.accent)
}

// ---------- まとめ ----------

/// 「まとめ」のチェックリスト。カードが at に現れて項目が並び、各項目がその at でチェックされる (読み上げに合わせて n.at(i))。
/// 全部チェックしたら doneAt にカードの右上へ CheckBadge と Burst。content (完成品など、画面座標で描く) は doneAt にカードの手前へふわっと出る
/// (カードと重ならないよう、box を狭めてカードを片側に寄せ、空いた所に描く)。
/// notes: false のときは文の代わりに灰色の帯を描き、チェックが入っていく様子だけを見せる
public func SummaryList(items: [(label: String, at: Double)], at: Double? = nil, doneAt: Double? = nil, box boxIn: SceneBox? = nil, maxRow: Double = 100, _ content: (() -> Void)? = nil) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let gd = useGuide()
  let palette = gd.palette
  let box = boxIn ?? useSceneBox()
  let count = Double(max(1, items.count))
  let start = at ?? max(0, (items.first?.at ?? 0) - jsRound(fps * 0.5))
  let done = doneAt ?? (items.last?.at ?? 0) + jsRound(fps * 0.8)
  let cur = activeIndex(frame, items.map { $0.at })
  let pad = 28.0
  let rowH = min(maxRow, (box.h - pad * 2) / count)
  let r = rowH * 0.26
  let size = min(38, rowH * 0.42)
  let textX = pad + r * 2 + rowH * 0.3
  // 文の長さに合わせたカードの幅 (範囲の 55%〜100%)
  let longest = max(items.map { textWidth($0.label, size) }.max() ?? 1, 1)
  let cardW = gd.notes ? min(box.w, max(box.w * 0.55, textX + longest + pad * 1.5)) : min(box.w, 520)
  let cardH = rowH * count + pad * 2
  let cx0 = box.x + (box.w - cardW) / 2
  let cy0 = box.y + (box.h - cardH) / 2
  let inS = spring(frame: frame - start, fps: fps, damping: 16, stiffness: 130)
  let finale = spring(frame: frame - done, fps: fps, damping: 200)
  if inS <= 0.001 { return }
  let mx = cx0 + cardW / 2
  let my = cy0 + cardH / 2
  g(opacity: min(1, inS * 1.5), transform: [.translate(mx, my), .scale(inS), .translate(-mx, -my)]) {
    rect(x: cx0, y: cy0, width: cardW, height: cardH, rx: 26, fill: "#ffffff", stroke: palette.ink, strokeWidth: 4, filter: .shadow)
    for (i, it) in items.enumerated() {
      let ry = cy0 + pad + Double(i) * rowH + rowH / 2
      let show = spring(frame: frame - start - 4 - Double(i) * 3, fps: fps, damping: 200)
      let c = interpolate(frame - it.at, [0, 10], [0, 1], .clamp)
      let checked = frame >= it.at
      let len = r * 1.7
      let fit = fitText(it.label, cardW - textX - pad, rowH - 8, size, 18)
      g(opacity: show) {
        if i == cur && frame < done {
          rect(x: cx0 + 10, y: ry - rowH / 2 + 4, width: cardW - 20, height: rowH - 8, rx: 14, fill: palette.primary, opacity: 0.1)
        }
        circle(cx: cx0 + pad + r, cy: ry, r: r, fill: checked ? palette.primary : "#ffffff", stroke: checked ? palette.ink : MUTED, strokeWidth: 4)
        if c > 0 {
          path("M \(cx0 + pad + r * 0.55) \(ry) L \(cx0 + pad + r * 0.9) \(ry + r * 0.36) L \(cx0 + pad + r * 1.5) \(ry - r * 0.36)",
               fill: "none", stroke: "#ffffff", strokeWidth: r * 0.24, strokeLinecap: .round, strokeLinejoin: .round, strokeDasharray: [len], strokeDashoffset: len * (1 - c))
        }
        if gd.notes {
          FitT(x: cx0 + textX, cy: ry, fit: fit, weight: checked ? 900 : 700, color: checked ? palette.ink : "#8a8577", anchor: .start)
        } else {
          // 文の代わりの帯 (長さは項目ごとに少し変える)
          rect(x: cx0 + textX, y: ry - rowH * 0.1, width: (cardW - textX - pad) * (0.62 + 0.3 * (Double((i * 7) % 5) / 4)), height: rowH * 0.2, rx: rowH * 0.1,
               fill: checked ? palette.primary : MUTED, opacity: checked ? 0.55 : 1)
        }
      }
    }
  }
  // 完成品はカードの手前に描く (重ならないよう、box を狭めてカードの横に置く)
  if let content { g(opacity: finale, content) }
  Burst(at: done, x: cx0 + cardW - 24, y: cy0 + 24, r: 110, count: 14, color: palette.accent)
  CheckBadge(x: cx0 + cardW - 24, y: cy0 + 24, at: done, r: 50)
}
