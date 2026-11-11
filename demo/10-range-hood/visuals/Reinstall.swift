// 取り付ける: 乾いたことを確認 → 両手で持ち上げて元の位置へ → つまみを戻して固定を確認 → プラグを差して運転、音・振動を確認 → 完了
import JGVKit

private let IN_HOOD = hood(HOOD_PARTS.filter)
private let HOOD_SCALE = HOOD_FILTER.w / FILTER_W
private let REST_PT = Pt(REST.x, REST.y)

func Reinstall(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let fs = n.fps
  // 2 行目: 持ち上げて元の位置へ
  let liftAt = n.atPhrase(1, 1, 0.1)
  let liftDur = max(1.0, (n.endOf(1) - liftAt) / fs - 0.2)
  let liftMove = Move(at: liftAt, to: IN_HOOD, dur: liftDur, lift: 60)
  let fpos = track(n.frame, fs, REST_PT, [liftMove])
  let lift = interpolate(n.frame, [liftAt, liftAt + liftDur * fs], [0, 1], .clamp)
  let inserted = lift >= 1
  let fscale = REST.scale + (HOOD_SCALE - REST.scale) * lift
  let holdL = place(fpos.x, fpos.y, fscale, 0, FILTER_PARTS.holdL)
  let holdR = place(fpos.x, fpos.y, fscale, 0, FILTER_PARTS.holdR)
  // 3 行目: つまみを戻す
  let knob = 1 - interpolate(n.frame, [n.atPhrase(2, 1, -0.2), n.atPhrase(2, 1, 0.5)], [0, 1], .clamp)
  let knobL = hood(HOOD_PARTS.knobL)
  let knobR = hood(HOOD_PARTS.knobR)
  // 4 行目: プラグ → スイッチ → 運転
  let plugIn = interpolate(n.frame, [n.atPhrase(3, 0, 0.4), n.atPhrase(3, 0, 0.9)], [0, 1], .clamp)
  let plug = mix(PLUG_OUT, PLUG_IN, plugIn)
  let onAt = n.atPhrase(3, 1, 0.5)
  let on: Double = n.frame >= onAt ? 1 : 0
  let spin = spinAngle(n.frame) { f in f < onAt ? 0 : 16 * min(1, (f - onAt) / (fs * 0.8)) }
  let gloves = 1 - n.ease(3, -0.3)
  // 手
  let point = Pt(REST.x - 150, REST.y - 60)
  var hR = mix(PRESENTER.restR, point, n.ease(0, -0.1))
  var hL = PRESENTER.restL
  if n.frame >= n.at(1, -0.2) {
    let grab = n.ease(1, -0.2)
    hR = mix(hR, holdR, grab)
    hL = mix(PRESENTER.restL, holdL, grab)
  }
  if n.frame >= n.at(2, -0.2) {
    hR = mix(holdR, Pt(knobR.x, knobR.y + 30), n.ease(2, -0.2))
    hL = mix(holdL, Pt(knobL.x, knobL.y + 30), n.ease(2, -0.2))
  }
  if n.frame >= n.at(3, -0.3) {
    hL = mix(Pt(knobL.x, knobL.y + 30), PRESENTER.restL, n.ease(3, -0.3))
    let toPlug = mix(Pt(knobR.x, knobR.y + 30), Pt(plug.x, plug.y + 24), n.ease(3, -0.3))
    let toButton = n.ease(3, 0) * interpolate(n.frame, [n.atPhrase(3, 1, -0.2), n.atPhrase(3, 1, 0.3)], [0, 1], .clamp)
    hR = n.frame < n.atPhrase(3, 1, -0.2) ? toPlug : mix(Pt(PLUG_IN.x, PLUG_IN.y + 24), Pt(BUTTON.x, BUTTON.y + 16), toButton)
  }
  if n.frame >= n.atPhrase(3, 2, -0.3) {
    hR = mix(Pt(BUTTON.x, BUTTON.y + 16), PRESENTER.gestureR, interpolate(n.frame, [n.atPhrase(3, 2, -0.3), n.atPhrase(3, 2, 0.3)], [0, 1], .clamp))
  }
  let done = n.at(4, 0.2)

  Stage {
    Outlet(x: OUTLET.x, y: OUTLET.y)
    Plug(x: plug.x, y: plug.y, angle: (1 - plugIn) * 20, cordFrom: CORD_FROM)
    Suction(x: COOK.x, y: HOOD.y + 10, from: 170, on: interpolate(n.frame, [onAt, onAt + fs], [0, 1], .clamp))
    RangeHood(x: HOOD.x, y: HOOD.y, on: on, spin: spin, knob: knob, hideFilter: !inserted)
    Sparkles(x: HOOD.x, y: HOOD.y - 120, w: 560, h: 180, on: n.ease(4, 0), count: 9, seed: "ri")
    Cooktop(x: COOK.x, y: COOK.y)
    NewsSheet(x: NEWS.x, y: NEWS.y, w: NEWS.w, stain: 1)
    if !inserted { HoodFilter(x: fpos.x, y: fpos.y, scale: fscale, flat: 1 + 0.17 * lift) }
    // 1 行目: 乾いたか確認
    g(opacity: 1 - n.ease(1, -0.2)) {
      Callout(x: REST.x, y: REST.y - 120, text: "完全に乾いているか確認", at: n.at(0, 0.2))
      CheckBadge(x: REST.x + 150, y: REST.y - 40, at: n.endOf(0) - 8, r: 34)
    }
    // 3 行目: 固定の確認
    Pulse(x: knobL.x, y: knobL.y, r: 50, color: palette.accent, period: 1.2, active: n.isSpeaking(2))
    Pulse(x: knobR.x, y: knobR.y, r: 50, color: palette.accent, period: 1.2, active: n.isSpeaking(2))
    g(opacity: 1 - n.ease(3, -0.1)) {
      Callout(x: HOOD.x, y: HOOD.y + 70, text: "しっかりはまっているか確認", at: n.at(2, 0.2))
    }
    // 4 行目: 音・振動の確認
    g(opacity: interpolate(n.frame, [n.atPhrase(3, 2), n.atPhrase(3, 2, 0.4)], [0, 1], .clamp) * (1 - n.ease(4, 0))) {
      for i in 0..<3 {
        let k = jsMod(n.sec * 0.8 + Double(i) / 3, 1)
        let r = 40 + k * 90
        path("M \(HOOD.x + 330 + r * 0.5) \(HOOD.y - 180 - r * 0.6) A \(r) \(r) 0 0 1 \(HOOD.x + 330 + r * 0.5) \(HOOD.y - 180 + r * 0.6)",
             fill: "none", stroke: palette.primary, strokeWidth: 6, strokeLinecap: .round, opacity: 1 - k)
      }
      Callout(x: HOOD.x, y: HOOD.y + 70, text: "異常な音や振動がないか確認", at: n.atPhrase(3, 2))
    }
    Burst(at: done, x: HOOD.x, y: HOOD.y - 100, r: 380, count: 18, color: palette.accent)
    Callout(x: HOOD.x, y: HOOD.y + 70, text: "掃除完了！", at: done)
    CheckBadge(x: HOOD.x + 380, y: HOOD.y - 100, at: done + 4, r: 52)
    Worker(handL: hL, handR: hR, gloves: gloves)
  }
}
