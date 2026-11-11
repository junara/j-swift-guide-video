// 台所の道具 (横から見た図: 原点 = 底の中心) と、手元俯瞰型の台所の道具 (真上から: 原点 = 中心)。
// 横から見た道具は Props.swift と同じく x y scale angle を受け取り、持ち手などは *_PARTS を place() で画面座標にする。
// 取っ手が片側にある道具 (フライパン・包丁・おたま・計量スプーン・計量カップ) は既定で取っ手が右。
// flip で左右反転でき、そのときのパーツ位置は place(x, y, s, angle, flipPart(XXX_PARTS.grip)) で求める。
import Foundation

// 色 (金属・木・食材)
private let METAL: Paint = "#a3b1b4"
private let METAL_LIGHT: Paint = "#c9d3d5"
private let STEEL: Paint = "#d5dcde"
private let IRON: Paint = "#3f4648"
private let IRON_IN: Paint = "#596164"
private let WOOD: Paint = "#6e4a33"
private let BOARD: Paint = "#e5c793"
private let BOARD_TOP: Paint = "#f0dbb0"

// ---------- 鍋 ----------
// 両手鍋。lidOpen: ふたを右上へ持ち上げる (0〜1)、lid: false でふたなし、fill: 中身の量 (ふたが開くと見える)、steam: 湯気 (0〜1)
public let POT_PARTS = Parts(["handleL": Pt(-158, -128), "handleR": Pt(158, -128), "rim": Pt(0, -160), "lid": Pt(0, -212)])
/// ふたを開けたときのつまみの位置 (ローカル座標)。ふたを持つ手は place(x, y, s, angle, potLidKnob(lidOpen))
public func potLidKnob(_ lidOpen: Double) -> Pt {
  let o = clamp01(lidOpen)
  let a = (o * 25 * Double.pi) / 180
  return Pt(o * 150 + 52 * sin(a), -o * 110 - 160 - 52 * cos(a))
}
public func Pot(x: Double, y: Double, scale: Double = 1, angle: Double = 0, lidOpen: Double = 0, lid: Bool = true, fill: Double = 0.7,
                soup: Paint = "#d9a75f", steam: Double = 0, color: Paint = "#a3b1b4" /* METAL */) {
  let o = lid ? clamp01(lidOpen) : 1
  let f = clamp01(fill)
  Placed(x: x, y: y, scale: scale, angle: angle) {
    if steam > 0 {
      g(opacity: clamp01(steam)) {
        Steam(x: 0, y: -176 - (1 - o) * 30, count: 3, height: 150)
      }
    }
    // 取っ手 (左右)
    path("M -126 -128 H -166 M 126 -128 H 166", strokeWidth: 24)
    path("M -126 -128 H -166 M 126 -128 H 166", stroke: "#6f7b7e", strokeWidth: 12)
    path("M -130 -160 L -124 -14 Q -122 0 -106 0 L 106 0 Q 122 0 124 -14 L 130 -160 Z", fill: color)
    path("M -98 -128 V -42", stroke: METAL_LIGHT, strokeWidth: 10)
    // 口と中身
    ellipse(cx: 0, cy: -160, rx: 130, ry: 20, fill: "#5d686b")
    if f > 0.02 && o > 0.05 { ellipse(cx: 0, cy: -158 + 8 * (1 - f), rx: 118 - 24 * (1 - f), ry: 13, fill: soup, strokeWidth: 3) }
    // ふた
    if lid {
      g(transform: [.translate(o * 150, -o * 110), .rotate(o * 25, 0, -160)]) {
        path("M -140 -160 Q -134 -196 0 -198 Q 134 -196 140 -160 A 140 20 0 0 1 -140 -160 Z", fill: "#b8c4c7")
        path("M -80 -184 Q 0 -192 60 -188", fill: Paint.none, stroke: METAL_LIGHT, strokeWidth: 6)
        rect(x: -24, y: -218, width: 48, height: 20, rx: 8, fill: "#3d3a32")
      }
    }
  }
}

// ---------- フライパン ----------
// food: 中身 (.egg 目玉焼き / .veg 野菜炒め / .pancake)、toss: 中身をあおって浮かせる (0〜1)、sizzle: 油はね (0〜1)
// content は鍋肌の上 (ローカル座標、PAN_PARTS.center が中心) に描く

/// フライパンの中身
public enum PanFood { case none, egg, veg, pancake }

