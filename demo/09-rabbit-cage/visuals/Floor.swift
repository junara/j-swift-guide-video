// ケージの床を掃除する (拡大): 手で牧草と毛を集めて取る → 掃除シートで床・壁の汚れを順に拭く → 残った汚れをブラシでこする
import Foundation
import JGVKit

private struct Stain {
  var x: Double
  var y: Double
  var r: Double
}
private let STAINS = [
  Stain(x: 800, y: 660, r: 34),
  Stain(x: 1010, y: 690, r: 40),
  Stain(x: 1220, y: 650, r: 36),
  Stain(x: 1180, y: 470, r: 30),
  Stain(x: 880, y: 500, r: 28),
]
private let HARD = Stain(x: 1440, y: 680, r: 38)
private let IDLE = Pt(1520, 400)
private let BR = 1.4

func Floor(_ props: Props) {
  let n = useNarration()
  let fs = n.fps
  let t = n.sec
  // 1 行目: 牧草と毛を集めて取り除く
  let g0 = n.at(0, 0.3)
  let g1 = n.endOf(0) - fs * 0.2
  let sweep = interpolate(n.frame, [g0, g1], [0, 1], .clamp)
  let gatherHand = Pt(760 + 700 * sweep, 650 + sin(t * 9) * 8)
  let liftOut = interpolate(n.frame, [g1, g1 + fs * 0.6], [0, 1], .clamp)
  let litterTo = mix(gatherHand, IDLE, liftOut)
  // 2 行目: 掃除シートで汚れを順に拭く
  let w0 = n.atPhrase(1, 1)
  let w1 = n.endOf(1)
  let cnt = Double(STAINS.count)
  let seg = (w1 - w0) / cnt
  let wi = Int(min(cnt - 1, max(0, floor((n.frame - w0) / seg))))
  let wipeAt = { (i: Int) in w0 + seg * Double(i) + seg * 0.35 }
  let stainOp = { (i: Int) in 1 - interpolate(n.frame, [wipeAt(i), wipeAt(i) + seg * 0.6], [0, 1], .clamp) }
  let scrub = Pt(cos(t * 10) * 26, sin(t * 10) * 14)
  let goTo = interpolate(n.frame - (w0 + seg * Double(wi)), [0, seg * 0.35], [0, 1], .clamp)
  let prevS = wi == 0 ? Pt(760, 560) : Pt(STAINS[wi - 1].x, STAINS[wi - 1].y)
  let wipeHand = mix(prevS, Pt(STAINS[wi].x, STAINS[wi].y), goTo)
  let wiping = n.frame >= n.atPhrase(1, 0) && n.frame < w1 + fs * 0.3
  // 3 行目: 落ちにくい汚れはブラシで
  let b0 = n.at(2, 0.4)
  let brushing = n.frame >= n.at(2, -0.2)
  let hardOp = 1 - 0.35 * interpolate(n.frame, [w1 - seg, w1], [0, 1], .clamp) - 0.65 * interpolate(n.frame, [b0 + fs * 0.4, n.endOf(2)], [0, 1], .clamp)
  let brushPos = Pt(HARD.x + (n.frame > b0 && n.frame < n.endOf(2) ? sin(t * 22) * 34 : 0), HARD.y + 12)
  let brushReach = interpolate(n.frame, [n.at(2, -0.2), b0], [0, 1], .clamp)
  let brushGrip = place(brushPos.x, brushPos.y, BR, 0, BRUSH_PARTS.grip)
  var hand = IDLE
  if n.frame < n.at(1, -0.3) {
    hand = n.frame < g1 ? mix(IDLE, gatherHand, n.ease(0, 0)) : litterTo
  } else if !brushing {
    hand = n.frame < w0 ? mix(IDLE, Pt(760, 560), n.ease(1, 0)) : Pt(wipeHand.x + scrub.x, wipeHand.y + scrub.y)
  } else {
    hand = mix(Pt(STAINS[STAINS.count - 1].x, STAINS[STAINS.count - 1].y), brushGrip, brushReach)
  }
  let stainFill: Paint = "#a88a5c"
  Stage {
    Presenter(handR: mix(LOW, POINT, n.ease(0, -0.3)))
    CloseUp(steps: [
      CloseUpStep("牧草・毛を取り除く", at: n.at(0, -0.2)),
      CloseUpStep("掃除シートで床・壁を拭く", at: n.at(1, -0.2)),
      CloseUpStep("落ちにくい汚れはブラシで", at: n.at(2, -0.2)),
    ]) {
      // ケージの内側: 奥の金網と床
      rect(x: 640, y: 250, width: 960, height: 500, fill: "#f3eee2")
      for i in 0 ..< 17 {
        let lx = 680 + Double(i) * 56
        line(x1: lx, y1: 250, x2: lx, y2: 600, stroke: "#b7bcbc", strokeWidth: 6)
      }
      path("M 640 380 H 1600", stroke: "#b7bcbc", strokeWidth: 6)
      path("M 640 600 H 1600 L 1600 750 H 640 Z", fill: "#e7dbbd", stroke: "#353b35", strokeWidth: 5)
      for (i, s) in STAINS.enumerated() {
        ellipse(cx: s.x, cy: s.y, rx: s.r * (i < 3 ? 1.8 : 1.2), ry: s.r * (i < 3 ? 0.5 : 0.9), fill: stainFill, opacity: 0.55 * stainOp(i))
      }
      ellipse(cx: HARD.x, cy: HARD.y, rx: HARD.r * 1.8, ry: HARD.r * 0.6, fill: "#7a5d39", opacity: 0.75 * hardOp)
      Litter(x: 1110, y: 665, w: 760, gather: n.frame < g1 ? sweep : 1, to: litterTo, amount: 1 - liftOut * (n.frame > g1 + fs * 0.4 ? 1 : 0), count: 26, seed: "fl", scale: 1.8)
      Sparkles(x: 1110, y: 560, w: 760, h: 260, on: interpolate(n.frame, [w1 - seg, w1], [0, 1], .clamp) * (brushing ? 0.5 : 1), count: 6, seed: "fs")
      Sparkles(x: HARD.x, y: HARD.y - 20, w: 160, h: 80, on: interpolate(n.frame, [n.endOf(2) - fs * 0.3, n.endOf(2)], [0, 1], .clamp), count: 4, seed: "fh")
      Burst(at: n.endOf(2), x: HARD.x, y: HARD.y, r: 110, count: 10)
      if wiping { WipeSheet(x: hand.x, y: hand.y + 10, scale: 1.3, angle: -10, dirty: interpolate(n.frame, [w0, w1], [0, 1], .clamp)) }
      if brushing {
        g(opacity: brushReach) { Brush(x: brushPos.x, y: brushPos.y, scale: BR) }
      }
      SleeveArm(from: Pt(1640, 300), to: hand, bend: 0.12)
    }
  }
}
