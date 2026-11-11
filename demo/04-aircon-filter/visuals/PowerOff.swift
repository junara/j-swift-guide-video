// 電源を切る: リモコンで停止 → 止まったことを確認 → 電源プラグを抜く
import JGVKit

func PowerOff(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let pressAt = n.at(0, 1.0)
  let press = interpolate(n.frame, [pressAt, pressAt + 12], [0, 1], .clamp)
  let on = 1 - interpolate(n.frame, [pressAt + 8, pressAt + 26], [0, 1], .clamp)
  // 右手: リモコンを AC に向ける → 3 行目でカウンターに置き、プラグへ
  let aim = Pt(640, 470)
  let raise = n.ease(0, -0.3)
  let putDown = interpolate(n.frame, [n.at(2, -0.2), n.at(2, 0.3)], [0, 1], .clamp)
  let toPlug = interpolate(n.frame, [n.atPhrase(2, 1, -0.3), n.atPhrase(2, 1, 0.2)], [0, 1], .clamp)
  let pull = interpolate(n.frame, [n.atPhrase(2, 1, 0.3), n.atPhrase(2, 1, 0.9)], [0, 1], .clamp)
  let plug = mix(PLUG_IN, PLUG_OUT, pull)
  let remoteHand = mix(PRESENTER.restR, aim, raise)
  let remotePos = mix(Pt(remoteHand.x, remoteHand.y - 46), Pt(760, 760), putDown)
  let handR = toPlug > 0 ? mix(remoteHand, Pt(plug.x, plug.y + 20), toPlug) : remoteHand
  Stage {
    Outlet(x: OUTLET.x, y: OUTLET.y)
    Plug(x: plug.x, y: plug.y, angle: pull * 25, cordFrom: CORD_FROM)
    AirCon(x: AC.x, y: AC.y, on: on)
    Pulse(x: AC.x, y: AC.y + 90, r: 250, color: palette.primary, period: 2, active: n.isSpeaking(1))
    Remote(x: remotePos.x, y: remotePos.y, angle: -25 * (1 - putDown) + 90 * putDown, press: press)
    Presenter(handR: handR)
    g(opacity: 1 - n.ease(2, -0.1)) {
      Callout(x: AC.x, y: AC.y + 290, text: "ファンが完全に止まったか確認", at: n.at(1, 0.1))
    }
    CheckBadge(x: AC.x + 330, y: AC.y + 40, at: n.endOf(1) - 6)
    Callout(x: OUTLET.x - 40, y: OUTLET.y - 110, text: "安全のためプラグを抜く", at: n.atPhrase(2, 0))
  }
}
