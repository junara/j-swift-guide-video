// ガイドレイアウト用の道具 (輪郭線つきフラットイラスト)。
// どれも原点 = 底の中心。x, y は画面座標、scale で拡大、angle (度, 時計回り) で傾ける。
// 持ち手などの位置は *_PARTS のローカル座標を place() で画面座標に変換して手の位置に使う。
import Foundation

/// 道具の持ち手・注ぎ口などのローカル座標の一覧 (KETTLE_PARTS.handle のように名前で読む。全部は .items)
@dynamicMemberLookup
public struct Parts {
  public let items: [(String, Pt)]
  public init(_ items: [(String, Pt)]) { self.items = items }
  public init(_ items: KeyValuePairs<String, Pt>) { self.items = items.map { ($0.key, $0.value) } }
  public subscript(dynamicMember key: String) -> Pt {
    guard let p = items.first(where: { $0.0 == key })?.1 else { fatalError("parts に \(key) がありません (\(items.map { $0.0 }))") }
    return p
  }
  public subscript(_ key: String) -> Pt? { items.first { $0.0 == key }?.1 }
}

/// 道具の共通ラッパー: 位置・回転・倍率と輪郭線の属性をまとめて付ける
public func Placed(x: Double, y: Double, scale: Double = 1, angle: Double = 0, _ content: () -> Void) {
  let palette = useGuide().palette
  g(stroke: palette.ink, strokeWidth: 6, strokeLinecap: .round, strokeLinejoin: .round,
    transform: [.translate(x, y), .rotate(angle), .scale(scale)], content)
}

/// flip (左右反転) した道具のパーツ位置: place(x, y, s, angle, flipPart(XXX_PARTS.handle))
public func flipPart(_ p: Pt) -> Pt { Pt(-p.x, p.y) }

/// flip のときだけ左右反転する g (Placed の中で使う。angle は画面上の傾きのまま)
func Flip(on: Bool, _ content: () -> Void) {
  g(transform: on ? [.scale(-1, 1)] : [], content)
}

/// 置いた道具の影
public func Shadow(x: Double, y: Double? = nil, w: Double) {
  let layout = useGuide().layout
  ellipse(cx: x, cy: y ?? layout.counterY + 4, rx: w / 2, ry: w * 0.06, fill: "#8f7a5c", opacity: 0.25)
}

// ---------- やかん ----------
/// やかんの持つ所: handle = 取っ手の上、spout = 注ぎ口の先。flip: true のときは flipPart(KETTLE_PARTS.spout) で求める
public let KETTLE_PARTS = Parts(["handle": Pt(0, -228), "spout": Pt(182, -132)])
/// やかん (注ぎ口が右。flip: true で左向き。左へ注ぐときは flip にして angle を負にする)
public func Kettle(x: Double, y: Double, scale: Double = 1, angle: Double = 0, color: Paint? = nil, flip: Bool = false) {
  let palette = useGuide().palette
  Placed(x: x, y: y, scale: scale, angle: angle) { Flip(on: flip) {
    path("M -60 -150 Q -62 -228 0 -228 Q 62 -228 60 -150", fill: Paint.none, strokeWidth: 20)
    path("M -60 -150 Q -62 -228 0 -228 Q 62 -228 60 -150", fill: Paint.none, stroke: palette.hair, strokeWidth: 9)
    path("M 88 -62 L 176 -138 L 188 -126 L 104 -28 Z", fill: color ?? palette.metal)
    path("M -105 0 Q -118 -118 -62 -152 L 62 -152 Q 118 -118 105 0 Z", fill: color ?? palette.metal)
    ellipse(cx: 0, cy: -154, rx: 58, ry: 12, fill: "#86a99d")
    circle(cx: 0, cy: -172, r: 11, fill: palette.hair)
    path("M -70 -40 Q 0 -25 70 -40", fill: Paint.none, stroke: "#5c7d72", strokeWidth: 5)
  } }
}

