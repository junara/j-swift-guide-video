// 道具の一覧画像のマス目 (kit の一覧 jgv catalog と、プロジェクトの見本 jgv preview で使う)。
// 赤い点 = 原点 (x, y に渡す位置)、橙の点 = *_PARTS (持ち手など。place() で画面座標にする)。
// groups ごとに見出し (title) を付けて、6 列で並べる
import Foundation

/// 道具の見本 (jgv preview の一覧画像の 1 コマ)。visuals/props.swift などで
/// `let PROPS_PREVIEW: [PreviewItem] = [...]` (ファイル名を大文字にした名前 + _PREVIEW) と並べると、一覧画像 out/preview.png に描かれる。
/// name: 部品名、note: 主な props や状態、scale: 一覧での倍率、dx / dy: コマの基準位置 (底の中心) からの原点のずらし量、
/// parts: *_PARTS (持ち手など。橙の点で描く)、draw: (x, y, scale) で原点・倍率を受け取って描く。
/// 原点は赤い点で描く。name に「/」を入れると (2 つの部品を並べるとき) 原点の点は描かない
public struct PreviewItem {
  public var name: String
  public var note: String?
  public var scale: Double
  public var dx: Double
  public var dy: Double
  public var parts: Parts?
  public var draw: (Double, Double, Double) -> Void
  public init(name: String, note: String? = nil, scale: Double, dx: Double = 0, dy: Double = 0, parts: Parts? = nil, draw: @escaping (Double, Double, Double) -> Void) {
    self.name = name; self.note = note; self.scale = scale; self.dx = dx; self.dy = dy; self.parts = parts; self.draw = draw
  }
}

public struct CatalogGroup {
  public var title: String?
  public var items: [PreviewItem]
  public init(title: String? = nil, items: [PreviewItem]) { self.title = title; self.items = items }
}

let COLS = 6
let CELL_W = 320.0
let CELL_H = 300.0
let BASE = 220.0 // セルの上端から原点 (底) までの高さ
let HEAD_H = 56.0 // 見出しの高さ

func rowsOf(_ g: CatalogGroup) -> Int { max(1, Int((Double(g.items.count) / Double(COLS)).rounded(.up))) }

public func catalogSizeOf(_ groups: [CatalogGroup]) -> (width: Double, height: Double) {
  (Double(COLS) * CELL_W, max(CELL_H, groups.reduce(0) { $0 + ($1.title != nil ? HEAD_H : 0) + Double(rowsOf($1)) * CELL_H }))
}

public func CatalogGrid(groups: [CatalogGroup]) {
  let gd = useGuide()
  let palette = gd.palette
  let size = catalogSizeOf(groups)
  rect(width: size.width, height: size.height, fill: "#fbf8f1")
  var top0 = 0.0
  g(fontFamily: gd.font) {
    for gr in groups {
      let head = top0
      let start = top0 + (gr.title != nil ? HEAD_H : 0)
      top0 = start + Double(rowsOf(gr)) * CELL_H
      if let title = gr.title {
        text(title, x: 20, y: head + 38, fontSize: 28, fontWeight: 800, fill: palette.ink)
      }
      for (i, it) in gr.items.enumerated() {
        let cx = Double(i % COLS) * CELL_W + CELL_W / 2
        let top = start + Double(i / COLS) * CELL_H
        let ox = cx + it.dx
        let y = top + BASE + it.dy
        rect(x: cx - CELL_W / 2 + 4, y: top + 4, width: CELL_W - 8, height: CELL_H - 8, rx: 14, fill: "#fff", stroke: "#e6dfd0", strokeWidth: 2)
        path("M \(cx - 120) \(top + BASE) H \(cx + 120)", stroke: "#e6dfd0", strokeWidth: 2, strokeDasharray: [6, 6])
        g { it.draw(ox, y, it.scale) }
        for (k, p) in it.parts?.items ?? [] where k != "screen" {
          let q = place(ox, y, it.scale, 0, p)
          circle(cx: q.x, cy: q.y, r: 6, fill: "#f08c2e", stroke: "#fff", strokeWidth: 2)
        }
        if !it.name.contains("/") { circle(cx: ox, cy: y, r: 6, fill: "#d6453a", stroke: "#fff", strokeWidth: 2) }
        text(it.name, x: cx, y: top + CELL_H - 50, fontSize: it.name.count > 16 ? 19 : 24, fontWeight: 800, fill: palette.ink, stroke: Paint.none, textAnchor: .middle)
        let sub = [it.note ?? "", it.scale != 1 ? "scale \((it.scale * 100).rounded() / 100)" : ""].filter { !$0.isEmpty }.joined(separator: " · ")
        text(sub, x: cx, y: top + CELL_H - 22, fontSize: 16, fill: "#8a8578", stroke: Paint.none, textAnchor: .middle)
      }
    }
  }
}
