// ケージの中のものを取り出す: トイレ → 食器 → おもちゃを外へ / 牧草と抜け毛を集めて左手のゴミ袋へ
import Foundation
import JGVKit

private func add(_ a: Pt, _ b: Pt, _ k: Double = 1) -> Pt { Pt(a.x + b.x * k, a.y + b.y * k) }
let PILE = Pt(CAGE.x - 20, CAGE.y - 58)
let BAG_GRIP = Pt(905, 500)

private struct Item {
  var key: String
  var grip: Pt
  var k: Double
}

func TakeOut(_ props: Props) {
  let n = useNarration()
  let fs = n.fps
  // 1 行目: 句ごとに 1 つずつ取り出す (前の動きが終わってから次へ)
  let items = [
    Item(key: "toilet", grip: TOILET_PARTS.grip, k: 1),
    Item(key: "bowl", grip: BOWL_PARTS.grip, k: 0.85),
    Item(key: "toy", grip: TOY_PARTS.grip, k: 1),
  ]
  var prevEnd = -Double.infinity
  var times: [Double] = []
  for i in items.indices {
    let t = max(n.atPhrase(0, i), prevEnd + fs * 0.45)
    prevEnd = t + fs * 0.8
    times.append(t)
  }
  let pos = items.enumerated().map { i, it in
    track(n.frame, fs, SLOT[it.key]!, [Move(at: times[i], to: OUT[it.key]!, dur: 0.8, lift: 150)])
  }
  let handMoves: [Move] = items.enumerated().flatMap { i, it in
    [
      Move(at: times[i] - fs * 0.4, to: add(SLOT[it.key]!, it.grip, it.k), dur: 0.4),
      Move(at: times[i], to: add(OUT[it.key]!, it.grip, it.k), dur: 0.8, lift: 150),
    ]
  }
  // 2 行目: 集める → ゴミ袋へ
  let g0 = n.atPhrase(1, 0, 0.2)
  let g1 = n.atPhrase(1, 1, -0.1)
  let gather = interpolate(n.frame, [g0, g1], [0, 1], .clamp)
  let sweepX = PILE.x + sin((n.frame - g0) / 5) * 200 * (1 - gather)
  let toss = n.atPhrase(1, 1, 0.3)
  let pile = track(n.frame, fs, PILE, [Move(at: toss, to: Pt(BAG_GRIP.x + 46, BAG_GRIP.y + 10), dur: 0.8, lift: 110)])
  let inBag = interpolate(n.frame, [toss + fs * 0.8, toss + fs * 1.1], [1, 0], .clamp)
  let bagIn = interpolate(n.frame, [n.atPhrase(1, 1, -0.6), n.atPhrase(1, 1, 0.1)], [0, 1], .clamp)
  let handL = mix(PRESENTER.restL, BAG_GRIP, bagIn * bagIn * (3 - 2 * bagIn))
  let bag = Pt(handL.x - TRASHBAG_PARTS.grip.x, handL.y - TRASHBAG_PARTS.grip.y)
  let afterItems = track(n.frame, fs, PRESENTER.gestureR, handMoves + [Move(at: prevEnd + fs * 0.1, to: PRESENTER.gestureR, dur: 0.5)])
  let sweeping = n.frame >= g0 - fs * 0.4
  let handR: Pt
  if n.frame < g0 - fs * 0.4 {
    handR = afterItems
  } else if n.frame < toss {
    handR = mix(PRESENTER.gestureR, Pt(sweepX + 30, PILE.y - 26), interpolate(n.frame, [g0 - fs * 0.4, g0], [0, 1], .clamp))
  } else if n.frame < toss + fs * 1.1 {
    handR = Pt(pile.x + 20, pile.y - 26)
  } else {
    handR = mix(Pt(BAG_GRIP.x + 66, BAG_GRIP.y - 16), PRESENTER.gestureR, interpolate(n.frame, [toss + fs * 1.1, toss + fs * 1.6], [0, 1], .clamp))
  }
  let started = times.map { n.frame >= $0 }
  Stage {
    Shadow(x: PEN.x, w: 290)
    PenBack(x: PEN.x, y: PEN.y)
    Rabbit(x: IN_PEN.x, y: IN_PEN.y, scale: RABBIT_SCALE, nibble: true)
    PenFront(x: PEN.x, y: PEN.y)
    Shadow(x: CAGE.x, w: 620)
    CageSet(door: 1, dirt: 1, inside: Inside(toilet: !started[0], bowl: !started[1], toy: !started[2])) {
      if n.frame < toss { Litter(x: CAGE.x, y: CAGE.y - 52, w: 520, gather: gather, to: PILE, seed: "in") }
    }
    if started[0] { Toilet(x: pos[0].x, y: pos[0].y, pellets: 0.7, soil: 1) }
    if started[1] { FoodBowl(x: pos[1].x, y: pos[1].y, scale: 0.85, food: 0.3) }
    if started[2] { Toy(x: pos[2].x, y: pos[2].y) }
    if n.frame >= times[0] + fs * 0.8 { Shadow(x: OUT.toilet.x, w: 160) }
    g(opacity: bagIn) {
      TrashBag(x: bag.x, y: bag.y, full: n.frame > toss + fs * 0.9 ? 0.25 : 0)
    }
    if n.frame >= toss {
      g(opacity: inBag) {
        Litter(x: CAGE.x, y: CAGE.y - 52, w: 520, gather: 1, to: pile, seed: "in")
      }
    }
    Presenter(handL: handL, handR: sweeping || n.frame >= g0 ? handR : afterItems)
  }
}
