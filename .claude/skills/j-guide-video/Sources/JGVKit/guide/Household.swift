// 家事・掃除・台所でよく使う道具と効果 (デモで描いたものを汎用化したもの)
// すべて原点 = 底の中心 (例外は各コメントに記載)。持つ位置は *_PARTS にローカル座標で書き、place() で画面座標にする。
// 一覧画像は reference/props-catalog.png (jgv catalog で作り直せる)
import Foundation

private let GLOVE: Paint = "#f2c14e"
private let OIL: Paint = "#b07a2e"
private let STAIN: Paint = "#a88a5c"

private func useSec() -> Double {
  useCurrentFrame() / useVideoConfig().fps
}

// ---------- 電源 ----------

/// 壁のコンセント (原点 = 中心)
public func Outlet(x: Double, y: Double) {
  Placed(x: x, y: y) {
    rect(x: -36, y: -48, width: 72, height: 96, rx: 12, fill: "#f7f5ef")
    path("M -10 -20 v 18 M 10 -20 v 18", strokeWidth: 5)
  }
}

/// プラグ (原点 = 刃の付け根、刃は上向き)。cordFrom からコードを伸ばす
public func Plug(x: Double, y: Double, angle: Double = 0, cordFrom: Pt) {
  let palette = useGuide().palette
  let d = "M \(cordFrom.x) \(cordFrom.y) C \(cordFrom.x + 60) \(cordFrom.y + 20) \(x - 10) \(y + 120) \(x) \(y + 38)"
  g {
    path(d, fill: Paint.none, stroke: palette.ink, strokeWidth: 10, strokeLinecap: .round)
    path(d, fill: Paint.none, stroke: "#e8e4da", strokeWidth: 4, strokeLinecap: .round)
    Placed(x: x, y: y, angle: angle) {
      path("M -10 -14 v -16 M 10 -14 v -16", stroke: "#b9b4a8", strokeWidth: 6)
      rect(x: -24, y: -14, width: 48, height: 52, rx: 10, fill: "#e9e5db")
    }
  }
}

/// プラグを持つ所 (Plug のローカル座標、刃の付け根から本体の中ほど)
public let PLUG_PARTS = Parts(["grip": Pt(0, 22)])
/// 抜いたプラグの、差した位置からのずれ (既定: 左下へ) と傾き (度)
public let PLUG_AWAY = Pt(-60, 90)
public let PLUG_TILT = 25.0

/// plugSpots() の戻り値 (in = 差したプラグの原点、out = 抜いたプラグの原点)
public struct PlugSpots {
  public var `in`: Pt
  public var out: Pt
  public init(in i: Pt, out: Pt) { self.in = i; self.out = out }
}

/// コンセント (Outlet の中心) に対する、差したプラグと抜いたプラグの原点。
/// away で抜いた位置を変える (コードが右から来るなら Pt(60, 90) など)
public func plugSpots(_ outlet: Pt, _ away: Pt = PLUG_AWAY) -> PlugSpots {
  PlugSpots(in: Pt(outlet.x, outlet.y + 10), out: Pt(outlet.x + away.x, outlet.y + away.y))
}

public struct PlugMoveOptions {
  /// コンセントの中心 (Outlet(x:y:) と同じ)
  public var outlet: Pt
  /// 抜き始め (差し始め) と、抜き終わり (差し終わり) のフレーム。手はこの 0.4 秒前からプラグへ伸びる
  public var from: Double
  public var to: Double
  public var away: Pt
  public var tilt: Double
  public init(outlet: Pt, from: Double, to: Double, away: Pt = PLUG_AWAY, tilt: Double = PLUG_TILT) {
    self.outlet = outlet; self.from = from; self.to = to; self.away = away; self.tilt = tilt
  }
}

/// unplug() / plugIn() の戻り値
public struct PlugMove {
  public var pos: Pt
  public var angle: Double
  /// 抜けている度合い (0 = 差した状態、1 = 抜いた状態)
  public var out: Double
  /// 手の位置 (プラグを持つ所)。手は mix(手の今の位置, grip, reach)
  public var grip: Pt
  /// 手をプラグへ伸ばす度合い (from の 0.4 秒前から 0→1、その後は 1 のまま。手を離すときは visual 側で mix する)
  public var reach: Double
}

