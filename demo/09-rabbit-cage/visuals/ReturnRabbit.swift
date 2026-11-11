// うさぎをケージに戻す: サークルから抱えてケージへ → 落ち着いているのを確認 → 扉を閉めてカチッ → 完了
import Foundation
import JGVKit

func ReturnRabbit(_ props: Props) {
  let n = useNarration()
  let fs = n.fps
  // 1 行目: ゆっくり戻す
  let lift = n.at(0, 0.4)
  let span = max(fs * 1.8, n.endOf(0) - lift)
  let moves = [
    Move(at: lift, to: Pt(IN_PEN.x, IN_PEN.y - 130), dur: 0.5),
    Move(at: lift + fs * 0.5, to: Pt(SLOT.rabbit.x, SLOT.rabbit.y - 120), dur: span / fs - 0.9, lift: 120),
    Move(at: lift + span - fs * 0.4, to: SLOT.rabbit, dur: 0.4),
  ]
  let r = track(n.frame, fs, IN_PEN, moves)
  let carrying = moving(n.frame, fs, moves)
  let placed = n.frame >= lift + span
  let grabIn = interpolate(n.frame, [lift - fs * 0.5, lift], [0, 1], .clamp)
  let letGo = interpolate(n.frame, [lift + span, lift + span + fs * 0.5], [0, 1], .clamp)
  let hands = grabIn * (1 - letGo)
  // 2 行目: 落ち着いたら扉を閉める
  let c0 = n.atPhrase(1, 1, 0.2)
  let door = 1 - interpolate(n.frame, [c0 + fs * 0.3, c0 + fs * 1.1], [0, 1], .clamp)
  let latch = cage(Pt(doorEdgeX(door), CAGE_PARTS.latch.y))
  let toDoor = interpolate(n.frame, [c0 - fs * 0.3, c0 + fs * 0.3], [0, 1], .clamp)
  let away = interpolate(n.frame, [c0 + fs * 1.4, c0 + fs * 1.9], [0, 1], .clamp)
  let baseR = mix(mix(PRESENTER.gestureR, latch, toDoor), PRESENTER.gestureR, away)
  let handR = mix(mix(PRESENTER.restR, baseR, n.frame >= lift ? 1 : n.ease(0, -0.2)), holdR(r), hands)
  let handL = mix(PRESENTER.restL, holdL(r), hands)
  let calm = n.frame >= n.atPhrase(1, 0) && n.frame < c0 + fs * 0.3
  let fin = n.at(2, 0.2)
  Stage {
    Shadow(x: PEN.x, w: 290)
    PenBack(x: PEN.x, y: PEN.y)
    if n.frame < lift { Rabbit(x: IN_PEN.x, y: IN_PEN.y, scale: RABBIT_SCALE, nibble: true) }
    PenFront(x: PEN.x, y: PEN.y)
    Shadow(x: CAGE.x, w: 620)
    CageSet(door: door, hay: 1, fresh: true, water: 0.95, clean: true, rabbit: placed, nibble: true)
    if carrying { Rabbit(x: r.x, y: r.y, scale: RABBIT_SCALE, held: 1) }
    Hearts(x: SLOT.rabbit.x - 40, y: SLOT.rabbit.y - 180, on: calm ? 1 : 0)
    Burst(at: c0 + fs * 1.1, x: latch.x, y: latch.y, r: 70, count: 10)
    Sparkles(x: CAGE.x, y: CAGE.y - 200, w: 580, h: 320, on: n.ease(2, 0.2), count: 8, seed: "fin")
    Presenter(handL: handL, handR: handR)
    Callout(x: CAGE.x, y: CAGE.y - 470, text: "扉をしっかり閉める", at: c0)
    CheckBadge(x: CAGE.x + 240, y: CAGE.y - 330, at: fin, r: 52)
  }
}