// ---------- マグ ----------
public let MUG_PARTS = Parts(["handle": Pt(140, -95), "rim": Pt(0, -175)])
public func Mug(x: Double, y: Double, scale: Double = 1, angle: Double = 0, fill: Double = 0, drink: Paint = "#684732", color: Paint? = nil) {
  let palette = useGuide().palette
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M 105 -140 C 210 -165 210 -20 100 -45", fill: Paint.none, strokeWidth: 30)
    path("M 105 -140 C 210 -165 210 -20 100 -45", fill: Paint.none, stroke: color ?? palette.accent, strokeWidth: 18)
    path("M -122 -175 L -110 -36 Q -104 0 0 0 Q 104 0 110 -36 L 122 -175 Z", fill: color ?? palette.accent)
    ellipse(cx: 0, cy: -175, rx: 122, ry: 30, fill: "#f7dfbc")
    ellipse(cx: 0, cy: -172, rx: 104, ry: 21, fill: fill > 0.05 ? drink : "#f4e9d3")
    path("M -78 -128 V -48", stroke: "#efc3a0", strokeWidth: 10)
  }
}

// ---------- 湯のみ ----------
public let YUNOMI_PARTS = Parts(["rim": Pt(0, -128), "grip": Pt(-62, -70)])
public func Yunomi(x: Double, y: Double, scale: Double = 1, angle: Double = 0, fill: Double = 0, tea: Paint = "#b8c46a", color: Paint? = nil) {
  let palette = useGuide().palette
  let level = -10 - 108 * min(1, max(0, fill))
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M -66 -128 L -56 -10 Q -54 0 -40 0 L 40 0 Q 54 0 56 -10 L 66 -128 Z", fill: color ?? "#f1ece0")
    if fill > 0.02 { ellipse(cx: 0, cy: level, rx: 56 - (level + 128) * 0.08, ry: 10, fill: tea, strokeWidth: 4) }
    ellipse(cx: 0, cy: -128, rx: 66, ry: 13, fill: Paint.none)
    path("M -60 -60 L 60 -60", stroke: palette.primary, strokeWidth: 14, opacity: 0.75)
  }
}

// ---------- 急須 (横手) ----------
public let TEAPOT_PARTS = Parts(["grip": Pt(196, -92), "spout": Pt(-168, -104), "lid": Pt(0, -150)])
public func Teapot(x: Double, y: Double, scale: Double = 1, angle: Double = 0, color: Paint = "#9a5b3a", lidOpen: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M 92 -72 L 192 -104 L 200 -80 L 98 -50 Z", fill: "#6e3f28")
    path("M -92 -52 L -164 -98 L -156 -112 L -84 -80 Z", fill: color)
    path("M -100 0 Q -126 -92 -72 -124 L 72 -124 Q 126 -92 100 0 Z", fill: color)
    g(transform: [.translate(lidOpen * 40, -lidOpen * 90), .rotate(lidOpen * 25)]) {
      ellipse(cx: 0, cy: -126, rx: 70, ry: 13, fill: "#b0704c")
      circle(cx: 0, cy: -146, r: 13, fill: "#6e3f28")
    }
    path("M -80 -40 Q 0 -26 80 -40", fill: Paint.none, stroke: "#7a4529", strokeWidth: 5)
  }
}

// ---------- 茶筒・スプーン ----------
public func Canister(x: Double, y: Double, scale: Double = 1, angle: Double = 0, label: String = "茶", lidOpen: Double = 0) {
  let palette = useGuide().palette
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -58, y: -170, width: 116, height: 170, rx: 14, fill: palette.primary)
    rect(x: -58, y: -120, width: 116, height: 64, fill: palette.cream)
    text(label, x: 0, y: -76, fontSize: 44, fontWeight: 800, fontFamily: "\"Hiragino Mincho ProN\", serif", fill: palette.primary, stroke: Paint.none, textAnchor: .middle)
    g(transform: [.translate(lidOpen * 110, lidOpen * 160)]) {
      rect(x: -62, y: -200, width: 124, height: 40, rx: 10, fill: "#264b3b")
    }
  }
}

