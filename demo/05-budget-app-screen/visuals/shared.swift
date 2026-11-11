// 画面配置: 左にスマホ、右にポイントメモ
import JGVKit

let PH = phoneSpace(x: 560, y: 226, h: 652)
let K = PH.k
/// 設計座標 → 画面座標
func toScreen(_ p: Pt) -> Pt { PH.pt(p) }
let NOTES = (x: 1000.0, y: 270.0, w: 820.0)
/// 設計座標の矩形 → 画面座標
func rectToScreen(_ r: Box) -> Box { PH.rect(r) }