public let PAN_PARTS = Parts(["grip": Pt(268, -68), "center": Pt(0, -52), "rim": Pt(-140, -52)])
public func FryingPan(x: Double, y: Double, scale: Double = 1, angle: Double = 0, food: PanFood = .none, toss: Double = 0, sizzle: Double = 0,
                      flip: Bool = false, _ content: () -> Void = {}) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let t = frame / fps
  let up = sin(clamp01(toss) * Double.pi) * 60
  let veg: [Paint] = ["#e58a3a", "#7aa851", "#efe3c2", "#e58a3a", "#7aa851", "#efe3c2", "#c8544a"]
  Placed(x: x, y: y, scale: scale, angle: angle) {
    Flip(on: flip) {
      // 柄
      path("M 132 -48 L 210 -60", strokeWidth: 20)
      path("M 132 -48 L 210 -60", stroke: "#8a9396", strokeWidth: 8)
      path("M 206 -60 L 330 -77", strokeWidth: 32)
      path("M 206 -60 L 330 -77", stroke: WOOD, strokeWidth: 20)
      path("M -140 -52 L -122 -10 Q -116 0 -100 0 L 100 0 Q 116 0 122 -10 L 140 -52 Z", fill: IRON)
      ellipse(cx: 0, cy: -52, rx: 140, ry: 16, fill: IRON_IN)
      if food == .egg {
        g(strokeWidth: 4) {
          ellipse(cx: -10, cy: -56, rx: 74, ry: 11, fill: "#fbfaf5")
          path("M -32 -58 Q -10 -88 12 -58 Z", fill: "#f2b53a")
        }
      }
      if food == .pancake {
        g(strokeWidth: 4, transform: [.translate(0, -up)]) {
          path("M -96 -56 Q -96 -72 0 -74 Q 96 -72 96 -56 Q 96 -48 0 -48 Q -96 -48 -96 -56 Z", fill: "#e2b56c")
          path("M -60 -66 Q 0 -70 50 -67", fill: Paint.none, stroke: "#f3d79c", strokeWidth: 5)
        }
      }
      if food == .veg {
        for (i, c) in veg.enumerated() {
          let vx = -95 + Double(i) * 32
          let vy = -64 - Double(i % 3) * 7 - up * (0.6 + random("pan-v\(i)") * 0.6)
          rect(x: vx - 14, y: vy - 8, width: 28, height: 16, rx: 7, fill: c, strokeWidth: 4,
               transform: [.rotate((random("pan-r\(i)") - 0.5) * 70 + up, vx, vy)])
        }
      }
      // 油はね
      if sizzle > 0 {
        for i in 0 ..< 8 {
          let k = jsMod(t * 1.7 + random("pan-s\(i)"), 1)
          let sx = (random("pan-sx\(i)") - 0.5) * 220
          circle(cx: sx + (sx > 0 ? 1 : -1) * k * 24, cy: -62 - sin(k * Double.pi) * 60, r: 5, fill: "#f4e3a8", strokeWidth: 2.5,
                 opacity: clamp01(sizzle) * (1 - k * 0.6))
        }
      }
    }
    // content は flip しても左右反転しない (鍋肌の中心が原点なので位置はそのまま)
    content()
  }
}

// ---------- 包丁 ----------
// 原点 = 刃 (下辺) の中ほど。柄が右・刃先が左 (flip で反転)。spine (峰) は上から押さえる手の位置
public let KNIFE_PARTS = Parts(["grip": Pt(124, -28), "edge": Pt(-30, 0), "tip": Pt(-152, -14), "spine": Pt(-40, -48)])
public func Knife(x: Double, y: Double, scale: Double = 1, angle: Double = 0, flip: Bool = false) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    Flip(on: flip) {
      rect(x: 74, y: -42, width: 102, height: 28, rx: 12, fill: "#4a3426")
      circle(cx: 150, cy: -28, r: 5, fill: METAL_LIGHT, strokeWidth: 2)
      circle(cx: 104, cy: -28, r: 5, fill: METAL_LIGHT, strokeWidth: 2)
      path("M 66 0 L -90 0 Q -130 -2 -152 -14 Q -140 -42 -100 -48 L 66 -48 Z", fill: STEEL)
      path("M 56 -10 L -96 -10", stroke: "#eef2f3", strokeWidth: 6)
      rect(x: 62, y: -46, width: 18, height: 36, rx: 5, fill: "#8a9396")
    }
  }
}

// ---------- まな板 ----------
// 上に置く物の底は CUTTING_BOARD_PARTS.top (板の表面)。pieces: 切った輪切りを右側に並べる (個数)、food: その色
public let CUTTING_BOARD_PARTS = Parts(["top": Pt(0, -34)])
public func CuttingBoard(x: Double, y: Double, scale: Double = 1, angle: Double = 0, pieces: Double = 0, food: Paint = "#e58a3a") {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M -192 -42 L 192 -42 L 200 -26 L -200 -26 Z", fill: BOARD_TOP)
    rect(x: -200, y: -26, width: 400, height: 26, rx: 6, fill: BOARD)
    path("M -170 -13 H 120", stroke: "#f3e2bf", strokeWidth: 5)
    // 並べられるのは 1 段 6 個で数段まで。有限でない値・大きすぎる値で固まらない・落ちないよう上限を付ける
    let n = pieces.isFinite ? Int(min(60, max(0, floor(pieces)))) : 0
    for i in 0 ..< n {
      ellipse(cx: 40 + Double(i % 6) * 26, cy: -40 - Double(i / 6) * 9, rx: 15, ry: 6, fill: food, strokeWidth: 4)
    }
  }
}

// ---------- ボウル (横から) ----------
// fill: 中身の量 (0〜1)、food: 中身の色。両手で持つ位置は gripL / gripR
public let BOWL_PARTS = Parts(["rim": Pt(0, -110), "gripL": Pt(-122, -74), "gripR": Pt(122, -74)])
public func Bowl(x: Double, y: Double, scale: Double = 1, angle: Double = 0, fill: Double = 0, food: Paint = "#f2d38a", color: Paint = "#f3ede1") {
  let palette = useGuide().palette
  let f = clamp01(fill)
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -52, y: -12, width: 104, height: 12, rx: 4, fill: color)
    path("M -130 -110 C -130 -44 -84 -10 -50 -10 L 50 -10 C 84 -10 130 -44 130 -110 Z", fill: color)
    path("M -118 -70 Q 0 -54 118 -70", fill: Paint.none, stroke: palette.primary, strokeWidth: 8, opacity: 0.55)
    ellipse(cx: 0, cy: -110, rx: 130, ry: 20, fill: "#e6dccb")
    if f > 0.02 { ellipse(cx: 0, cy: -108 + 8 * (1 - f), rx: 116 - 34 * (1 - f), ry: 13 - 3 * (1 - f), fill: food, strokeWidth: 3) }
    ellipse(cx: 0, cy: -110, rx: 130, ry: 20, fill: Paint.none)
  }
}