private func plugMove(_ frame: Double, _ fps: Double, _ o: PlugMoveOptions, _ dir: Double) -> PlugMove {
  let from = o.from
  let to = max(o.to, from + 1)
  let u = interpolate(frame, [from, to], [0, 1], .clamp)
  let s = u * u * (3 - 2 * u)
  // 抜けている度合い (0 = 差した状態、1 = 抜いた状態)
  let out = dir > 0 ? s : 1 - s
  let spots = plugSpots(o.outlet, o.away)
  let pos = mix(spots.in, spots.out, out)
  let angle = o.tilt * out
  return PlugMove(
    pos: pos,
    angle: angle,
    out: out,
    grip: place(pos.x, pos.y, 1, angle, PLUG_PARTS.grip),
    reach: interpolate(frame, [from - fps * 0.4, from], [0, 1], .clamp)
  )
}

/// プラグを抜く動き: [from, to] で差した位置 → 抜いた位置へ。PowerPlug(out: m.out) と手 (m.grip, m.reach) に使う
public func unplug(_ frame: Double, _ fps: Double, _ o: PlugMoveOptions) -> PlugMove { plugMove(frame, fps, o, 1) }
/// プラグを差す動き: [from, to] で抜いた位置 → 差した位置へ
public func plugIn(_ frame: Double, _ fps: Double, _ o: PlugMoveOptions) -> PlugMove { plugMove(frame, fps, o, -1) }

/// コンセントと、差した / 抜いたプラグをまとめて描く。outlet = コンセントの中心、cordFrom = コードの根元 (画面座標)、
/// out = 抜けている度合い (0 = 差した、1 = 抜いた。unplug() / plugIn() の out をそのまま)
public func PowerPlug(outlet: Pt, cordFrom: Pt, out: Double = 0, away: Pt = PLUG_AWAY, tilt: Double = PLUG_TILT) {
  let spots = plugSpots(outlet, away)
  let pos = mix(spots.in, spots.out, out)
  g {
    Outlet(x: outlet.x, y: outlet.y)
    Plug(x: pos.x, y: pos.y, angle: tilt * out, cordFrom: cordFrom)
  }
}

/// ブレーカー (分電盤の 1 回路分、原点 = 中心)。off: レバーを下げて切る (0 = 入、1 = 切)
public let BREAKER_PARTS = Parts(["leverOn": Pt(0, -24), "leverOff": Pt(0, 14)])
public func Breaker(x: Double, y: Double, scale: Double = 1, angle: Double = 0, off: Double = 0) {
  let palette = useGuide().palette
  let k = min(1, max(0, off))
  let lever = mix(BREAKER_PARTS.leverOn, BREAKER_PARTS.leverOff, k)
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -50, y: -66, width: 100, height: 132, rx: 12, fill: "#e9e5db")
    rect(x: -22, y: -44, width: 44, height: 84, rx: 8, fill: "#cfcbc1", strokeWidth: 4)
    rect(x: -17, y: lever.y - 16, width: 34, height: 32, rx: 6, fill: k > 0.5 ? "#9aa3a5" : palette.accent, strokeWidth: 4)
    path("M -30 54 h 60", stroke: "#b9b4a8", strokeWidth: 4)
  }
}

/// リモコン (原点 = 中心)。press: ボタンを押す (0→1 で電波が広がる)
public func Remote(x: Double, y: Double, scale: Double = 1, angle: Double = 0, press: Double = 0) {
  let palette = useGuide().palette
  Placed(x: x, y: y, scale: scale, angle: angle) {
    if press > 0 && press < 1 {
      for i in 0 ..< 3 {
        let i = Double(i)
        path("M \(-24 - i * 18) \(-86 - i * 18) Q 0 \(-104 - i * 24) \(24 + i * 18) \(-86 - i * 18)", fill: Paint.none, stroke: palette.accent, strokeWidth: 5,
             opacity: (1 - press) * (1 - i * 0.25))
      }
    }
    rect(x: -34, y: -70, width: 68, height: 140, rx: 18, fill: "#f4f2ec")
    rect(x: -22, y: -54, width: 44, height: 30, rx: 6, fill: "#cfe0d6", strokeWidth: 3)
    circle(cx: 0, cy: 0, r: 13, fill: press > 0 && press < 0.4 ? "#c4473a" : "#e06a5a", strokeWidth: 3)
    path("M -16 28 h 10 M 6 28 h 10 M -16 46 h 10 M 6 46 h 10", stroke: "#9a958a", strokeWidth: 5)
  }
}

// ---------- 水まわり ----------

/// 蛇口が壁から伸びる側
public enum FaucetSide { case left, right }

