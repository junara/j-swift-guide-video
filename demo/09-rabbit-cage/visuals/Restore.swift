// ケージの中を元に戻す: トイレ → 食器 → おもちゃを中へ / 牧草を補充し、給水ボトルに水 / 床に触れて乾燥を確認
import Foundation
import JGVKit

private func add(_ a: Pt, _ b: Pt, _ k: Double = 1) -> Pt { Pt(a.x + b.x * k, a.y + b.y * k) }

private struct Item {
  var key: String
  var grip: Pt
  var k: Double
}

func Restore(_ props: Props) {
  let n = useNarration()
  let fs = n.fps
  // 1 行目: 1 つずつ戻す
  let items = [
    Item(key: "toilet", grip: TOILET_PARTS.grip, k: 1),
    Item(key: "bowl", grip: BOWL_PARTS.grip, k: 0.85),
    Item(key: "toy", grip: TOY_PARTS.grip, k: 1),
  ]
  let step = max(fs * 1.15, (n.endOf(0) - n.at(0, 0.3)) / 3)
  let times = items.indices.map { n.at(0, 0.3) + step * Double($0) }
  let pos = items.enumerated().map { i, it in
    track(n.frame, fs, OUT[it.key]!, [Move(at: times[i], to: SLOT[it.key]!, dur: 0.8, lift: 150)])
  }
  let done = times.map { n.frame >= $0 + fs * 0.8 }
  let itemHand: [Move] = items.enumerated().flatMap { i, it in
    [
      Move(at: times[i] - fs * 0.35, to: add(OUT[it.key]!, it.grip, it.k), dur: 0.35),
      Move(at: times[i], to: add(SLOT[it.key]!, it.grip, it.k), dur: 0.8, lift: 150),
    ]
  }
  // 2 行目: 牧草と水
  let rack = cage(CAGE_PARTS.hay)
  let bottle = cage(CAGE_PARTS.bottle)
  let hayT = n.atPhrase(1, 0, 0.2)
  let hay = interpolate(n.frame, [hayT + fs * 0.4, hayT + fs * 1.2], [0.15, 1], .clamp)
  let waterT = n.atPhrase(1, 1, 0.1)
  let water = interpolate(n.frame, [waterT, waterT + fs * 1.4], [0.2, 0.95], .clamp)
  // 3 行目: 床に触れて乾いているか確認
  let touch = Pt(CAGE.x + 40, CAGE.y - 66)
  let checkAt = n.at(2, 1.4)
  let hand = track(n.frame, fs, PRESENTER.gestureR, itemHand + [
    Move(at: times[2] + fs * 0.85, to: PRESENTER.gestureR, dur: 0.4),
    Move(at: hayT - fs * 0.3, to: Pt(rack.x + 20, rack.y - 10), dur: 0.5),
    Move(at: waterT - fs * 0.2, to: Pt(bottle.x - 50, bottle.y + 40), dur: 0.5),
    Move(at: n.at(2, -0.1), to: touch, dur: 0.6),
    Move(at: n.at(2, 0.8), to: Pt(touch.x + 80, touch.y - 2), dur: 0.5),
    Move(at: checkAt, to: PRESENTER.gestureR, dur: 0.5),
  ])
  let carryingHay = n.frame >= hayT - fs * 0.3 && n.frame < hayT + fs * 0.6
  Stage {
    Shadow(x: PEN.x, w: 290)
    PenBack(x: PEN.x, y: PEN.y)
    Rabbit(x: IN_PEN.x, y: IN_PEN.y, scale: RABBIT_SCALE, nibble: true)
    PenFront(x: PEN.x, y: PEN.y)
    Shadow(x: CAGE.x, w: 620)
    CageSet(door: 1, hay: hay, fresh: true, water: water, inside: Inside(toilet: done[0], bowl: done[1], toy: done[2]), clean: true)
    if !done[0] { Shadow(x: pos[0].x, w: 160) }
    if !done[0] { Toilet(x: pos[0].x, y: pos[0].y) }
    if !done[1] { FoodBowl(x: pos[1].x, y: pos[1].y, scale: 0.85, food: 1) }
    if !done[2] { Toy(x: pos[2].x, y: pos[2].y) }
    if carryingHay {
      g(transform: [.translate(hand.x, hand.y + 10)]) {
        for (i, dx) in [-30.0, -14, 0, 14, 30].enumerated() {
          let odd = Double(i % 2)
          line(x1: dx - 10, y1: -10 + odd * 8, x2: dx + 14, y2: 18 - odd * 6, stroke: "#a8c25c", strokeWidth: 6, strokeLinecap: .round)
        }
      }
    }
    Sparkles(x: rack.x, y: rack.y, w: 120, h: 80, on: interpolate(n.frame, [hayT + fs * 1.2, hayT + fs * 1.5], [0, 1], .clamp) * (1 - n.ease(1, 1.6)), count: 3, seed: "hy")
    Sparkles(x: bottle.x, y: bottle.y + 40, w: 70, h: 140, on: interpolate(n.frame, [waterT + fs * 1.3, waterT + fs * 1.6], [0, 1], .clamp) * (1 - n.ease(2, 0)), count: 3, seed: "wt")
    Presenter(handR: hand)
    Callout(x: CAGE.x, y: CAGE.y - 470, text: "床や備品はよく乾かす", at: n.at(2, 0.2))
    CheckBadge(x: CAGE.x + 240, y: CAGE.y - 330, at: checkAt)
  }
}