// ---------- 計量カップ ----------
// 透明なカップ。fill: 中身の量 (0〜1、目盛り 4 本)、liquid: 中身の色
public let MEASURING_CUP_PARTS = Parts(["handle": Pt(112, -102), "spout": Pt(-88, -176), "rim": Pt(0, -170)])
public func MeasuringCup(x: Double, y: Double, scale: Double = 1, angle: Double = 0, fill: Double = 0, liquid: Paint = "#9ccbe0", flip: Bool = false) {
  let f = clamp01(fill)
  // 側面の x (y は -8〜-170)
  let side = { (y: Double) -> Double in 58 + ((-8 - y) / 162) * 8 }
  let ly = -10 - 150 * f
  Placed(x: x, y: y, scale: scale, angle: angle) {
    Flip(on: flip) {
      path("M 64 -146 C 130 -150 130 -50 60 -54", fill: Paint.none, strokeWidth: 26)
      path("M 64 -146 C 130 -150 130 -50 60 -54", fill: Paint.none, stroke: "#e8f2f4", strokeWidth: 14)
      path("M -66 -170 L -58 -8 Q -56 0 -46 0 L 46 0 Q 56 0 58 -8 L 66 -170 Z", fill: "#e8f2f4")
      if f > 0.02 {
        path("M \(-side(ly)) \(ly) L \(side(ly)) \(ly) L 58 -8 Q 56 0 46 0 L -46 0 Q -56 0 -58 -8 Z", fill: liquid, strokeWidth: 3, opacity: 0.85)
      }
      for k in [0.25, 0.5, 0.75, 1] {
        path("M \(k == 0.5 || k == 1 ? 14 : 28) \(-10 - 150 * k) H 50", strokeWidth: 4)
      }
      path("M -40 -150 V -40", stroke: "#ffffff", strokeWidth: 8, opacity: 0.8)
      path("M -66 -170 L -88 -178 L -64 -150", fill: "#e8f2f4")
      path("M -66 -170 L -58 -8 Q -56 0 -46 0 L 46 0 Q 56 0 58 -8 L 66 -170 Z", fill: Paint.none)
    }
  }
}

// ---------- 計量スプーン ----------
// 原点 = さじの底。amount: すくった粉 (0〜1、1 で山盛り)、color: 粉の色。傾けて落とすときの口は lip
public let MEASURING_SPOON_PARTS = Parts(["grip": Pt(150, -48), "bowl": Pt(0, -38), "lip": Pt(-42, -38)])
public func MeasuringSpoon(x: Double, y: Double, scale: Double = 1, angle: Double = 0, amount: Double = 0, color: Paint = "#f7f2e6", flip: Bool = false) {
  let a = clamp01(amount)
  Placed(x: x, y: y, scale: scale, angle: angle) {
    Flip(on: flip) {
      path("M 38 -40 L 180 -50", strokeWidth: 18)
      path("M 38 -40 L 180 -50", stroke: METAL_LIGHT, strokeWidth: 8)
      path("M -42 -38 Q -40 0 0 0 Q 40 0 42 -38 Z", fill: METAL_LIGHT)
      ellipse(cx: 0, cy: -38, rx: 42, ry: 9, fill: "#e3e8ea", strokeWidth: 4)
      if a > 0.02 { path("M -38 -38 Q 0 \(-40 - 34 * a) 38 -38 Z", fill: color, strokeWidth: 4) }
    }
  }
}

// ---------- おたま ----------
// 原点 = 器の底。fill: すくった汁 (0〜1)、soup: その色。注ぐときは左へ傾けて lip から流す
public let LADLE_PARTS = Parts(["grip": Pt(104, -246), "bowl": Pt(0, -50), "lip": Pt(-55, -50)])
public func Ladle(x: Double, y: Double, scale: Double = 1, angle: Double = 0, fill: Double = 0, soup: Paint = "#d9a75f", flip: Bool = false) {
  let f = clamp01(fill)
  Placed(x: x, y: y, scale: scale, angle: angle) {
    Flip(on: flip) {
      path("M 46 -54 Q 92 -120 108 -296 Q 110 -320 92 -324", fill: Paint.none, strokeWidth: 18)
      path("M 46 -54 Q 92 -120 108 -296 Q 110 -320 92 -324", fill: Paint.none, stroke: METAL, strokeWidth: 8)
      path("M -55 -50 Q -52 0 0 0 Q 52 0 55 -50 Z", fill: METAL)
      ellipse(cx: 0, cy: -50, rx: 55, ry: 11, fill: "#5d686b", strokeWidth: 4)
      if f > 0.02 { ellipse(cx: 0, cy: -49, rx: 48 * (0.6 + 0.4 * f), ry: 8, fill: soup, strokeWidth: 3) }
      path("M -34 -36 Q -30 -16 -10 -10", fill: Paint.none, stroke: METAL_LIGHT, strokeWidth: 6)
    }
  }
}

// ---------- 菜箸 ----------
// 原点 = 箸先。open: 箸先を開く (0〜1)
public let SAIBASHI_PARTS = Parts(["grip": Pt(62, -262), "tip": Pt(0, 0)])
public func Saibashi(x: Double, y: Double, scale: Double = 1, angle: Double = 0, open: Double = 0, color: Paint = "#d9b77c") {
  let o = clamp01(open)
  let sticks = ["M 0 0 L 70 -340", "M \(12 + o * 44) 2 L 86 -336"]
  Placed(x: x, y: y, scale: scale, angle: angle) {
    for d in sticks {
      g {
        path(d, strokeWidth: 16)
        path(d, stroke: color, strokeWidth: 7)
      }
    }
  }
}