/// 蛇口 (原点 = 吐水口)。side: 壁から伸びる側、height: 吐水口から管の上端までの高さ
public func Faucet(x: Double, y: Double, scale: Double = 1, angle: Double = 0, side: FaucetSide = .left, height: Double = 90) {
  let s: Double = side == .left ? -1 : 1
  let d = "M \(s * 260) \(-height) H \(s * 40) Q 0 \(-height) 0 \(-height + 40) V -8"
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path(d, fill: Paint.none, strokeWidth: 42)
    path(d, fill: Paint.none, stroke: "#c9ced0", strokeWidth: 30)
    rect(x: side == .left ? -150 : 120, y: -height - 46, width: 50, height: 30, rx: 8, fill: "#d98a5c")
  }
}

/// シンクの槽 (原点 = 槽の上辺の中心)。拡大カードで蛇口と組み合わせる
public func Sink(x: Double, y: Double, scale: Double = 1, angle: Double = 0, w: Double = 760, h: Double = 420) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -w / 2 - 30, y: -30, width: w + 60, height: h + 60, rx: 30, fill: "#d7dcdc")
    rect(x: -w / 2, y: 0, width: w, height: h, rx: 26, fill: "#b7c1c3")
    ellipse(cx: 0, cy: h - 50, rx: 36, ry: 14, fill: "#7d8a8e", strokeWidth: 4)
  }
}

/// 洗面器 (ぬるま湯・洗剤液)。suds: 泡、steam: 湯気
public let BASIN_PARTS = Parts(["water": Pt(0, -66)])
public func Basin(x: Double, y: Double, scale: Double = 1, angle: Double = 0, suds: Double = 0, steam: Bool = false, color: Paint = "#e8a07a") {
  let t = useSec()
  let palette = useGuide().palette
  Placed(x: x, y: y, scale: scale, angle: angle) {
    if steam {
      for (i, sx) in [-30.0, 0, 30].enumerated() {
        let k = jsMod(t * 0.5 + Double(i) / 3, 1)
        path("M \(sx) \(-86 - k * 50) q 10 -14 0 -28 q -10 -14 0 -28", fill: Paint.none, stroke: palette.ink, strokeWidth: 4, opacity: 0.5 * sin(k * Double.pi))
      }
    }
    path("M -92 -70 L -70 -6 Q -66 0 -56 0 L 56 0 Q 66 0 70 -6 L 92 -70 Z", fill: color)
    ellipse(cx: 0, cy: -70, rx: 92, ry: 14, fill: "#a8d4e6")
    if suds > 0.01 {
      g(fill: "#fff", stroke: "#b9c6cc", strokeWidth: 2, opacity: suds) {
        for (i, sx) in [-56.0, -30, -4, 22, 48].enumerated() {
          circle(cx: sx, cy: -72 + Double(i % 2) * 4, r: 9 + Double(i % 3) * 3)
        }
      }
    }
    path("M -100 -70 H 100", strokeWidth: 8)
  }
}

// ---------- 掃除道具 ----------

/// ゴム手袋 (立てた片手)
public func Glove(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path(
      "M -28 0 L -30 -50 Q -52 -66 -54 -86 Q -52 -96 -42 -92 L -30 -80 L -32 -130 Q -32 -140 -22 -140 Q -14 -140 -14 -130 L -12 -96 L -10 -146 Q -10 -156 0 -156 Q 10 -156 10 -146 L 10 -96 L 14 -138 Q 14 -148 24 -148 Q 32 -146 32 -136 L 28 -94 L 34 -120 Q 36 -128 44 -126 Q 50 -122 48 -112 L 36 -50 L 32 0 Z",
      fill: GLOVE
    )
    rect(x: -34, y: -22, width: 70, height: 22, rx: 6, fill: "#e3ad36")
  }
}

/// ゴム手袋をはめた手 (Presenter・SleeveArm の手の位置に重ねる、原点 = 手の中心)
public func GloveHand(x: Double, y: Double, r: Double = 24, on: Double = 1) {
  let palette = useGuide().palette
  if on <= 0.01 { return }
  g(stroke: palette.ink, strokeWidth: 5, opacity: on) {
    circle(cx: x, cy: y, r: r, fill: GLOVE)
    circle(cx: x - r * 0.75, cy: y - r * 0.35, r: r * 0.38, fill: GLOVE, strokeWidth: 4)
  }
}

/// スポンジ (横から)。foam: 泡
public let SPONGE_PARTS = Parts(["grip": Pt(0, -40)])
public func Sponge(x: Double, y: Double, scale: Double = 1, angle: Double = 0, foam: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -58, y: -52, width: 116, height: 52, rx: 12, fill: "#f4d35e")
    rect(x: -58, y: -70, width: 116, height: 20, rx: 6, fill: "#6aa36f")
    for cx in [-30.0, 0, 30] {
      circle(cx: cx, cy: -26, r: 5, fill: "#e2bb3c", strokeWidth: 2)
    }
    if foam > 0.01 {
      g(fill: "#fff", stroke: "#b9c6cc", strokeWidth: 2.5, opacity: foam) {
        for (i, cx) in [-46.0, -20, 8, 34, 52].enumerated() {
          circle(cx: cx, cy: 4 + Double(i % 2) * 8, r: 12 + Double(i % 3) * 3)
        }
      }
    }
  }
}