public let SPOON_PARTS = Parts(["grip": Pt(130, 0), "bowl": Pt(-40, 0)])
public func Spoon(x: Double, y: Double, scale: Double = 1, angle: Double = 0, leaves: Bool = false) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M -10 0 L 150 0", strokeWidth: 18)
    path("M -10 0 L 150 0", stroke: "#c9c2b2", strokeWidth: 8)
    ellipse(cx: -40, cy: 0, rx: 38, ry: 24, fill: "#d8d2c4")
    if leaves { ellipse(cx: -40, cy: -8, rx: 30, ry: 14, fill: "#4f6b2f", strokeWidth: 3) }
  }
}

// ---------- ドリップバッグ ----------
// open: 上の帯を破り取る (0→1)、hooks: 左右のフックを広げる (0→1)、wet: お湯で濡れる (0→1)、water: 中の湯量 (0→1)
public let DRIPBAG_PARTS = Parts([
  "holdL": Pt(-75, -110),
  "holdR": Pt(75, -110),
  "strip": Pt(58, -176),
  "hookL": Pt(-150, -196),
  "hookR": Pt(150, -196),
  "top": Pt(0, -158),
])
public func DripBag(x: Double, y: Double, scale: Double = 1, angle: Double = 0, open: Double = 0, hooks: Double = 0, wet: Double = 0, water: Double = 0) {
  let paper: Paint = "#f3ead7"
  let h = min(1, max(0, hooks))
  let hook = { (dir: Double) -> String in
    let sx = 75 * dir
    let tx = (75 + 75 * h) * dir
    return "M \(sx) \(-176) L \(tx) \(-196 + 6 * (1 - h)) L \(tx) \(-168) L \(sx) \(-122) Z"
  }
  Placed(x: x, y: y, scale: scale, angle: angle) {
    // 広げたフック (本体の後ろ)
    if h > 0.02 {
      path(hook(-1), fill: "#e6dcc5")
      path(hook(1), fill: "#e6dcc5")
    }
    rect(x: -75, y: -160, width: 150, height: 160, rx: 8, fill: paper)
    if wet > 0 { rect(x: -75, y: -160 * wet * 0.9, width: 150, height: 160 * wet * 0.9, rx: 8, fill: "#c9a77f", strokeWidth: 0, opacity: 0.75) }
    rect(x: -75, y: -160, width: 150, height: 160, rx: 8, fill: Paint.none)
    // 開け口: 粉が見える
    if open > 0.5 {
      ellipse(cx: 0, cy: -158, rx: 66, ry: 14, fill: "#5a3b26", strokeWidth: 4)
      if water > 0 { ellipse(cx: 0, cy: -158, rx: 60 * min(1, water + 0.2), ry: 11 * min(1, water + 0.2), fill: "#a0703f", strokeWidth: 3, opacity: 0.85) }
    } else {
      path("M -70 -160 H 70", strokeWidth: 4, strokeDasharray: [10, 8])
    }
    // 折りたたんだフック (本体の表)
    if h < 0.5 {
      g(strokeWidth: 4, opacity: 1 - h * 2) {
        path("M -56 -140 L -56 -96 M 56 -140 L 56 -96")
      }
    }
    path("M -36 -70 Q 0 -90 36 -70 Q 0 -50 -36 -70 Z", fill: "#d9c7a3", strokeWidth: 4)
    // 破り取る上の帯
    g(opacity: 1 - max(0, open - 0.7) / 0.3, transform: [.translate(open * 140, -open * 120), .rotate(open * 35, 0, -176)]) {
      rect(x: -75, y: -192, width: 150, height: 32, rx: 6, fill: paper)
    }
  }
}

// ---------- 液体・湯気・粒 ----------