// ---------- 電子レンジ ----------
// 扉は手前に倒れて開く (open 0〜1)。on: 庫内の明かり (0〜1)、display: 表示窓の文字 ("1:30" "600W" など)
// content は庫内 (ローカル座標、MICROWAVE_PARTS.inside が庫内の床の中心) に描く。扉を閉めてもガラス窓越しに見える
public let MICROWAVE_PARTS = Parts(["handle": Pt(0, -210), "inside": Pt(0, -26), "button": Pt(62, -251)])
private let MW_HINGE = -14.0
private let MW_DOOR_H = 210.0
/// 扉を開けたときの取っ手の位置 (ローカル座標)。手は place(x, y, s, angle, microwaveHandle(open))
public func microwaveHandle(_ open: Double) -> Pt { Pt(0, MW_HINGE - (MW_DOOR_H - 14) * cos((clamp01(open) * Double.pi) / 2)) }
public func Microwave(x: Double, y: Double, scale: Double = 1, angle: Double = 0, open: Double = 0, on: Double = 0, display: String = "",
                      _ content: () -> Void = {}) {
  let font = useGuide().font
  let c = cos((clamp01(open) * Double.pi) / 2)
  let dh = max(16, MW_DOOR_H * c) // 扉の見かけの高さ (開くほど低い)
  let top = MW_HINGE - dh
  let l = clamp01(on)
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -210, y: -280, width: 420, height: 280, rx: 20, fill: "#ece8df")
    // 操作部
    rect(x: 88, y: -266, width: 104, height: 30, rx: 6, fill: "#2f3a3d", strokeWidth: 4)
    text(display, x: 140, y: -244, fontSize: 20, fontWeight: 700, fontFamily: font, fill: "#9fe0b0", stroke: Paint.none, textAnchor: .middle)
    circle(cx: MICROWAVE_PARTS.button.x, cy: MICROWAVE_PARTS.button.y, r: 10, fill: "#d98a5c", strokeWidth: 4)
    path("M -180 -251 H -60", stroke: "#d8d2c5", strokeWidth: 6)
    // 庫内
    rect(x: -180, y: -222, width: 360, height: 200, rx: 10, fill: l > 0 ? "#f3e3a6" : "#d9d3c4", strokeWidth: 4)
    path("M -150 -40 H 150", stroke: "#c4bca9", strokeWidth: 4)
    content()
    // 扉
    if c > 0.25 {
      // 窓の部分をくり抜いた扉 (庫内の content が窓越しに見える)
      path("\(rectPath(-196, top, 392, dh, min(14, dh / 2))) \(rectPath(-166, top + 34 * c, 332, (MW_DOOR_H - 56) * c, 8))", fill: "#4a5254", fillRule: .evenodd)
    } else {
      rect(x: -196, y: top, width: 392, height: dh, rx: min(14, dh / 2), fill: "#4a5254")
    }
    if c > 0.25 {
      g {
        rect(x: -166, y: top + 34 * c, width: 332, height: (MW_DOOR_H - 56) * c, rx: 8, fill: "#2f3a3d", strokeWidth: 4, fillOpacity: 0.35 - 0.2 * l)
        if l > 0 { rect(x: -166, y: top + 34 * c, width: 332, height: (MW_DOOR_H - 56) * c, rx: 8, fill: "#f6dc8a", stroke: Paint.none, opacity: 0.45 * l) }
      }
    }
    path("M -120 \(top + 14 * c) H 120", strokeWidth: 16)
    path("M -120 \(top + 14 * c) H 120", stroke: "#c9d3d5", strokeWidth: 6)
  }
}

// ---------- 炊飯器 ----------
// open: ふたを開ける (0〜1、右奥のちょうつがいで回る)、display: 表示窓の文字、steam: 湯気 (0〜1)
public let RICE_COOKER_PARTS = Parts(["button": Pt(0, -154), "rim": Pt(0, -150), "lid": Pt(-110, -176)])
private let RC_HINGE = Pt(128, -150)
private let RC_OPEN_DEG = 65.0
/// ふたを開けたときの、ふたの手前の縁 (RICE_COOKER_PARTS.lid) の位置 (ローカル座標)。手は place(x, y, s, angle, riceCookerLid(open))
public func riceCookerLid(_ open: Double) -> Pt {
  let a = (clamp01(open) * RC_OPEN_DEG * Double.pi) / 180
  let dx = RICE_COOKER_PARTS.lid.x - RC_HINGE.x
  let dy = RICE_COOKER_PARTS.lid.y - RC_HINGE.y
  return Pt(RC_HINGE.x + dx * cos(a) - dy * sin(a), RC_HINGE.y + dx * sin(a) + dy * cos(a))
}
public func RiceCooker(x: Double, y: Double, scale: Double = 1, angle: Double = 0, open: Double = 0, display: String = "", steam: Double = 0) {
  let gd = useGuide()
  let font = gd.font
  let palette = gd.palette
  let o = clamp01(open)
  Placed(x: x, y: y, scale: scale, angle: angle) {
    if steam > 0 {
      g(opacity: clamp01(steam)) {
        Steam(x: o > 0.4 ? 0 : 60, y: o > 0.4 ? -190 : -214, count: o > 0.4 ? 3 : 2, height: 130)
      }
    }
    path("M -140 -150 L -132 -16 Q -130 0 -112 0 L 112 0 Q 130 0 132 -16 L 140 -150 Z", fill: "#f4f1ea")
    rect(x: -62, y: -116, width: 124, height: 62, rx: 12, fill: "#3a4447", strokeWidth: 4)
    text(display, x: 0, y: -91, fontSize: 22, fontWeight: 700, fontFamily: font, fill: "#9fe0b0", stroke: Paint.none, textAnchor: .middle)
    circle(cx: -22, cy: -68, r: 7, fill: palette.accent, strokeWidth: 3)
    circle(cx: 22, cy: -68, r: 7, fill: "#d8d2c5", strokeWidth: 3)
    // 内釜とご飯 (ふたを開けると見える)
    ellipse(cx: 0, cy: -150, rx: 132, ry: 18, fill: "#c9d3d5")
    ellipse(cx: 0, cy: -149, rx: 116, ry: 12, fill: "#fbfaf5", strokeWidth: 3)
    for (i, ex) in [-70.0, -30, 10, 50, 80].enumerated() {
      ellipse(cx: ex, cy: -149 + Double(i % 2) * 4, rx: 6, ry: 2.6, fill: Paint.none, stroke: "#e3ddcf", strokeWidth: 2)
    }
    // ふた
    g(transform: [.rotate(o * RC_OPEN_DEG, RC_HINGE.x, RC_HINGE.y)]) {
      path("M -146 -150 Q -140 -206 0 -210 Q 140 -206 146 -150 Z", fill: "#e5e0d4")
      circle(cx: 60, cy: -194, r: 8, fill: "#3d3a32", strokeWidth: 3)
      rect(x: -22, y: -162, width: 44, height: 14, rx: 5, fill: palette.accent, strokeWidth: 4)
    }
  }
}