/// 歯ブラシ (横に寝かせた状態)。head = ブラシ部分。すき間の汚れ落とし用
public let TOOTHBRUSH_PARTS = Parts(["grip": Pt(40, -10), "head": Pt(-66, 0)])
public func ToothBrush(x: Double, y: Double, scale: Double = 1, angle: Double = 0, color: Paint = "#7fb6d6") {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -50, y: -20, width: 130, height: 16, rx: 8, fill: color)
    rect(x: -92, y: -22, width: 48, height: 18, rx: 6, fill: color)
    path("M -88 -4 V 10 M -78 -4 V 10 M -68 -4 V 10 M -58 -4 V 10 M -48 -4 V 10", stroke: "#f2f2ee", strokeWidth: 5)
    path("M -90 10 H -46", strokeWidth: 3)
  }
}

/// 取っ手付きの小さなブラシ (原点 = 毛先の中心)
public let BRUSH_PARTS = Parts(["grip": Pt(0, -72)])
public func Brush(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M -36 -42 Q -36 -82 0 -82 Q 36 -82 36 -42", fill: Paint.none, strokeWidth: 14)
    path("M -36 -42 Q -36 -82 0 -82 Q 36 -82 36 -42", fill: Paint.none, stroke: "#9b6b43", strokeWidth: 6)
    rect(x: -58, y: -44, width: 116, height: 22, rx: 8, fill: "#9b6b43")
    rect(x: -52, y: -22, width: 104, height: 22, rx: 4, fill: "#e7c56f")
    path("M -36 -18 v 14 M -18 -18 v 14 M 0 -18 v 14 M 18 -18 v 14 M 36 -18 v 14", stroke: "#b8963f", strokeWidth: 3)
  }
}

/// 中性洗剤のボトル。label: ラベルの文字
public let DETERGENT_PARTS = Parts(["grip": Pt(0, -80), "nozzle": Pt(0, -196)])
public func Detergent(x: Double, y: Double, scale: Double = 1, angle: Double = 0, label: String = "中性") {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M -14 -196 L -10 -176 H 10 L 14 -196 Z", fill: "#f7f5ef")
    rect(x: -24, y: -180, width: 48, height: 22, rx: 6, fill: "#f7f5ef")
    rect(x: -42, y: -160, width: 84, height: 160, rx: 22, fill: "#8cc7b0")
    rect(x: -30, y: -112, width: 60, height: 56, rx: 8, fill: "#ffffff", strokeWidth: 4)
    text(label, x: 0, y: -84, fontSize: 22, fontWeight: 900, fontFamily: "\"Hiragino Sans\", sans-serif", fill: "#3d5f6e", stroke: Paint.none,
         textAnchor: .middle, dominantBaseline: .central)
  }
}

/// スプレー容器
public func SprayBottle(x: Double, y: Double, scale: Double = 1, angle: Double = 0, color: Paint = "#e7a6c4") {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -26, y: -80, width: 52, height: 80, rx: 12, fill: color)
    rect(x: -14, y: -96, width: 28, height: 18, fill: "#fbfaf4", strokeWidth: 4)
    path("M -14 -112 H 26 L 30 -100 H -14 Z", fill: "#fbfaf4", strokeWidth: 4)
    path("M 4 -96 l 10 18", strokeWidth: 4)
  }
}

/// 雑巾 (たたんで置いた状態)。wet: 濡れ
public func Rag(x: Double, y: Double, scale: Double = 1, angle: Double = 0, wet: Double = 0, color: Paint = "#eef0f2") {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -60, y: -34, width: 120, height: 34, rx: 8, fill: color)
    path("M -50 -26 L 50 -8 M -50 -8 L 50 -26", stroke: "#8aa0b4", strokeWidth: 2.5, strokeDasharray: [6, 6])
    rect(x: -60, y: -34, width: 120, height: 34, rx: 8, fill: "#6fb6d6", stroke: Paint.none, opacity: 0.3 * wet)
  }
}