/// a から b へ流れ落ちる液体
public func Stream(from: Pt, to: Pt, color: Paint = "#9ccbe0", width: Double = 16, active: Bool = true) {
  guard active else { return }
  let frame = useCurrentFrame()
  let wob = sin(frame * 0.6) * 6
  let d = "M \(from.x) \(from.y) C \(from.x + 30) \(from.y + 20) \(to.x + wob) \((from.y + to.y) / 2) \(to.x) \(to.y)"
  path(d, fill: Paint.none, stroke: color, strokeWidth: width, strokeLinecap: .round, opacity: 0.9)
  circle(cx: to.x, cy: to.y, r: width * 0.9, fill: color, opacity: 0.5)
}

public struct PourOptions {
  /// 持ち上げ始めるフレームと、元の位置に戻し終わるフレーム (n.atPhrase() などをそのまま)
  public var from: Double
  public var to: Double
  /// 置いてあるときの原点 (底の中心)
  public var rest: Pt
  /// 注ぎ口を持ってくる位置 (注ぎ先の少し上。例: マグの縁の 40px 上)
  public var target: Pt
  /// 注ぐときの傾き (度、時計回り)。注ぎ口が右の道具 (やかん) は正、左 (急須・左へ傾ける湯のみ) は負
  public var angle: Double
  /// 道具の倍率 (描くときの scale と同じ値)
  public var scale: Double
  /// 注ぎ口・持つ所のローカル座標 (KETTLE_PARTS.spout / KETTLE_PARTS.handle、TEAPOT_PARTS.spout / .grip など)
  public var spout: Pt
  public var grip: Pt
  public init(from: Double, to: Double, rest: Pt, target: Pt, angle: Double, scale: Double = 1, spout: Pt, grip: Pt) {
    self.from = from; self.to = to; self.rest = rest; self.target = target; self.angle = angle; self.scale = scale; self.spout = spout; self.grip = grip
  }
}

public struct PourState {
  /// 道具に渡す原点と角度
  public var pos: Pt
  public var tilt: Double
  /// 手の位置
  public var grip: Pt
  /// Stream の始点
  public var spout: Pt
  /// 注いでいる間 true
  public var pouring: Bool
  /// 注いだ量 0→1 (注ぎ先の fill に)
  public var poured: Double
  /// 手を伸ばす度合い 0→1→0 (手は mix(定位置, grip, reach))
  public var reach: Double
}

/// 道具を持ち上げて傾けて注ぎ、元に戻す動き (やかん・急須・湯のみ・洗剤ボトルなど、注ぎ口と持つ所がある道具ならどれでも)。
/// frame が [from, to] の間に 持ち上げ → 傾ける → 注ぐ → 起こす → 戻す。傾けたとき注ぎ口がちょうど target に来るよう原点を逆算する。
/// 区間が短いときは各動きの時間を縮めるので、[from, to] は 1 秒程度でも動く
public func pourFrom(_ frame: Double, _ fps: Double, _ o: PourOptions) -> PourState {
  let from = o.from
  let to = max(o.to, from + 2)
  let span = to - from
  let a = min(fps * 0.27, span * 0.15) // 傾け始め
  let b = min(fps * 0.53, span * 0.3) // 傾け終わり
  let l = min(fps * 0.4, span * 0.25) // 持ち上げ・戻しの時間
  let lift = interpolate(frame, [from, from + l], [0, 1], .clamp)
  let back = interpolate(frame, [to - l, to], [0, 1], .clamp)
  let k = interpolate(frame, [from + a, from + b, to - b, to - a], [0, 1, 1, 0], .clamp)
  let tilt = o.angle * k
  // 傾けきったときに注ぎ口が target に来る原点
  let rel = place(0, 0, o.scale, o.angle, o.spout)
  let pourPos = Pt(o.target.x - rel.x, o.target.y - rel.y)
  let pos = mix(o.rest, pourPos, lift * (1 - back))
  let r = min(fps * 0.33, max(1, span * 0.2))
  return PourState(
    pos: pos,
    tilt: tilt,
    grip: place(pos.x, pos.y, o.scale, tilt, o.grip),
    spout: place(pos.x, pos.y, o.scale, tilt, o.spout),
    pouring: k > 0.8,
    poured: interpolate(frame, [from + b, to - b], [0, 1], .clamp),
    reach: interpolate(frame, [from - r, from, to, to + r], [0, 1, 1, 0], .clamp)
  )
}