// ---------- 冷蔵庫 ----------
// 高さ 600 (scale 1)。部屋型ではカウンターより背が高い床置きの家電なので、床 (y = counterY + counterH = 870) に立てて右端 (x 1500〜1700) に置く。
// open: 上の扉を開ける (0〜1、右側のちょうつがいで手前に開く)。content は庫内 (ローカル座標、棚の上面は FRIDGE_PARTS.shelf1〜3) に描く
public let FRIDGE_PARTS = Parts([
  "handle": Pt(-128, -420),
  "shelf1": Pt(-20, -290),
  "shelf2": Pt(-20, -390),
  "shelf3": Pt(-20, -490),
  "drawer": Pt(0, -150),
])
private let FR_HINGE = 152.0
private let FR_DOOR_W = 304.0
/// 扉を開けたときの取っ手の位置 (ローカル座標)
public func fridgeHandle(_ open: Double) -> Pt {
  Pt(FR_HINGE - (FR_HINGE - FRIDGE_PARTS.handle.x) * cos((clamp01(open) * 80 * Double.pi) / 180), FRIDGE_PARTS.handle.y)
}
public func Fridge(x: Double, y: Double, scale: Double = 1, angle: Double = 0, open: Double = 0, color: Paint = "#e9ece6", _ content: () -> Void = {}) {
  let c = cos((clamp01(open) * 80 * Double.pi) / 180)
  let dw = FR_DOOR_W * c
  let hx = fridgeHandle(open).x
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -160, y: -600, width: 320, height: 600, rx: 22, fill: color)
    // 下の引き出し
    rect(x: -152, y: -182, width: 304, height: 170, rx: 12, fill: color)
    path("M -60 -160 H 60", strokeWidth: 14)
    path("M -60 -160 H 60", stroke: "#9aa3a5", strokeWidth: 6)
    // 庫内 (扉の後ろ)
    rect(x: -152, y: -592, width: 304, height: 400, rx: 12, fill: "#f7f6ef")
    if open > 0.02 {
      g {
        rect(x: -152, y: -592, width: 304, height: 400, rx: 12, fill: "#fff6d6", stroke: Paint.none, opacity: 0.6)
        for sy in [-290.0, -390, -490] {
          path("M -148 \(sy) H 148", stroke: "#a9c4cc", strokeWidth: 6)
        }
        content()
      }
    }
    // 上の扉
    rect(x: FR_HINGE - dw, y: -592, width: dw, height: 400, rx: min(12, dw / 2), fill: color)
    if c > 0.3 { path("M \(FR_HINGE - dw + 30 * c) -560 V -240", stroke: "#ffffff", strokeWidth: 8, opacity: 0.7) }
    path("M \(hx) -470 V -370", strokeWidth: 16)
    path("M \(hx) -470 V -370", stroke: "#9aa3a5", strokeWidth: 6)
  }
}

// =====================================================================
// 手元俯瞰型 (layout: "guide-topdown") の台所の道具。真上から見た図、原点 = 中心。
// =====================================================================
// ---------- 手元俯瞰の台所の道具 ----------

/// 輪郭線 (ink, 太さ 6, 角・端は丸) を付けた g
private func Inked(_ palette: GuidePalette, _ content: () -> Void) {
  g(stroke: palette.ink, strokeWidth: 6, strokeLinecap: .round, strokeLinejoin: .round, content)
}

/// まな板 (真上から)。w × h、木目つき
public func TopCuttingBoard(x: Double, y: Double, w: Double = 560, h: Double = 360, color: Paint = "#ead2a2") {
  let palette = useGuide().palette
  g {
    rect(x: x - w / 2 + 10, y: y - h / 2 + 14, width: w, height: h, rx: 28, fill: "#6b4a25", opacity: 0.18)
    rect(x: x - w / 2, y: y - h / 2, width: w, height: h, rx: 28, fill: color, stroke: palette.ink, strokeWidth: 6, strokeLinecap: .round, strokeLinejoin: .round)
    for i in 0 ..< 6 {
      let gy = y - h / 2 + 30 + random("tcb-y\(i)") * (h - 60)
      let gx = x - w / 2 + 30 + random("tcb-x\(i)") * (w - 260)
      path("M \(gx) \(gy) q 100 \(-6 + random("tcb-q\(i)") * 12) 200 0", fill: Paint.none, stroke: "#d6b77f", strokeWidth: 4, strokeLinecap: .round)
    }
    circle(cx: x + w / 2 - 36, cy: y - h / 2 + 36, r: 12, fill: "#d8b98e", stroke: palette.ink, strokeWidth: 4)
  }
}