/// 手に持った布 (雑巾・タオル、原点 = 中心)。twist: 絞る (0〜1)、wet: 濡れ
public func Cloth(x: Double, y: Double, scale: Double = 1, angle: Double = 0, color: Paint = "#eef0f2", twist: Double = 0, wet: Double = 0) {
  let w = 130 - 30 * twist
  let pinch = 26 * twist
  let shape = "M \(-w / 2) -36 Q 0 \(-36 + pinch) \(w / 2) -36 L \(w / 2) 36 Q 0 \(36 - pinch) \(-w / 2) 36 Z"
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path(shape, fill: color)
    if twist > 0.05 {
      for k in [-0.3, 0, 0.3] {
        path("M \(k * w - 14) \(-30 + pinch) L \(k * w + 14) \(30 - pinch)", strokeWidth: 3)
      }
    } else {
      path("M -46 -20 L 46 20 M -46 20 L 46 -20", stroke: "#8aa0b4", strokeWidth: 2.5, strokeDasharray: [6, 6])
    }
    path(shape, fill: "#6fb6d6", stroke: Paint.none, opacity: 0.3 * wet)
  }
}

/// 乾いたタオル (たたんで置いた状態)
public let TOWEL_COLOR: Paint = "#e6b8a2"
public func Towel(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -62, y: -46, width: 124, height: 46, rx: 10, fill: TOWEL_COLOR)
    path("M -62 -16 H 62", stroke: "#c98f76", strokeWidth: 4)
    path("M -62 -46 H 62", strokeWidth: 6)
  }
}

/// 新聞紙 (たたんだ束)
public func NewsBundle(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -62, y: -30, width: 124, height: 30, rx: 4, fill: "#f1eee4")
    path("M -50 -20 H 10 M -50 -10 H 40 M 20 -20 H 50", stroke: "#a7a294", strokeWidth: 3)
  }
}

/// 天板に敷いた新聞紙 (原点 = 天板の高さの中心)。spread: 広げる (0〜1、左から)、stain: 油じみ
public func NewsSheet(x: Double, y: Double, w: Double, spread: Double = 1, stain: Double = 0) {
  let palette = useGuide().palette
  if spread <= 0.01 { return }
  let ww = w * spread
  let x0 = x - w / 2
  g(stroke: palette.ink, strokeWidth: 4, strokeLinejoin: .round) {
    path("M \(x0 + 14) \(y - 10) L \(x0 + ww - 14) \(y - 10) L \(x0 + ww) \(y + 46) L \(x0) \(y + 46) Z", fill: "#f1eee4")
    g(stroke: "#a7a294", strokeWidth: 3) {
      for (i, dy) in [6.0, 18, 30].enumerated() {
        path("M \(x0 + 24) \(y + dy) H \(x0 + max(30, ww * (i == 1 ? 0.55 : 0.85)))")
      }
      if ww > w * 0.7 { path("M \(x0 + ww * 0.62) \(y + 18) H \(x0 + ww - 24)") }
    }
    if stain > 0.01 { ellipse(cx: x, cy: y + 14, rx: 70, ry: 10, fill: OIL, stroke: Paint.none, opacity: 0.35 * stain) }
  }
}

/// ゴミ袋 (幅 130 × 高さ 150)。full: 中身 (0〜1)
public let TRASHBAG_PARTS = Parts(["grip": Pt(-46, -150), "mouth": Pt(0, -146)])
public func TrashBag(x: Double, y: Double, scale: Double = 1, angle: Double = 0, full: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M -54 -140 Q -76 -60 -50 0 H 50 Q 76 -60 54 -140 Z", fill: "#e7eaee")
    if full > 0.01 {
      path("M -52 -\(10 + 60 * full) Q 0 -\(30 + 60 * full) 52 -\(10 + 60 * full) L 50 0 H -50 Z", fill: "#cfc4a6", stroke: Paint.none, opacity: 0.8)
    }
    path("M -54 -140 Q -76 -60 -50 0 H 50 Q 76 -60 54 -140", fill: Paint.none)
    ellipse(cx: 0, cy: -146, rx: 56, ry: 12, fill: "#9aa2a8")
    path("M -30 -90 Q -36 -50 -28 -20", fill: Paint.none, stroke: "#fff", strokeWidth: 6, opacity: 0.8)
  }
}

/// ボトル型のウェットシート
public func WipePack(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -80, y: -70, width: 160, height: 70, rx: 20, fill: "#cfe6e0")
    rect(x: -40, y: -86, width: 80, height: 22, rx: 10, fill: "#5aa38f")
    path("M -10 -86 q 10 -24 22 -6", fill: "#fbfaf4", strokeWidth: 4)
    circle(cx: -40, cy: -34, r: 14, fill: "#fbfaf4", strokeWidth: 3)
    path("M -46 -34 l 4 -10 l 4 10 M -40 -30 v 0", fill: Paint.none, strokeWidth: 3)
    path("M -14 -40 H 50 M -14 -24 H 34", stroke: "#5aa38f", strokeWidth: 5)
  }
}

