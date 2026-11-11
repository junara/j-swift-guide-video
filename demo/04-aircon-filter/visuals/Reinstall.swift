// 取り付ける: フィルターを持ち上げて差し込む → パネルを閉じる → プラグを差して運転を確認
import JGVKit

func Reinstall(_ props: Props) {
  let n = useNarration()
  // 1 行目: カウンターのフィルターを持ち上げ、エアコンの左の枠へ
  let slot = place(AC.x, AC.y, 1, 0, Pt(-130, 81))
  let rest = Pt(820, 700)
  let lift = interpolate(n.frame, [n.at(0, 0.2), n.endOf(0) - 4], [0, 1], .clamp)
  let e = 1 - pow(1 - lift, 2)
  let fpos = Pt(rest.x + (slot.x - rest.x) * e, rest.y + (slot.y - rest.y) * e - sin(e * Double.pi) * 120)
  let fscale = 0.6 + (0.36 - 0.6) * e
  let inserted = lift >= 1
  let grip = place(fpos.x, fpos.y, fscale, 0, FILTER_PARTS.handle)
  // 2 行目: パネルを閉じる
  let panel = 0.78 * (1 - interpolate(n.frame, [n.at(1, 0.1), n.endOf(1)], [0, 1], .clamp))
  let edge = place(AC.x, AC.y, 1, 0, Pt(0, panelEdgeY(panel)))
  // 3 行目: プラグを差し、運転
  let toPlug = interpolate(n.frame, [n.at(2, -0.1), n.at(2, 0.4)], [0, 1], .clamp)
  let plugIn = interpolate(n.frame, [n.at(2, 0.5), n.atPhrase(2, 0, 1.2)], [0, 1], .clamp)
  let plug = mix(PLUG_OUT, PLUG_IN, plugIn)
  let on = interpolate(n.frame, [n.atPhrase(2, 1, 0.3), n.atPhrase(2, 1, 0.9)], [0, 1], .clamp)
  let back = interpolate(n.frame, [n.atPhrase(2, 1, 0), n.atPhrase(2, 1, 0.5)], [0, 1], .clamp)
  var handR = mix(PRESENTER.restR, grip, n.ease(0, -0.2))
  if n.frame >= n.at(1) { handR = mix(handR, Pt(edge.x, edge.y + 10), n.ease(1, -0.2)) }
  if n.frame >= n.at(2, -0.1) { handR = mix(mix(Pt(edge.x, edge.y + 10), Pt(plug.x, plug.y + 24), toPlug), PRESENTER.gestureR, back) }
  Stage {
    Outlet(x: OUTLET.x, y: OUTLET.y)
    Plug(x: plug.x, y: plug.y, angle: (1 - plugIn) * 25, cordFrom: CORD_FROM)
    AirCon(x: AC.x, y: AC.y, on: on, panel: panel, hideFilter: !inserted)
    if !inserted { Filter(x: fpos.x, y: fpos.y, scale: fscale) }
    Presenter(handR: handR)
    Callout(x: AC.x, y: AC.y + 300, text: "正常に動くか確認", at: n.atPhrase(2, 1, 0.3))
    CheckBadge(x: AC.x + 330, y: AC.y + 40, at: n.atPhrase(2, 1, 0.9))
  }
}