/// 包丁 (真上から)。angle = 0 で刃先が上・柄が下。原点 = 刃の中ほど (切る線の上に置く)。
/// lift: 包丁を持ち上げた度合い (0〜1、影が離れて少し大きく見える)。chop() と組み合わせて刻む
public let TOP_KNIFE_PARTS = Parts(["grip": Pt(0, 132), "tip": Pt(-14, -206), "spine": Pt(-22, -60)])
public func TopKnife(x: Double, y: Double, angle: Double = 0, scale: Double = 1, lift: Double = 0) {
  let palette = useGuide().palette
  let l = clamp01(lift)
  let blade = "M -22 40 L -22 -170 Q -22 -200 -14 -206 Q 20 -150 22 -60 L 22 40 Z"
  let body = {
    path(blade)
    rect(x: -18, y: 38, width: 36, height: 22, rx: 5)
    rect(x: -17, y: 58, width: 34, height: 150, rx: 15)
  }
  g(transform: [.translate(x, y), .rotate(angle), .scale(scale)]) {
    g(fill: "#6b4a25", opacity: 0.18 - 0.06 * l, transform: [.translate(8 + 18 * l, 10 + 24 * l)]) {
      body()
    }
    g(stroke: palette.ink, strokeWidth: 6, strokeLinecap: .round, strokeLinejoin: .round, transform: [.scale(1 + 0.05 * l)]) {
      path(blade, fill: STEEL)
      path("M 12 30 L 12 -70", stroke: "#eef2f3", strokeWidth: 5)
      rect(x: -18, y: 38, width: 36, height: 22, rx: 5, fill: "#8a9396", strokeWidth: 4)
      rect(x: -17, y: 58, width: 34, height: 150, rx: 15, fill: "#4a3426")
      circle(cx: 0, cy: 96, r: 5, fill: METAL_LIGHT, strokeWidth: 2)
      circle(cx: 0, cy: 170, r: 5, fill: METAL_LIGHT, strokeWidth: 2)
    }
  }
}

/// chop() の戻り値
public struct Chop {
  /// 切り終えた回数 (TopVeg の cuts に渡す)
  public var cuts: Double
  /// 包丁の位置 (vegCutX に渡す、cuts + 途中の割合)
  public var pos: Double
  /// 包丁の持ち上げ (TopKnife の lift)
  public var lift: Double
}

/// 刻む動き: from〜to フレームの間に count 回包丁を下ろす。
/// cuts = 切り終えた回数 (TopVeg の cuts に渡す)、pos = 包丁の位置 (vegCutX に渡す、cuts + 途中の割合)、lift = 包丁の持ち上げ (TopKnife の lift)
public func chop(_ frame: Double, _ from: Double, _ to: Double, _ count: Double) -> Chop {
  let t = clamp01((frame - from) / max(1, to - from))
  let raw = t * count
  let cuts = min(count, floor(raw))
  let phase = raw - floor(raw)
  return Chop(cuts: cuts, pos: raw, lift: t > 0 && t < 1 ? sin(phase * Double.pi) : 0)
}

/// 野菜の種類 (TopVeg の kind)
public enum VegKind { case carrot, cucumber, onion, tomato }

// right: 右端 (切り始め) の x、left: 左端の x、thick: 1 切れの厚さ
private func vegSpec(_ kind: VegKind) -> (right: Double, left: Double, thick: Double) {
  switch kind {
  case .carrot: return (172, -150, 26)
  case .cucumber: return (172, -172, 26)
  case .onion: return (90, -90, 22)
  case .tomato: return (85, -85, 24)
  }
}
/// cuts 回切ったときの切り口の x (TopVeg のローカル座標)。包丁は place(x, y, scale, angle, Pt(vegCutX(kind, pos), 0)) に置く
public func vegCutX(_ kind: VegKind, _ cuts: Double) -> Double {
  let v = vegSpec(kind)
  return v.right - v.thick * max(0, min(cuts, vegMaxCuts(kind)))
}
/// 切れる回数の上限
public func vegMaxCuts(_ kind: VegKind) -> Double {
  let v = vegSpec(kind)
  return floor((v.right - v.left) / v.thick) - 1
}

private func vegShape(_ kind: VegKind) -> String {
  switch kind {
  case .carrot: return "M -150 -34 Q -60 -32 170 -4 Q 178 0 170 4 Q -60 32 -150 34 Q -162 0 -150 -34 Z"
  case .cucumber: return "M -172 0 Q -172 -30 -142 -32 L 142 -30 Q 172 -28 172 0 Q 172 28 142 30 L -142 32 Q -172 30 -172 0 Z"
  case .onion: return "M -90 0 A 90 88 0 1 0 90 0 A 90 88 0 1 0 -90 0 Z"
  case .tomato: return "M -85 0 A 85 82 0 1 0 85 0 A 85 82 0 1 0 -85 0 Z"
  }
}
private func vegColor(_ kind: VegKind) -> Paint {
  switch kind {
  case .carrot: return "#e58a3a"
  case .cucumber: return "#5f8f3e"
  case .onion: return "#efe0bd"
  case .tomato: return "#d6533f"
  }
}

