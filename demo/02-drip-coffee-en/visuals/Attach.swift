// Attach it to the mug (拡大): フックを広げる → マグの縁に掛ける → 安定を確認 → 手を離す
import JGVKit

private let MUGC = (x: 1120.0, y: 750.0, scale: 1.3)
private let SCALE = 1.3

func Attach(_ props: Props) {
  let n = useNarration()
  let spread = interpolate(n.frame, [n.atPhrase(0, 0, 0.1), n.atPhrase(0, 0, 0.9)], [0, 1], .clamp)
  let lower = interpolate(n.frame, [n.atPhrase(0, 1), n.endOf(0)], [0, 1], .clamp)
  let onRim = Pt(MUGC.x, MUGC.y - 175 * MUGC.scale + 92 * SCALE)
  let above = Pt(MUGC.x, onRim.y - 190)
  let bag = mix(above, onRim, 1 - pow(1 - lower, 2))
  // 2 行目: 少し揺らして確認 → 読み終わりで手を離す
  let wiggle = n.isSpeaking(1) && n.frame < n.at(1, 1.2) ? sin(n.frame * 0.9) * 3 : 0
  let letGo = interpolate(n.frame, [n.endOf(1) - 4, n.endOf(1) + 10], [0, 1], .clamp)
  let hookL = place(bag.x + wiggle, bag.y, SCALE, 0, DRIPBAG_PARTS.hookL)
  let hookR = place(bag.x + wiggle, bag.y, SCALE, 0, DRIPBAG_PARTS.hookR)
  let holdL = place(bag.x, bag.y, SCALE, 0, DRIPBAG_PARTS.holdL)
  let holdR = place(bag.x, bag.y, SCALE, 0, DRIPBAG_PARTS.holdR)
  let gg = n.ease(0, -0.3)
  let handL = mix(mix(Pt(600, 760), holdL, gg), hookL, spread)
  let handR = mix(mix(Pt(1640, 760), holdR, gg), hookR, spread)
  let away = { (h: Pt, dir: Double) in Pt(h.x + dir * 260 * letGo, h.y + 200 * letGo) }

  Stage {
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.3)))
    CloseUp(steps: [
      CloseUpStep(label: n.t("attach.step1", "Spread the hooks"), at: n.atPhrase(0, 0, -0.2)),
      CloseUpStep(label: n.t("attach.step2", "Lower onto the rim"), at: n.atPhrase(0, 1, -0.2)),
      CloseUpStep(label: n.t("attach.step3", "Check that it is secure"), at: n.at(1, -0.1)),
      CloseUpStep(label: n.t("attach.step4", "Let go of the bag"), at: n.endOf(1) - 4),
    ]) {
      Mug(x: MUGC.x, y: MUGC.y, scale: MUGC.scale)
      DripBag(x: bag.x + wiggle, y: bag.y, scale: SCALE, open: 1, hooks: spread)
      SleeveArm(from: Pt(600, 780), to: away(handL, -1), bend: 0.2)
      SleeveArm(from: Pt(1640, 780), to: away(handR, 1), bend: -0.2)
      CheckBadge(x: 1450, y: 360, at: n.endOf(1))
    }
  }
}
