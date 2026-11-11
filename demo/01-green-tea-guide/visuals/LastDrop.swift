// STEP 5: 拡大カードで、急須を大きく傾けて最後の一滴が落ちる。2 行目で「うまみ凝縮」
import JGVKit

func LastDrop(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let cup = Pt(1000, 735)
  let tilt = -62 * n.ease(0, -0.2)
  let pos = Pt(1250, 520)
  let spout = place(pos.x, pos.y, 1.15, tilt, TEAPOT_PARTS.spout)
  let grip = place(pos.x, pos.y, 1.15, tilt, TEAPOT_PARTS.grip)
  // しずくが 1.1 秒ごとに膨らんで落ちる
  let period = jsRound(n.fps * 1.1)
  let t = jsMod(jsMod(n.frame - n.at(0, 0.4), period) + period, period)
  let active = n.frame >= n.at(0, 0.4)
  let grow = interpolate(t, [0, period * 0.5], [0.3, 1], .clamp)
  let fall = interpolate(t, [period * 0.5, period * 0.85], [0, 1], .clamp)
  let dropY = spout.y + 18 + fall * fall * (cup.y - 150 - spout.y)
  let ripple = interpolate(t, [period * 0.85, period], [0, 1], .clamp)
  let surface = cup.y - 120

  Stage {
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.3)))
    CloseUp(steps: [
      CloseUpStep("最後の一滴まで注ぐ", at: n.at(0, -0.2)),
      CloseUpStep("うまみが凝縮", at: n.at(1, -0.1)),
    ]) {
      Yunomi(x: cup.x, y: cup.y, scale: 1.35, fill: 0.8)
      if active {
        path("M \(spout.x) \(dropY - 16 * grow) q \(12 * grow) \(20 * grow) 0 \(30 * grow) q \(-12 * grow) \(-10 * grow) 0 \(-30 * grow) Z",
             fill: "#c3cf72", stroke: palette.ink, strokeWidth: 3, transform: [.translate((cup.x - spout.x) * fall, 0)])
        if ripple > 0 {
          ellipse(cx: cup.x, cy: surface, rx: 20 + ripple * 60, ry: 5 + ripple * 12, fill: Paint.none, stroke: palette.ink, strokeWidth: 3, opacity: 1 - ripple)
        }
      }
      Teapot(x: pos.x, y: pos.y, scale: 1.15, angle: tilt)
      SleeveArm(from: Pt(1640, 720), to: grip, bend: -0.15)
      Burst(at: n.at(1, 0.1), x: cup.x, y: surface - 40, r: 120, count: 14, color: palette.accent)
      Pop(at: n.at(1, 0.2), x: cup.x - 190, y: cup.y - 330) {
        rect(x: -150, y: -46, width: 300, height: 92, rx: 46, fill: palette.primary, stroke: palette.ink, strokeWidth: 4)
        T("うまみ凝縮", x: 0, y: 0, size: 44, weight: 900, color: "#fff")
      }
    }
  }
}