/// 野菜の模様 (輪郭の内側)
private func VegDetail(kind: VegKind) {
  switch kind {
  case .carrot:
    g(fill: Paint.none, stroke: "#c46a24", strokeWidth: 4, strokeLinecap: .round) {
      for (i, vx) in [-110.0, -50, 10, 70, 120].enumerated() {
        path("M \(vx) \(i % 2 != 0 ? -18 : 6) l 6 12")
      }
    }
  case .cucumber:
    g {
      path("M -140 -12 Q 0 -18 140 -12", fill: Paint.none, stroke: "#82ad5c", strokeWidth: 8, strokeLinecap: .round)
      for i in 0 ..< 12 {
        circle(cx: -140 + Double(i) * 25, cy: Double(i % 3) * 14 - 2, r: 2.6, fill: "#3f6b2a")
      }
    }
  case .onion:
    g(fill: Paint.none, stroke: "#d4bf8e", strokeWidth: 4) {
      path("M -80 0 Q 0 -70 80 0 M -80 0 Q 0 70 80 0 M -84 0 H 84")
    }
  case .tomato:
    g {
      path("M -40 -50 Q -60 -34 -64 -10", fill: Paint.none, stroke: "#ec8a74", strokeWidth: 8, strokeLinecap: .round)
      path("M 0 -6 L -26 -20 L -6 -2 L -22 20 L 2 4 L 24 18 L 8 -2 L 26 -22 Z", fill: "#5f8f3e", stroke: "#353b35", strokeWidth: 3, strokeLinejoin: .round)
    }
  }
}

/// 野菜 (真上から)。kind: .carrot にんじん / .cucumber きゅうり / .onion 玉ねぎ (むいたもの) / .tomato トマト。
/// 横向き (angle 0) で右端から切る。cuts: 切った回数 (0〜vegMaxCuts)、切った分は右へ少しずつずれて並ぶ。
/// id は元の版 (clipPath の名前) との互換のために残してある (Swift 版では使わない)
public func TopVeg(x: Double, y: Double, kind: VegKind = .carrot, angle: Double = 0, scale: Double = 1, cuts: Double = 0, gap: Double = 8, id: String? = nil) {
  let palette = useGuide().palette
  let d = vegShape(kind)
  let n = Int(max(0, min(vegMaxCuts(kind), floor(cuts))))
  let cut = { (k: Int) -> Double in k == 0 ? 400 : vegCutX(kind, Double(k)) }
  // 0 = 切り残し、1〜n = 切った 1 切れ (1 が右端)
  var segs: [(a: Double, b: Double, dx: Double)] = [(-400, cut(n), 0)]
  for j in 0 ..< n { segs.append((cut(j + 1), cut(j), gap * Double(n - j))) }
  let body = {
    path(d, fill: vegColor(kind))
    g(clip: .path(d)) {
      VegDetail(kind: kind)
    }
    path(d, fill: Paint.none, stroke: palette.ink, strokeWidth: 5, strokeLinejoin: .round)
  }
  g(transform: [.translate(x, y), .rotate(angle), .scale(scale)]) {
    // 影
    path(d, fill: "#6b4a25", opacity: 0.18, transform: [.translate(6 + gap * Double(n) * 0.5, 8)])
    // にんじんのへた
    if kind == .carrot {
      g(strokeLinecap: .round) {
        path("M -150 -10 L -184 -24 M -152 0 L -190 2 M -150 10 L -182 26", stroke: palette.ink, strokeWidth: 16)
        path("M -150 -10 L -184 -24 M -152 0 L -190 2 M -150 10 L -182 26", stroke: "#6f9a45", strokeWidth: 7)
      }
    }
    for (i, s) in segs.enumerated() {
      g(transform: [.translate(s.dx, 0)]) {
        g(clip: .rect(x: s.a, y: -200, width: s.b - s.a, height: 400)) {
          body()
          // 切り口の線
          g(stroke: palette.ink, strokeWidth: 4, clip: .path(d)) {
            if i > 0 || n > 0 { path("M \(s.b) -200 V 200") }
            if i > 0 { path("M \(s.a) -200 V 200") }
          }
        }
      }
    }
  }
}

/// 真上から見たフライパンの柄を握る位置 (画面座標)。angle は TopPan と同じ (0 = 柄が右)
public func topPanGrip(_ x: Double, _ y: Double, _ r: Double, _ angle: Double = 0) -> Pt {
  let a = (angle * Double.pi) / 180
  let d = r * 1.95
  return Pt(x + cos(a) * d, y + sin(a) * d)
}

/// フライパン (真上から)。r = 半径、angle = 柄の向き (度、0 = 右、時計回り)。
/// content は鍋肌の上に画面座標で描く (中身)。oil: 油のつや (0〜1)、sizzle: ジュージューはねる油 (0〜1)
public func TopPan(x: Double, y: Double, r: Double = 170, angle: Double = 0, oil: Double = 0, sizzle: Double = 0, _ content: () -> Void = {}) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let palette = useGuide().palette
  let t = frame / fps
  g {
    g(transform: [.translate(x, y), .rotate(angle)]) {
      ellipse(cx: r * 0.1, cy: r * 0.12, rx: r, ry: r, fill: "#6b4a25", opacity: 0.18)
      // 柄 (長さは半径に比例)
      path("M \(r * 0.9) 0 H \(r * 1.45)", stroke: palette.ink, strokeWidth: r * 0.15 + 6, strokeLinecap: .round)
      path("M \(r * 0.9) 0 H \(r * 1.45)", stroke: "#8a9396", strokeWidth: r * 0.15 - 6, strokeLinecap: .round)
      Inked(palette) {
        rect(x: r * 1.4, y: -r * 0.12, width: r * 1.1, height: r * 0.24, rx: r * 0.11, fill: WOOD)
      }
      circle(cx: r * 2.38, cy: 0, r: r * 0.04 + 2, fill: "#d8b98e", stroke: palette.ink, strokeWidth: 3)
      Inked(palette) {
        circle(cx: 0, cy: 0, r: r, fill: IRON)
      }
      circle(cx: 0, cy: 0, r: r * 0.86, fill: IRON_IN, stroke: palette.ink, strokeWidth: 3)
      // 油のつや: 内側の縁に沿った明るい弧
      if oil > 0 {
        path("M \(-r * 0.7) \(-r * 0.1) A \(r * 0.72) \(r * 0.72) 0 0 1 \(-r * 0.1) \(-r * 0.7)", fill: Paint.none, stroke: "#f0dca0", strokeWidth: r * 0.06,
             strokeLinecap: .round, opacity: 0.55 * clamp01(oil))
      }
    }
    content()
    if sizzle > 0 {
      for i in 0 ..< 12 {
        let k = jsMod(t * 1.5 + random("tpan-k\(i)"), 1)
        let a = random("tpan-a\(i)") * Double.pi * 2
        let dd = random("tpan-d\(i)").squareRoot() * r * 0.75
        circle(cx: x + cos(a) * dd, cy: y + sin(a) * dd, r: 3 + k * 9, fill: Paint.none, stroke: "#f4e3a8", strokeWidth: 3, opacity: clamp01(sizzle) * (1 - k))
      }
    }
  }
}