/// ゆらゆら立ちのぼる湯気
public func Steam(x: Double, y: Double, count: Int = 3, height: Double = 120, opacity: Double = 0.6) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let palette = useGuide().palette
  let t = frame / fps
  g(fill: Paint.none, stroke: palette.ink, strokeWidth: 5, strokeLinecap: .round) {
    for i in 0 ..< count {
      let p = jsMod(t * 0.45 + Double(i) / Double(count), 1)
      let sx = x + (Double(i) - Double(count - 1) / 2) * 34
      let sy = y - p * height * 0.6
      path("M \(sx) \(sy) q 16 -\(height * 0.2) 0 -\(height * 0.4) q -16 -\(height * 0.2) 0 -\(height * 0.4)", opacity: opacity * sin(p * Double.pi))
    }
  }
}

/// 茶葉・コーヒー粉などの粒 (中心 x,y・半径 spread に count 個)
public func Grains(x: Double, y: Double, spread: Double = 40, count: Int = 14, color: Paint = "#4f6b2f", size: Double = 9, seed: String = "g") {
  for i in 0 ..< count {
    let gx = x + (random("\(seed)x\(i)") - 0.5) * spread * 2
    let gy = y + (random("\(seed)y\(i)") - 0.5) * spread * 0.6
    ellipse(cx: gx, cy: gy, rx: size, ry: size * 0.45, fill: color, transform: [.rotate(random("\(seed)r\(i)") * 180, gx, gy)])
  }
}

// ---------- 注釈 ----------

/// 道具の近くに出す小さなラベル
public func Callout(x: Double, y: Double, text label: String, at: Double = 0) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let gd = useGuide()
  let s = spring(frame: frame - at, fps: fps, damping: 200)
  let w = textWidth(label, 26) + 48
  guard gd.notes else { return }
  g(opacity: s, transform: [.translate(x, y + (1 - s) * 16)]) {
    LayoutProbe.group(.mark, "注釈「\(label)」", rect: CGRect(x: -w / 2, y: -26, width: w, height: 52)) {
      rect(x: -w / 2, y: -26, width: w, height: 52, rx: 26, fill: "#ffffff", stroke: gd.palette.ink, strokeWidth: 3)
      T(label, x: 0, y: 0, size: 26, weight: 700, color: gd.palette.ink)
    }
  }
}

/// 完了のチェックマーク
public func CheckBadge(x: Double, y: Double, at: Double, r: Double = 44) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let palette = useGuide().palette
  let s = spring(frame: frame - at, fps: fps, damping: 12, stiffness: 150)
  let c = interpolate(frame - at, [6, 16], [0, 1], .clamp)
  let len = r * 1.6
  g(transform: [.translate(x, y), .scale(s)]) {
    LayoutProbe.group(.mark, "チェック", rect: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)) {}
    circle(r: r, fill: palette.primary, stroke: palette.ink, strokeWidth: 5)
    path("M \(-r * 0.42) 0 L \(-r * 0.1) \(r * 0.32) L \(r * 0.45) \(-r * 0.32)", fill: Paint.none, stroke: "#fff", strokeWidth: r * 0.2,
         strokeLinecap: .round, strokeLinejoin: .round, strokeDasharray: [len], strokeDashoffset: len * (1 - c))
  }
}

/// 拡大カードの小手順ラベル (label を at フレームから出す)
public struct CloseUpStep {
  public var label: String
  public var at: Double
  public init(_ label: String, at: Double) { self.label = label; self.at = at }
  public init(label: String, at: Double) { self.label = label; self.at = at }
}

