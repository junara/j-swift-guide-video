// 全シーン共通の配置: 壁のエアコン、コンセント、プラグの位置
import JGVKit

let AC = Pt(1100, 235)
let OUTLET = Pt(1420, 690)
let CORD_FROM = place(AC.x, AC.y, 1, 0, AIRCON_PARTS.cord)
let PLUG_IN = Pt(OUTLET.x, OUTLET.y + 10)
let PLUG_OUT = Pt(OUTLET.x - 70, OUTLET.y + 70)
/// 拡大カードでのエアコン
struct BigPlace { var x: Double; var y: Double; var scale: Double }
let AC_BIG = BigPlace(x: 1120, y: 380, scale: 1.5)
/// パネルの開き具合 p のときの、パネル下端 (ローカル y)
func panelEdgeY(_ p: Double) -> Double { 130 - 236 * p }
/// 拡大カードの人物の右手 (カードの縁を指す)
let POINT = Pt(615, 515)