// ---------- 一覧 (jgv catalog) ----------

/// 台所の道具の一覧 (KIT_CATALOG に並べる)
public let CATALOG_KITCHEN: [PreviewItem] = [
  PreviewItem(name: "Pot", note: "lidOpen fill steam", scale: 0.58, parts: POT_PARTS) { x, y, s in Pot(x: x, y: y, scale: s, lidOpen: 0.3, steam: 1) },
  PreviewItem(name: "FryingPan", note: "food toss sizzle flip", scale: 0.55, dx: -50, parts: PAN_PARTS) { x, y, s in FryingPan(x: x, y: y, scale: s, food: .veg, sizzle: 1) },
  PreviewItem(name: "Knife", note: "flip", scale: 0.8, dy: -40, parts: KNIFE_PARTS) { x, y, s in Knife(x: x, y: y, scale: s) },
  PreviewItem(name: "CuttingBoard", note: "pieces food", scale: 0.65, parts: CUTTING_BOARD_PARTS) { x, y, s in CuttingBoard(x: x, y: y, scale: s, pieces: 5) },
  PreviewItem(name: "Bowl", note: "fill food", scale: 0.85, parts: BOWL_PARTS) { x, y, s in Bowl(x: x, y: y, scale: s, fill: 0.8) },
  PreviewItem(name: "MeasuringCup", note: "fill liquid flip", scale: 1, parts: MEASURING_CUP_PARTS) { x, y, s in MeasuringCup(x: x, y: y, scale: s, fill: 0.5) },
  PreviewItem(name: "MeasuringSpoon", note: "amount color flip", scale: 1, dx: -60, dy: -40, parts: MEASURING_SPOON_PARTS) { x, y, s in
    MeasuringSpoon(x: x, y: y, scale: s, amount: 1)
  },
  PreviewItem(name: "Ladle", note: "fill soup flip", scale: 0.62, dx: -20, parts: LADLE_PARTS) { x, y, s in Ladle(x: x, y: y, scale: s, fill: 1) },
  PreviewItem(name: "Saibashi", note: "open", scale: 0.6, dx: -30, parts: SAIBASHI_PARTS) { x, y, s in Saibashi(x: x, y: y, scale: s, open: 0.5) },
  PreviewItem(name: "Microwave", note: "open on display children", scale: 0.6, parts: MICROWAVE_PARTS) { x, y, s in Microwave(x: x, y: y, scale: s, on: 1, display: "1:30") },
  PreviewItem(name: "RiceCooker", note: "open display steam", scale: 0.62, parts: RICE_COOKER_PARTS) { x, y, s in
    RiceCooker(x: x, y: y, scale: s, open: 0.3, display: "炊飯", steam: 1)
  },
  PreviewItem(name: "Fridge", note: "open children (床に置く)", scale: 0.34, parts: FRIDGE_PARTS) { x, y, s in
    Fridge(x: x, y: y, scale: s, open: 0.7) {
      Bowl(x: -40, y: FRIDGE_PARTS.shelf1.y, scale: 0.5, fill: 0.8)
    }
  },
  PreviewItem(name: "TopCuttingBoard / TopVeg", note: "cuts (手元俯瞰)", scale: 1) { x, y, _ in
    TopCuttingBoard(x: x, y: y - 100, w: 280, h: 180)
    TopVeg(x: x - 10, y: y - 100, scale: 0.62, cuts: 5, id: "cat-carrot")
  },
  PreviewItem(name: "TopKnife", note: "angle scale lift (手元俯瞰)", scale: 0.55, dy: -100, parts: TOP_KNIFE_PARTS) { x, y, s in TopKnife(x: x, y: y, scale: s) },
  PreviewItem(name: "TopPan", note: "r angle oil sizzle (手元俯瞰)", scale: 1, dx: -40, dy: -100) { x, y, _ in
    TopPan(x: x, y: y, r: 72, oil: 1, sizzle: 1) {
      TopVeg(x: x, y: y, kind: .tomato, scale: 0.4, cuts: 3, id: "cat-pan-tomato")
    }
  },
  PreviewItem(name: "TopVeg kind / cuts", note: "cucumber onion tomato", scale: 0.4, dy: -100) { x, y, s in
    TopVeg(x: x - 50, y: y - 55, kind: .cucumber, scale: s, cuts: 3, id: "cat-cuc")
    TopVeg(x: x - 70, y: y + 45, kind: .onion, scale: s, id: "cat-onion")
    TopVeg(x: x + 60, y: y + 45, kind: .tomato, scale: s, id: "cat-tomato")
  },
]