/// 手に持ったウェットシート 1 枚 (原点 = 中心)。dirty: 汚れ
public func WipeSheet(x: Double, y: Double, scale: Double = 1, angle: Double = 0, dirty: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M -42 -36 Q 0 -44 42 -36 L 38 36 Q 0 44 -38 36 Z", fill: "#fbfaf4", strokeWidth: 4)
    for ly in [-20.0, 0, 20] {
      path("M -26 \(ly) H 26", stroke: "#cfe0ea", strokeWidth: 3, strokeDasharray: [4, 8])
    }
    if dirty > 0.01 { ellipse(cx: 0, cy: 18, rx: 22, ry: 10, fill: STAIN, stroke: Paint.none, opacity: 0.5 * dirty) }
  }
}

/// 掃除機のノズル (原点 = 吸い込み口の中心、柄は右上へ)。on: 吸い込み中
public let NOZZLE_PARTS = Parts(["grip": Pt(210, -250)])
public func VacuumNozzle(x: Double, y: Double, scale: Double = 1, angle: Double = 0, on: Bool = false) {
  let frame = useCurrentFrame()
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M 40 -30 L 230 -270", strokeWidth: 34)
    path("M 40 -30 L 230 -270", stroke: "#c9ced0", strokeWidth: 22)
    rect(x: -90, y: -30, width: 180, height: 34, rx: 12, fill: "#5b6a70")
    rect(x: -80, y: 2, width: 160, height: 8, rx: 4, fill: "#353b35")
    if on { path("M -60 \(30 + jsMod(frame, 8)) q 60 -20 120 0", fill: Paint.none, stroke: "#8ab8c8", strokeWidth: 4, opacity: 0.8) }
  }
}

// ---------- 台所 ----------

/// 2 口コンロ (幅 460)。pot: 左の口に鍋をのせる、flame: 火 (0〜1)
public func Cooktop(x: Double, y: Double, scale: Double = 1, angle: Double = 0, pot: Bool = false, flame: Double = 0) {
  let frame = useCurrentFrame()
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -230, y: -26, width: 460, height: 26, rx: 8, fill: "#454c4e")
    for cx in [-110.0, 110] {
      ellipse(cx: cx, cy: -30, rx: 70, ry: 10, fill: "#2e3335", strokeWidth: 4)
    }
    rect(x: 160, y: -16, width: 44, height: 10, rx: 4, fill: "#9aa3a5", strokeWidth: 3)
    if pot {
      if flame > 0 {
        g(stroke: Paint.none, opacity: flame) {
          for (i, fx) in [-30.0, 0, 30].enumerated() {
            path("M \(-110 + fx - 8) -34 Q \(-110 + fx) \(-58 - sin(frame * 0.5 + Double(i)) * 6) \(-110 + fx + 8) -34 Z", fill: "#6aa7e0")
          }
        }
      }
      path("M -200 -150 L -190 -40 Q -188 -32 -178 -32 L -42 -32 Q -32 -32 -30 -40 L -20 -150 Z", fill: "#8f9ea3")
      path("M -214 -150 H -6", strokeWidth: 8)
      path("M -236 -132 H -200 M -20 -132 H 16", strokeWidth: 12)
    }
  }
}

// ---------- 事務・PC ----------

/// ノート PC の画面 (Laptop のローカル座標、幅 428 × 高さ 250 の左上)
public let LAPTOP_SCREEN = Box(x: -214, y: -318, w: 428, h: 250)
/// ノート PC のパーツ (screen は画面の左上。画面の大きさは LAPTOP_SCREEN)
public let LAPTOP_PARTS = Parts(["keysL": Pt(-80, -16), "keysR": Pt(80, -16), "screen": Pt(LAPTOP_SCREEN.x, LAPTOP_SCREEN.y)])

