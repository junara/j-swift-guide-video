// すすいで乾燥 (拡大): ぬるま湯で泡を流しきる → タオルで水気を拭く → 風通しの良い場所で乾かす (時間は短縮)
import JGVKit

private let BASE_L = Pt(760, 790)
private let BASE_R = Pt(1480, 790)
private let DRY = Pt(1000, 540)

func RinseDry(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  // 1 行目: 左右に動かしながらすすぐ
  let water = n.frame < n.endOf(0) + 4
  let rinse = interpolate(n.frame, [n.at(0, 0.2), n.endOf(0)], [0, 1], .clamp)
  let slide = water ? sin((n.frame - n.at(0)) * 0.07) * 110 * n.ease(0) : 0
  // 2 行目: タオルで拭く
  let wipe = interpolate(n.frame, [n.atPhrase(1, 1, -0.3), n.endOf(1)], [0, 1], .clamp)
  let towelP = zigzag(wipe, F.x - 150, F.x + 150, F.y - 90, F.y + 90, 3)
  // 3 行目: 乾かす場所へ
  let move = n.ease(2, -0.1)
  let pos = mix(Pt(F.x + slide, F.y), DRY, move)
  let dryAt = n.atPhrase(2, 1, -0.1)
  let dry = interpolate(n.frame, [dryAt, n.endOf(2)], [0, 1], .clamp)
  let wet = (1 - 0.7 * wipe) * (1 - dry)
  let holdL = place(pos.x, pos.y, F.scale, 0, FILTER_PARTS.holdL)
  let holdR = place(pos.x, pos.y, F.scale, 0, FILTER_PARTS.holdR)
  let letGo = interpolate(n.frame, [n.at(2, 0.6), n.at(2, 1.1)], [0, 1], .clamp)
  let hL = mix(holdL, BASE_L, letGo)
  var hR = holdR
  if n.frame >= n.at(1, -0.2) { hR = mix(holdR, towelP, n.ease(1, -0.2)) }
  if n.frame >= n.at(2, -0.2) { hR = mix(towelP, holdR, n.ease(2, -0.2)) }
  hR = mix(hR, BASE_R, letGo)
  let sink = 1 - move
  let timer = Pt(1420, 470)

  Stage {
    Worker(handR: mix(LOW, POINT, n.ease(0, -0.3)), gloves: 1)
    CloseUp(steps: [
      CloseUpStep("ぬるま湯で十分にすすぐ", at: n.at(0, -0.2)),
      CloseUpStep("タオルで水気を拭く", at: n.at(1, -0.2)),
      CloseUpStep("風通しの良い場所で乾燥", at: n.at(2, -0.2)),
    ]) {
      g(opacity: sink) {
        Sink(x: SINK.x, y: SINK.y)
        Faucet(x: TAP.x, y: TAP.y, side: .right, height: 110)
      }
      // 風
      g(opacity: interpolate(n.frame, [n.atPhrase(2, 0, 0.2), n.atPhrase(2, 0, 0.6)], [0, 1], .clamp)) {
        for i in 0..<3 {
          let k = jsMod(n.sec * 0.9 + Double(i) / 3, 1)
          path("M \(700 + k * 520) \(400 + Double(i) * 90) q 30 -14 60 0 q 30 14 60 0", fill: "none", stroke: "#8ab8c8", strokeWidth: 6, strokeLinecap: .round, opacity: sin(k * Double.pi))
        }
        Towel(x: DRY.x, y: DRY.y + 190, scale: 2.6)
      }
      HoodFilter(x: pos.x, y: pos.y, scale: F.scale, oil: 0, gaps: 0, foam: 1 - rinse, wet: wet, seed: "sf")
      Stream(from: Pt(TAP.x, TAP.y + 4), to: Pt(TAP.x + 6, F.y - 40), color: "#a9d8ea", width: 20, active: water)
      if water { Drips(x: F.x, y: F.y + 150, w: 360, fall: 60, color: rinse < 0.5 ? "#ffffff" : "#8fcbe6", count: 9, seed: "rw") }
      if n.isSpeaking(1) { Drips(x: F.x, y: F.y + 150, w: 300, fall: 50, count: 4, seed: "rt") }
      if n.frame >= n.at(1, -0.2) && n.frame < n.at(2, 0.2) { Cloth(x: towelP.x, y: towelP.y, scale: 1.1, color: TOWEL_COLOR) }
      SleeveArm(from: BASE_L, to: hL, bend: 0.12)
      SleeveArm(from: BASE_R, to: hR, bend: -0.12)
      GloveHand(x: hL.x, y: hL.y)
      GloveHand(x: hR.x, y: hR.y)
      g(opacity: 1 - n.ease(1, -0.2)) {
        Callout(x: 1340, y: 360, text: "洗剤が残らないように", at: n.at(0, 0.3))
      }
      // 乾燥タイマー
      g(opacity: interpolate(n.frame, [dryAt - 6, dryAt + 4], [0, 1], .clamp)) {
        circle(cx: timer.x, cy: timer.y, r: 80, fill: palette.cream, stroke: palette.ink, strokeWidth: 5)
        Draw(d: circlePath(timer.x, timer.y, 60), progress: 1, color: "#e3dccb", width: 12)
        if dry > 0 { Draw(d: arcPath(timer.x, timer.y, 60, -90, -90 + 359.9 * dry), progress: 1, color: palette.primary, width: 12) }
        CountUp(at: dryAt, to: 100, durSec: max(0.5, (n.endOf(2) - dryAt) / n.fps), suffix: "%", x: timer.x, y: timer.y, size: 34, weight: 900, color: palette.ink)
      }
      Callout(x: timer.x, y: timer.y + 130, text: "乾燥時間は短縮しています", at: dryAt + 6)
      CheckBadge(x: DRY.x + 230, y: DRY.y - 150, at: n.endOf(2) - 4)
    }
  }
}
