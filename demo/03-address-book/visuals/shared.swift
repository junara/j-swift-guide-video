// 拡大カードのシーン共通: 人物の右手はカードの縁を指す
import JGVKit

let POINT = Pt(548, 520)
func pointHand(_ t: Double) -> Pt { mix(PRESENTER.restR, POINT, t) }