/// ノート PC (幅 568)。content は画面の中 (幅 428 × 高さ 250、左上が原点) に描く。
/// 画面の UI を大きく見せたいときは PhoneFrame / BrowserFrame を拡大カードで使う
public func Laptop(x: Double, y: Double, scale: Double = 1, angle: Double = 0, on: Double = 1, _ content: () -> Void = {}) {
  let sc = LAPTOP_SCREEN
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -232, y: -334, width: 464, height: 296, rx: 16, fill: "#3a403d")
    rect(x: sc.x, y: sc.y, width: sc.w, height: sc.h, rx: 6, fill: "#1f2422", strokeWidth: 3)
    g(stroke: Paint.none, opacity: on, transform: [.translate(sc.x, sc.y)]) {
      content()
    }
    path("M -284 0 L -246 -38 L 246 -38 L 284 0 Z", fill: "#cfd4d1")
    path("M -200 -26 H 200 M -210 -14 H 210", stroke: "#a9afab", strokeWidth: 4)
  }
}

/// 封筒 (メール・通知の記号にも)。open: ふたを開く (0〜1)
public func Envelope(x: Double, y: Double, scale: Double = 1, angle: Double = 0, open: Double = 0) {
  let palette = useGuide().palette
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -80, y: -110, width: 160, height: 110, rx: 10, fill: "#fff")
    path("M -80 -110 L 0 \(-50 - open * 100) L 80 -110", fill: palette.apron)
    path("M -80 0 L -20 -55 M 80 0 L 20 -55", strokeWidth: 4)
    circle(cx: 0, cy: -52, r: 12, fill: palette.accent, strokeWidth: 3)
  }
}

// ---------- 効果 ----------

/// 落ちる水滴・汚れ (x を中心に幅 w の範囲に count 個、周期的に落下)
public func Drips(x: Double, y: Double, w: Double, fall: Double = 160, color: Paint = "#6fb6d6", count: Int = 8, seed: String = "d") {
  let t = useSec()
  g {
    for i in 0 ..< count {
      let k = jsMod(t * 1.2 + random("\(seed)\(i)"), 1)
      let dx = x - w / 2 + random("\(seed)x\(i)") * w
      ellipse(cx: dx, cy: y + k * fall, rx: 6, ry: 10, fill: color, opacity: 1 - k)
    }
  }
}

/// きらめき (中心 x, y・幅 w × 高さ h の範囲に count 個が明滅)。きれいになった所に
public func Sparkles(x: Double, y: Double, w: Double, h: Double, on: Double = 1, count: Int = 6, seed: String = "sp") {
  let t = useSec()
  if on < 0.01 { return }
  g(opacity: on) {
    for i in 0 ..< count {
      let k = jsMod(t * 0.9 + random("\(seed)\(i)"), 1)
      let s = sin(k * Double.pi) * (14 + random("\(seed)s\(i)") * 12)
      let cx = x - w / 2 + random("\(seed)x\(i)") * w
      let cy = y - h / 2 + random("\(seed)y\(i)") * h
      path("M \(cx) \(cy - s) Q \(cx) \(cy) \(cx + s) \(cy) Q \(cx) \(cy) \(cx) \(cy + s) Q \(cx) \(cy) \(cx - s) \(cy) Q \(cx) \(cy) \(cx) \(cy - s) Z",
           fill: "#ffe08a", stroke: "#e0a84a", strokeWidth: 2)
    }
  }
}

/// 小さなハートが立ちのぼる (うれしい・落ち着いている)
public func Hearts(x: Double, y: Double, on: Double = 1) {
  let t = useSec()
  let palette = useGuide().palette
  if on < 0.01 { return }
  g(opacity: on) {
    for i in 0 ..< 3 {
      let i = Double(i)
      let k = jsMod(t * 0.6 + i / 3, 1)
      let hx = x + sin(k * 6 + i) * 16 + (i - 1) * 30
      let hy = y - k * 90
      let s = 0.8 + i * 0.15
      path("M 0 10 C -18 -2 -16 -16 -6 -16 C -2 -16 0 -12 0 -10 C 0 -12 2 -16 6 -16 C 16 -16 18 -2 0 10 Z",
           fill: "#e8828c", stroke: palette.ink, strokeWidth: 2.5, opacity: sin(k * Double.pi), transform: [.translate(hx, hy), .scale(s)])
    }
  }
}

// ---------- 一覧 (jgv catalog) ----------

