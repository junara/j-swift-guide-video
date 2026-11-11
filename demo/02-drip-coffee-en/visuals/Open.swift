// Open the bag (拡大): 両手で持つ → 右手が上の帯を破り取る → そっと開いて粉が見える
import JGVKit

private let BAG = (x: 1120.0, y: 730.0, scale: 1.6)

func Open(_ props: Props) {
  let n = useNarration()
  let hold = n.ease(0, -0.3)
  let tearFrom = n.atPhrase(0, 1, 0.2)
  let tearTo = n.endOf(0)
  let tear = interpolate(n.frame, [tearFrom + 8, tearTo], [0, 1], .clamp)
  let openGently = interpolate(n.frame, [n.at(1), n.at(1, 0.8)], [0, 1], .clamp)
  let at = { (p: Pt) in place(BAG.x, BAG.y, BAG.scale, 0, p) }
  let holdL = at(DRIPBAG_PARTS.holdL)
  let holdR = at(DRIPBAG_PARTS.holdR)
  // 右手: 側面 → 帯をつまむ → 帯と一緒に右上へ → 側面に戻る
  let strip = at(Pt(DRIPBAG_PARTS.strip.x + tear * 140, DRIPBAG_PARTS.strip.y - tear * 120))
  let toStrip = interpolate(n.frame, [tearFrom - 4, tearFrom + 8], [0, 1], .clamp) * (1 - interpolate(n.frame, [tearTo + 2, tearTo + 14], [0, 1], .clamp))
  let handR = mix(holdR, strip, toStrip)
  let enter = { (to: Pt, from: Pt) in mix(from, to, hold) }

  Stage {
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.3)))
    CloseUp(steps: [
      CloseUpStep(label: n.t("open.step1", "Hold with both hands"), at: n.atPhrase(0, 0, -0.2)),
      CloseUpStep(label: n.t("open.step2", "Tear off the top strip"), at: n.atPhrase(0, 1, -0.2)),
      CloseUpStep(label: n.t("open.step3", "Check the opening"), at: n.at(1, -0.1)),
    ]) {
      g(transform: [.translate(0, -openGently * 6)]) {
        DripBag(x: BAG.x, y: BAG.y, scale: BAG.scale, open: tear)
      }
      SleeveArm(from: Pt(640, 760), to: enter(Pt(holdL.x - 10, holdL.y), Pt(600, 780)), bend: 0.2)
      SleeveArm(from: Pt(1600, 760), to: enter(Pt(handR.x + 10, handR.y), Pt(1640, 780)), bend: -0.2)
    }
  }
}
