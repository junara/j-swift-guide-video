// 複数の工程で使う配置と、電子レンジ (assets/microwave.svg) の描き方
import JGVKit

/// カウンターの天板
let Y = GUIDE.counterY
/// お茶わん・冷凍ごはん・お皿・電子レンジの定位置 (底の中心)
let CHAWAN = Pt(520, Y)
let RICE_REST = Pt(655, Y)
let PLATE_REST = Pt(810, Y)
let MW = Pt(1020, Y)
let MW_SCALE = 0.75

// ---------- 電子レンジ ----------

/// 電子レンジの SVG の持つ所 (ローカル座標): handle (扉が閉まっているときの取っ手)・inside (庫内の床の中心)・display (表示窓)・start (スタートボタン)
let MW_PARTS = svgParts("microwave")
/// 扉の蝶番の x (ローカル座標)。扉は左の蝶番で手前に開き、正面からは幅が縮んで見える
private let MW_HINGE = -198.0
/// 扉の見かけの幅の割合 (open 0 で 1、open 1 で 0.18)
private func doorWidth(_ open: Double) -> Double { 1 - 0.82 * min(1, max(0, open)) }

/// 扉の取っ手の画面座標 (手は place ではなくこれを使う。扉の開きに合わせて左へ動く)
func mwHandle(_ open: Double) -> Pt {
  let h = MW_PARTS.handle
  return place(MW.x, MW.y, MW_SCALE, 0, Pt(MW_HINGE + (h.x - MW_HINGE) * doorWidth(open), h.y))
}
/// スタートボタン・庫内の床の中心の画面座標
func mwStart() -> Pt { place(MW.x, MW.y, MW_SCALE, 0, MW_PARTS.start) }
func mwInside() -> Pt { place(MW.x, MW.y, MW_SCALE, 0, MW_PARTS.inside) }
/// 庫内に置いたお皿の倍率 (定位置のお皿は 1)
let DISH_IN_MW_SCALE = 0.8

/// 電子レンジ。open: 扉の開き (0〜1)、on: 庫内の明かり (0〜1)、display: 表示窓の文字、
/// dish: 庫内のお皿にのったごはん (heat, wrap)。nil なら空。dishShift: ターンテーブルで揺れるお皿の横のずれ (ローカル座標)
func MicrowaveSvg(x: Double = MW.x, y: Double = MW.y, scale: Double = MW_SCALE, open: Double, on: Double, display: String,
                  dish: (heat: Double, wrap: Double)?, dishShift: Double = 0) {
  // 庫内のお皿は扉より下に描きたいので、扉を隠して描いた後に扉だけを重ねる (末尾の { } は SVG の上に描かれるため)
  Svg("microwave", x: x, y: y, scale: scale, layers: [
    "door": .hidden,
    "light": SvgLayer(hidden: on <= 0.01, opacity: min(1, max(0, on))),
  ]) {
    if let dish {
      let p = MW_PARTS.inside
      DishWithRice(x: p.x + dishShift, y: p.y, scale: DISH_IN_MW_SCALE, heat: dish.heat, wrap: dish.wrap)
    }
  }
  Svg("microwave", x: x, y: y, scale: scale, layers: [
    "base": .hidden,
    "door": SvgLayer(transform: [.translate(MW_HINGE, 0), .scale(doorWidth(open), 1), .translate(-MW_HINGE, 0)]),
  ]) {
    let d = MW_PARTS.display
    text(display, x: d.x, y: d.y, fontSize: 21, fontWeight: 700, fontFamily: "Menlo", fill: "#9fe0b0", stroke: "none",
         textAnchor: .middle, dominantBaseline: .central)
  }
}

// ---------- カウンターの上の道具一式 ----------

/// カウンターの上の道具を状態どおりに描く。手で動かしている物は引数で外し、visual で別に描く
///   chawan: お茶わんのごはんの量、rice: 定位置の冷凍ごはん (heat, wrap)、dishAtRest: 定位置のお皿にのったごはん (お皿だけなら nil で plate: true)
func CounterSet(chawan: Double, rice: (heat: Double, wrap: Double)?, plate: Bool, dishAtRest: (heat: Double, wrap: Double)?,
                open: Double, on: Double, display: String, dishInMw: (heat: Double, wrap: Double)?, dishShift: Double = 0) {
  Shadow(x: MW.x, w: 360)
  MicrowaveSvg(open: open, on: on, display: display, dish: dishInMw, dishShift: dishShift)
  Shadow(x: CHAWAN.x, w: 130)
  Chawan(x: CHAWAN.x, y: CHAWAN.y, fill: chawan)
  if let rice {
    Shadow(x: RICE_REST.x, w: 140)
    FrozenRice(x: RICE_REST.x, y: RICE_REST.y, heat: rice.heat, wrap: rice.wrap)
  }
  if let d = dishAtRest {
    Shadow(x: PLATE_REST.x, w: 190)
    DishWithRice(x: PLATE_REST.x, y: PLATE_REST.y, heat: d.heat, wrap: d.wrap)
  } else if plate {
    Shadow(x: PLATE_REST.x, w: 190)
    Plate(x: PLATE_REST.x, y: PLATE_REST.y)
  }
}
