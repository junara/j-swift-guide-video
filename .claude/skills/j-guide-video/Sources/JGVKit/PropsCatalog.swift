// kit の道具の一覧 (jgv catalog → out/props-catalog.png)。
// 赤い点 = 原点 (x, y に渡す位置)、橙の点 = *_PARTS (持ち手など。place() で画面座標にする)
import Foundation

// 道具を足したらここにも追加する (name: 部品名、note: 主な props、dx / dy: セルの基準位置からの原点のずらし量)
public let KIT_CATALOG: [PreviewItem] = {
  // 家事の道具のうち Laptop 以降 (ノート PC・封筒・水滴など) は、台所の道具の後に並べる
  let split = CATALOG_HOUSEHOLD.firstIndex { $0.name == "Laptop" } ?? CATALOG_HOUSEHOLD.count
  // 1 つの式で配列と配列の一部を + でつなぐと、古い Swift では型を決めるのに時間がかかりすぎるので、順に足す
  var all: [PreviewItem] = CATALOG_PROPS
  all.append(contentsOf: CATALOG_HOUSEHOLD[..<split])
  all.append(contentsOf: CATALOG_KITCHEN)
  all.append(contentsOf: CATALOG_HOUSEHOLD[split...])
  all.append(contentsOf: CATALOG_EFFECTS)
  return all
}()

let CATALOG_PROPS: [PreviewItem] = [
  PreviewItem(name: "Kettle", note: "color flip", scale: 0.8, parts: KETTLE_PARTS) { x, y, s in Kettle(x: x, y: y, scale: s) },
  PreviewItem(name: "Mug", note: "fill", scale: 0.75, dx: -20, parts: MUG_PARTS) { x, y, s in Mug(x: x, y: y, scale: s, fill: 0.7) },
  PreviewItem(name: "Yunomi", note: "fill", scale: 1, parts: YUNOMI_PARTS) { x, y, s in Yunomi(x: x, y: y, scale: s, fill: 0.7) },
  PreviewItem(name: "Teapot", note: "lidOpen", scale: 0.68, parts: TEAPOT_PARTS) { x, y, s in Teapot(x: x, y: y, scale: s) },
  PreviewItem(name: "Canister", note: "label", scale: 0.9) { x, y, s in Canister(x: x, y: y, scale: s) },
  PreviewItem(name: "Spoon", note: "leaves", scale: 0.9, dx: -30, dy: -40, parts: SPOON_PARTS) { x, y, s in Spoon(x: x, y: y, scale: s, leaves: true) },
  PreviewItem(name: "DripBag", note: "open hooks", scale: 0.7, parts: DRIPBAG_PARTS) { x, y, s in DripBag(x: x, y: y, scale: s, open: 1, hooks: 1) },
]

let CATALOG_EFFECTS: [PreviewItem] = [
  PreviewItem(name: "DropIn", note: "at shadowW height", scale: 0.6) { x, y, s in DropIn(at: 0, x: x, y: y) { gy in Mug(x: x, y: gy, scale: s) } },
  PreviewItem(name: "Ripple", note: "at", scale: 1) { x, y, s in
    Basin(x: x, y: y, scale: s, color: "#cfe3ea")
    Ripple(x: x, y: y - 70 * s, w: 160 * s)
  },
  PreviewItem(name: "NoSign", note: "r at", scale: 1, dy: -90) { x, y, _ in NoSign(x: x, y: y, r: 48) },
  PreviewItem(name: "ArcTimer", note: "progress label", scale: 1, dy: -100) { x, y, _ in ArcTimer(x: x, y: y, r: 58, progress: 0.65, label: "5分") },
  PreviewItem(name: "Presenter smile", note: "smile 0 / 1", scale: 0.36) { x, y, s in
    for (i, dx) in [-70.0, 70.0].enumerated() {
      g(transform: [.translate(x + dx, y), .scale(s), .translate(-(x + dx), -y)]) { Presenter(x: x + dx, y: y, smile: Double(i)) }
    }
  },
  PreviewItem(name: "Presenter look", note: "male / female / neutral", scale: 0.3) { x, y, s in
    for (i, look) in PresenterLook.allCases.enumerated() {
      let px = x + Double(i - 1) * 90
      g(transform: [.translate(px, y), .scale(s), .translate(-px, -y)]) { Presenter(x: px, y: y, look: look) }
    }
  },
  PreviewItem(name: "Steam / Grains", scale: 1) { x, y, _ in
    Steam(x: x - 60, y: y - 40)
    Grains(x: x + 70, y: y - 60, spread: 60)
  },
]
