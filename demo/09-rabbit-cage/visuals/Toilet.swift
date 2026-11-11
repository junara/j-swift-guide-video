// トイレを掃除する (拡大): 傾けて排泄物をゴミ袋へ → 汚れたシーツを抜く → 水で洗う → タオルで拭いて新しいシーツを敷く
import Foundation
import JGVKit

private let S = 2.2
private let T0 = Pt(1010, 690)
private let BAG = (x: 1440.0, y: 735.0, scale: 1.25)
private let MOUTH = place(BAG.x, BAG.y, BAG.scale, 0, TRASHBAG_PARTS.mouth)
private let TAP = Pt(1010, 330)
private let NEW_SHEET = Pt(760, 650)
private let TILT = 38.0
private let lipRel = place(0, 0, S, TILT, TOILET_PARTS.lip)
private let T1 = Pt(MOUTH.x - 30 - lipRel.x, MOUTH.y - 50 - lipRel.y)
private let IDLE = Pt(1520, 430)

func Toilet(_ props: Props) {
  let n = useNarration()
  let fs = n.fps
  let palette = useGuide().palette
  // 1 行目: 傾けて排泄物を捨てる
  let a0 = n.at(0, 0.3)
  let tilt = interpolate(n.frame, [a0, a0 + fs * 0.8, n.endOf(0), n.endOf(0) + fs * 0.6], [0, 1, 1, 0], .clamp)
  let box = mix(T0, T1, tilt)
  let angle = TILT * tilt
  let pour = interpolate(n.frame, [a0 + fs * 0.8, n.endOf(0)], [0, 1], .clamp)
  let lip = place(box.x, box.y, S, angle, TOILET_PARTS.lip)
  // 2 行目: 汚れたシーツを抜いてゴミ袋へ
  let s0 = n.at(1, 0.3)
  let oldSheet = track(n.frame, fs, place(T0.x, T0.y, S, 0, TOILET_PARTS.top), [Move(at: s0, to: Pt(MOUTH.x, MOUTH.y - 30), dur: 1.0, lift: 140)])
  let sheetGone = interpolate(n.frame, [s0 + fs * 1.0, s0 + fs * 1.25], [1, 0], .clamp)
  let newIn = n.ease(1, 1.2)
  // 3 行目: 水洗い → タオル → 新しいシーツ
  let w0 = n.atPhrase(2, 0, 0.3)
  let w1 = n.atPhrase(2, 1)
  let water = n.frame >= w0 && n.frame < w1 - fs * 0.2
  let tapIn = interpolate(n.frame, [w0 - fs * 0.5, w0, w1 - fs * 0.2, w1 + fs * 0.2], [0, 1, 1, 0], .clamp)
  let grime = 1 - interpolate(n.frame, [w0 + fs * 0.3, w1 - fs * 0.3], [0, 1], .clamp)
  let wet = interpolate(n.frame, [w0, w0 + fs * 0.3], [0, 1], .clamp) * (1 - interpolate(n.frame, [w1 + fs * 0.4, n.endOf(2)], [0, 1], .clamp))
  let towel = n.frame >= w1 - fs * 0.1 && n.frame < n.endOf(2) + fs * 0.1
  let towelP = Pt(T0.x + sin((n.frame - w1) / 6) * 110, T0.y - 80 + cos((n.frame - w1) / 3) * 10)
  let e0 = n.endOf(2) + fs * 0.2
  let newSheet = track(n.frame, fs, NEW_SHEET, [Move(at: e0, to: place(T0.x, T0.y, S, 0, TOILET_PARTS.top), dur: 0.7, lift: 120)])
  let sheetDone = n.frame >= e0 + fs * 0.7
  // 右手
  let grip = place(box.x, box.y, S, angle, TOILET_PARTS.grip)
  var hand = IDLE
  if n.frame < s0 - fs * 0.4 {
    hand = mix(IDLE, grip, n.ease(0, -0.1))
  } else if n.frame < s0 + fs * 1.0 {
    hand = mix(grip, Pt(oldSheet.x + 70, oldSheet.y - 10), interpolate(n.frame, [s0 - fs * 0.4, s0], [0, 1], .clamp))
  } else if n.frame < w0 - fs * 0.5 {
    hand = mix(Pt(MOUTH.x + 70, MOUTH.y - 40), grip, interpolate(n.frame, [s0 + fs * 1.0, s0 + fs * 1.6], [0, 1], .clamp))
  } else if n.frame < w1 - fs * 0.1 {
    hand = grip
  } else if towel {
    hand = mix(grip, towelP, interpolate(n.frame, [w1 - fs * 0.1, w1 + fs * 0.2], [0, 1], .clamp))
  } else {
    let held = Pt(newSheet.x + 70, newSheet.y - 10)
    hand = n.frame < e0 + fs * 0.7 ? held : mix(held, IDLE, interpolate(n.frame, [e0 + fs * 0.7, e0 + fs * 1.2], [0, 1], .clamp))
  }
  let bagFull: Double = n.frame > s0 + fs * 1.1 ? 0.45 : pour > 0.5 ? 0.25 : 0
  Stage {
    Presenter(handR: mix(LOW, POINT, n.ease(0, -0.3)))
    CloseUp(steps: [
      CloseUpStep("排泄物を捨てる", at: n.at(0, -0.2)),
      CloseUpStep("汚れたシーツ・砂を交換", at: n.at(1, -0.2)),
      CloseUpStep("容器を水で洗う", at: n.atPhrase(2, 0, -0.2)),
      CloseUpStep("タオルで水気を拭く", at: n.atPhrase(2, 1, -0.2)),
    ]) {
      g(opacity: tapIn) {
        Faucet(x: TAP.x, y: TAP.y)
      }
      TrashBag(x: BAG.x, y: BAG.y, scale: BAG.scale, full: bagFull)
      g(opacity: newIn * (sheetDone ? 0 : 1)) {
        PetSheet(x: newSheet.x, y: newSheet.y, scale: 1.2)
        if n.frame < e0 {
          T("新しいシーツ", x: NEW_SHEET.x, y: NEW_SHEET.y + 52, size: 24, weight: 800, color: palette.primary)
        }
      }
      Toilet(
        x: box.x,
        y: box.y,
        scale: S,
        angle: angle,
        pellets: 1 - pour,
        soil: sheetDone ? 0 : 1,
        sheet: sheetDone ? 1 : n.frame < s0 ? 1 : 0,
        grime: grime,
        wet: wet,
        grate: n.frame < s0 || sheetDone
      )
      // こぼれ落ちる排泄物
      if pour > 0 && pour < 1 {
        for i in 0 ..< 9 {
          let k = jsMod(pour * 3 + random("pp\(i)"), 1)
          circle(cx: lip.x + (MOUTH.x - lip.x) * k + (random("px\(i)") - 0.5) * 30, cy: lip.y + (MOUTH.y - lip.y) * k * k, r: 12,
                 fill: "#6b4e33", stroke: "#353b35", strokeWidth: 3, opacity: k < 0.95 ? 1 : 0)
        }
      }
      if n.frame >= s0 {
        g(opacity: sheetGone) {
          PetSheet(x: oldSheet.x, y: oldSheet.y, scale: 1.6, angle: interpolate(n.frame, [s0, s0 + fs], [0, 25], .clamp), soil: 1)
        }
      }
      Stream(from: Pt(TAP.x, TAP.y + 4), to: Pt(TAP.x, T0.y - 150), color: "#8fcbe6", width: 22, active: water)
      if water { Drips(x: T0.x, y: T0.y - 10, w: 300, fall: 60, color: grime > 0.4 ? "#b39b74" : "#8fcbe6", count: 8, seed: "tw") }
      if towel { TowelCloth(x: hand.x, y: hand.y, scale: 1.3, angle: -8) }
      SleeveArm(from: Pt(1640, 300), to: hand, bend: 0.12)
      CheckBadge(x: T0.x + 230, y: T0.y - 260, at: e0 + fs * 0.7)
    }
  }
}