/// 手元を大きく見せる拡大カード。steps の小手順ラベル (①②…) が、指定フレームで順に切り替わる。
/// 中身は画面座標で描く (カードの範囲は useStage().closeUp)。シーン頭で開き、シーン終わりに縮んで消える。
/// 前後の工程も拡大カードのときは enter: false / exit: false で、工程をまたいでカードを開いたままにする
/// (前の工程は exit: false、次の工程は enter: false。両方そろえないと、境目でカードが消える・急に現れる)。
/// enter: false のとき at は使われない。つなぐ工程どうしは box も同じにする (違うと境目で枠が跳ぶ)。
public func CloseUp(label: String? = nil, steps: [CloseUpStep] = [], at: Double? = nil, box boxIn: Box? = nil, enter: Bool = true, exit: Bool = true, _ content: () -> Void) {
  let n = useNarration()
  let gd = useGuide()
  let palette = gd.palette
  let box = boxIn ?? gd.layout.closeUp
  let start = at ?? n.at(0, -0.4)
  let inS = enter ? spring(frame: n.frame - start, fps: n.fps, damping: 16, stiffness: 120) : 1
  // シーンの最後のフレーム (durationInFrames - 1) より前に消えきるようにする (最後のフレームに縮んだカードが残らない)
  let outS = exit ? interpolate(n.frame, [n.durationInFrames - 12, n.durationInFrames - 2], [1, 0], .clamp) : 1
  let s = inS * outS
  var cur = -1
  for (i, st) in steps.enumerated() where n.frame >= st.at { cur = i }
  // 番号 (①②…) はここで付けるので、label の頭に書いた番号は外す (「① ① 〜」と二重にならないように)
  let curLabel = cur >= 0 ? steps[cur].label.replacingOccurrences(of: "^\\s*[①-⑳]\\s*", with: "", options: .regularExpression) : ""
  let headText = label ?? guideLabels(gd.lang).closeUp
  // 小手順ラベルがカード左上の見出しに重ならないよう、長いときは右へずらす
  let headEnd = box.x + 34 + textWidth(headText, 24) + 24
  // 入りきらない長さなら文字を小さくする
  let room = box.x + box.w - 20 - headEnd
  let fs = cur >= 0 ? max(22, min(32, (32 * (room - 90)) / max(1, textWidth(curLabel, 32)))) : 32
  let pillW = cur >= 0 ? textWidth(curLabel, fs) + 90 : 0
  let marks = Array("①②③④⑤⑥⑦⑧⑨")
  let cx = box.x + box.w / 2
  let cy = box.y + box.h / 2
  let lx = min(box.x + box.w - pillW / 2 - 20, max(cx, headEnd + pillW / 2))
  g(opacity: min(1, s * 1.5), transform: [.translate(cx, cy), .scale(s), .translate(-cx, -cy)]) {
    LayoutProbe.group(.cover, "拡大カード", rect: CGRect(x: box.x, y: box.y, width: box.w, height: box.h)) {}
    rect(x: box.x, y: box.y, width: box.w, height: box.h, rx: 26, fill: palette.cream, stroke: palette.ink, strokeWidth: 4, filter: .shadow)
    LayoutProbe.group(.chrome, "拡大カードの見出し") {
      T(headText, x: box.x + 34, y: box.y + 38, size: 24, weight: 700, color: palette.ink, anchor: .start)
    }
    g(clip: .rect(x: box.x, y: box.y, width: box.w, height: box.h, rx: 26), content)
    if gd.notes && cur >= 0 {
      // 切り替わりで空白が出ないよう、新しいラベルは半透明から始める
      g(opacity: interpolate(n.frame - steps[cur].at, [0, 5], [cur == 0 ? 0 : 0.5, 1], .clamp)) {
        // 腕などが重なっても読めるよう、ラベルの下に座布団を敷く
        LayoutProbe.group(.chrome, "小手順ラベル「\(curLabel)」", rect: CGRect(x: lx - pillW / 2, y: box.y + 20, width: pillW, height: 52)) {
          rect(x: lx - pillW / 2, y: box.y + 20, width: pillW, height: 52, rx: 26, fill: palette.cream, stroke: palette.ink, strokeWidth: 3)
          T("\(cur < marks.count ? String(marks[cur]) : String(cur + 1)) \(curLabel)", x: lx, y: box.y + 46, size: fs, weight: 800, color: palette.ink)
        }
      }
    }
  }
}