/// 家事の道具の一覧 (KIT_CATALOG に並べる)
public let CATALOG_HOUSEHOLD: [PreviewItem] = [
  PreviewItem(name: "Outlet / Plug", scale: 1) { x, y, _ in
    Outlet(x: x - 60, y: y - 120)
    Plug(x: x + 40, y: y - 110, cordFrom: Pt(x + 120, y - 50))
  },
  PreviewItem(name: "PowerPlug", note: "out", scale: 1) { x, y, _ in PowerPlug(outlet: Pt(x - 10, y - 150), cordFrom: Pt(x + 110, y - 50), out: 0.6) },
  PreviewItem(name: "Breaker", note: "off", scale: 1, dy: -90, parts: BREAKER_PARTS) { x, y, s in Breaker(x: x, y: y, scale: s, off: 0) },
  PreviewItem(name: "Remote", note: "press", scale: 1, dy: -80) { x, y, s in Remote(x: x, y: y, scale: s, press: 0.5) },
  PreviewItem(name: "Faucet", note: "side height", scale: 0.6, dx: -80, dy: -60) { x, y, s in Faucet(x: x, y: y, scale: s, side: .right) },
  PreviewItem(name: "Sink", note: "w h", scale: 0.28, dy: -140) { x, y, s in Sink(x: x, y: y, scale: s) },
  PreviewItem(name: "Basin", note: "suds steam", scale: 1, parts: BASIN_PARTS) { x, y, s in Basin(x: x, y: y, scale: s, suds: 1, steam: true) },
  PreviewItem(name: "Glove", scale: 1) { x, y, s in Glove(x: x, y: y, scale: s) },
  PreviewItem(name: "GloveHand", note: "on", scale: 1, dy: -80) { x, y, _ in GloveHand(x: x, y: y, r: 36) },
  PreviewItem(name: "Sponge", note: "foam", scale: 1.2, dy: -20, parts: SPONGE_PARTS) { x, y, s in Sponge(x: x, y: y, scale: s, foam: 1) },
  PreviewItem(name: "ToothBrush", note: "color", scale: 1.2, dy: -40, parts: TOOTHBRUSH_PARTS) { x, y, s in ToothBrush(x: x, y: y, scale: s) },
  PreviewItem(name: "Brush", scale: 1.2, parts: BRUSH_PARTS) { x, y, s in Brush(x: x, y: y, scale: s) },
  PreviewItem(name: "Detergent", note: "label", scale: 0.9, parts: DETERGENT_PARTS) { x, y, s in Detergent(x: x, y: y, scale: s) },
  PreviewItem(name: "SprayBottle", note: "color", scale: 1.3) { x, y, s in SprayBottle(x: x, y: y, scale: s) },
  PreviewItem(name: "Rag", note: "wet", scale: 1.3, dy: -20) { x, y, s in Rag(x: x, y: y, scale: s, wet: 0.5) },
  PreviewItem(name: "Cloth", note: "twist wet", scale: 1.2, dy: -80) { x, y, s in Cloth(x: x, y: y, scale: s, twist: 0.6) },
  PreviewItem(name: "Towel", scale: 1.3, dy: -20) { x, y, s in Towel(x: x, y: y, scale: s) },
  PreviewItem(name: "NewsBundle / NewsSheet", scale: 1) { x, y, _ in
    NewsBundle(x: x, y: y - 110)
    NewsSheet(x: x, y: y - 40, w: 240, stain: 1)
  },
  PreviewItem(name: "TrashBag", note: "full", scale: 1, parts: TRASHBAG_PARTS) { x, y, s in TrashBag(x: x, y: y, scale: s, full: 0.6) },
  PreviewItem(name: "WipePack / WipeSheet", scale: 1) { x, y, _ in
    WipePack(x: x - 50, y: y)
    WipeSheet(x: x + 90, y: y - 120, dirty: 1)
  },
  PreviewItem(name: "VacuumNozzle", note: "on", scale: 0.65, dx: -50, dy: -20, parts: NOZZLE_PARTS) { x, y, s in VacuumNozzle(x: x, y: y, scale: s, on: true) },
  PreviewItem(name: "Cooktop", note: "pot flame", scale: 0.6) { x, y, s in Cooktop(x: x, y: y, scale: s, pot: true, flame: 1) },
  PreviewItem(name: "Laptop", note: "children", scale: 0.5, parts: LAPTOP_PARTS) { x, y, s in
    Laptop(x: x, y: y, scale: s) {
      rect(x: 24, y: 24, width: 380, height: 40, rx: 8, fill: "#5b8c74")
      rect(x: 24, y: 84, width: 240, height: 24, rx: 6, fill: "#e9eef0")
      rect(x: 24, y: 124, width: 300, height: 24, rx: 6, fill: "#e9eef0")
    }
  },
  PreviewItem(name: "Envelope", note: "open", scale: 1, dy: -20) { x, y, s in Envelope(x: x, y: y, scale: s, open: 1) },
  PreviewItem(name: "Drips / Sparkles / Hearts", scale: 1) { x, y, _ in
    Drips(x: x - 70, y: y - 200, w: 80)
    Sparkles(x: x + 60, y: y - 150, w: 120, h: 120)
    Hearts(x: x, y: y - 20)
  },
]
