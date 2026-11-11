// STEP 2: 拡大カードで、スプーンが茶筒から茶葉をすくって急須へ 2 杯入れる
import JGVKit

func AddLeaves(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let can = Pt(840, 700)
  let pot = Pt(1240, 715)
  let scoop = Pt(840, 470)
  let dump = Pt(1230, 470)
  // 1 行目の間に 2 往復 (すくう → 運ぶ → 傾ける → 戻る)
  let start = n.atPhrase(0, 0, 0.2)
  let end = n.endOf(0)
  let cycle = (end - start) / 2
  let k = min(1.999, max(0, (n.frame - start) / cycle))
  let phase = jsMod(k, 1)
  let done = n.frame >= end
  let carry = done ? 0 : interpolate(phase, [0.15, 0.45, 0.75, 0.95], [0, 1, 1, 0], .clamp)
  // 入れ終わったらスプーンはカードの外へ下げる
  let away = interpolate(n.frame, [end, end + 15], [0, 1], .clamp)
  let pos = mix(mix(scoop, dump, carry), Pt(1760, 720), away)
  let arc = sin(carry * Double.pi) * -90
  let tilt = done ? 0 : interpolate(phase, [0.45, 0.6, 0.72], [0, -70, 0], .clamp)
  let spoonPos = Pt(pos.x, pos.y + arc)
  let grip = place(spoonPos.x, spoonPos.y, 1.2, tilt, SPOON_PARTS.grip)
  let full = !done && n.frame >= start && phase > 0.1 && phase < 0.55
  let falling = !done && phase > 0.52 && phase < 0.75
  let leavesInPot = min(2, Int(((n.frame - start) / cycle + 0.4).rounded(.down)))

  Stage {
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.3)))
    CloseUp(steps: [
      CloseUpStep("茶葉をすくう", at: n.atPhrase(0, 0, -0.2)),
      CloseUpStep("急須に入れる", at: n.atPhrase(0, 1, -0.2)),
      CloseUpStep("2人分で約6g", at: n.at(1, -0.1)),
    ]) {
      Canister(x: can.x, y: can.y, scale: 1.25, lidOpen: n.ease(0, -0.3))
      Teapot(x: pot.x, y: pot.y, scale: 1.25, lidOpen: 1)
      if leavesInPot > 0 { Grains(x: pot.x, y: pot.y - 160, spread: 44, count: 8 * leavesInPot, seed: "pot") }
      if falling {
        Grains(x: dump.x - 40, y: interpolate(phase, [0.52, 0.75], [dump.y + 10, pot.y - 160], .clamp), spread: 30, count: 10, seed: "f\(Int(k.rounded(.down)))")
      }
      Spoon(x: spoonPos.x, y: spoonPos.y, scale: 1.2, angle: tilt, leaves: full)
      SleeveArm(from: Pt(1640, 760), to: grip, bend: -0.2)
      if n.frame >= n.at(1) {
        Pulse(x: 1040, y: 400, r: 70, color: palette.primary)
        CountUp(at: n.at(1), to: 6, prefix: "約", suffix: "g", x: 1040, y: 400, size: 84, weight: 900, color: palette.primary)
        T("2人分", x: 1040, y: 480, size: 38, weight: 800, color: palette.ink, opacity: n.ease(1, 0.2))
      }
    }
  }
}
