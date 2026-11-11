// 電源を切る: スイッチを押して停止 → 羽根がゆっくり止まるのを確認 → プラグを抜く (または専用ブレーカー) → 誤作動に注意
import JGVKit

func PowerOff(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  // 1 行目: スイッチを押す
  let pressAt = n.at(0, 1.0)
  let on: Double = n.frame < pressAt ? 1 : 0
  let tau = n.fps * 0.9
  let spin = spinAngle(n.frame) { f in f < pressAt ? 16 : 16 * exp(-(f - pressAt) / tau) }
  let stopped = n.atPhrase(1, 0, 0.6)
  // 2 行目: プラグを抜く
  let toPlug = interpolate(n.frame, [n.atPhrase(1, 1, -0.3), n.atPhrase(1, 1, 0.2)], [0, 1], .clamp)
  let pull = interpolate(n.frame, [n.atPhrase(1, 1, 0.3), n.atPhrase(1, 1, 0.9)], [0, 1], .clamp)
  let plug = mix(PLUG_IN, PLUG_OUT, pull)
  let back = n.ease(2, -0.2)
  var handR = mix(PRESENTER.restR, Pt(BUTTON.x, BUTTON.y + 16), n.ease(0, -0.1))
  if toPlug > 0 { handR = mix(handR, Pt(plug.x, plug.y + 24), toPlug) }
  if back > 0 { handR = mix(handR, PRESENTER.gestureR, back) }
  // ブレーカーのレバー
  let brkAt = n.atPhrase(1, 2, 0.2)
  let lever = interpolate(n.frame, [brkAt + 6, brkAt + 16], [0, 1], .clamp)

  Stage {
    Outlet(x: OUTLET.x, y: OUTLET.y)
    Plug(x: plug.x, y: plug.y, angle: pull * 20, cordFrom: CORD_FROM)
    Suction(x: COOK.x, y: HOOD.y + 10, from: 170, on: 1 - interpolate(n.frame, [pressAt, pressAt + n.fps], [0, 1], .clamp))
    RangeHood(x: HOOD.x, y: HOOD.y, on: on, spin: spin, dirt: 0.9, oil: 1, gaps: 0.8)
    Cooktop(x: COOK.x, y: COOK.y)
    Pulse(x: HOOD.x, y: HOOD.y - 40, r: 260, color: palette.primary, period: 1.6, active: n.isSpeaking(1) && n.frame < n.atPhrase(1, 1))
    g(opacity: 1 - n.ease(2, -0.2)) {
      Callout(x: HOOD.x, y: HOOD.y + 70, text: "羽根が完全に止まったか確認", at: n.at(1, 0.1))
    }
    CheckBadge(x: HOOD.x - 340, y: HOOD.y - 60, at: stopped)
    Callout(x: OUTLET.x + 20, y: OUTLET.y - 90, text: "電源プラグを抜く", at: n.atPhrase(1, 1, 0.2))
    // または専用ブレーカーを切る
    Pop(at: n.atPhrase(1, 2, -0.1), x: 1650, y: 560) {
      rect(x: -150, y: -120, width: 300, height: 240, rx: 22, fill: "#fff", stroke: palette.ink, strokeWidth: 4, filter: .shadow)
      T("または", x: 0, y: -88, size: 24, weight: 800, color: palette.ink)
      rect(x: -46, y: -60, width: 92, height: 110, rx: 10, fill: "#e9e5db", stroke: palette.ink, strokeWidth: 4)
      rect(x: -18, y: -40, width: 36, height: 70, rx: 6, fill: "#cfcbc1", stroke: palette.ink, strokeWidth: 3)
      rect(x: -14, y: -36 + lever * 34, width: 28, height: 30, rx: 5, fill: lever > 0.5 ? "#9aa3a5" : palette.accent, stroke: palette.ink, strokeWidth: 3)
      T("専用ブレーカーを切る", x: 0, y: 84, size: 26, weight: 900, color: palette.ink)
    }
    // 3 行目: 誤って動かないように
    Pop(at: n.at(2, 0.2), x: HOOD.x, y: HOOD.y + 150) {
      rect(x: -250, y: -40, width: 500, height: 80, rx: 40, fill: "#fff", stroke: "#d14b3b", strokeWidth: 4)
      Icon(name: "warning", x: -196, y: 0, size: 48, color: "#d14b3b")
      T("誤って動かないように", x: 24, y: 0, size: 30, weight: 900, color: palette.ink)
    }
    Worker(handR: handR)
  }
}
