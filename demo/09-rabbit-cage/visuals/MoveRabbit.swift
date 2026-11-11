// うさぎを安全な場所に移動する: 扉を開ける → 両手で抱えてサークルへ → 逃走・誤飲に注意
import Foundation
import JGVKit

func MoveRabbit(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  // 1 行目: 扉をゆっくり開ける
  let reach = n.ease(0, -0.2)
  let door = interpolate(n.frame, [n.at(0, 0.5), n.endOf(0)], [0, 1], .clamp)
  let latch = cage(Pt(doorEdgeX(door), CAGE_PARTS.latch.y))
  // 2 行目: 抱えてサークルへ
  let lift = n.at(1, 0.4)
  let span = max(n.fps * 1.6, n.endOf(1) - lift)
  let moves = [
    Move(at: lift, to: Pt(SLOT.rabbit.x, SLOT.rabbit.y - 120), dur: 0.5),
    Move(at: lift + n.fps * 0.5, to: Pt(IN_PEN.x, IN_PEN.y - 140), dur: (span / n.fps) - 0.9, lift: 120),
    Move(at: lift + span - n.fps * 0.4, to: IN_PEN, dur: 0.4),
  ]
  let r = track(n.frame, n.fps, SLOT.rabbit, moves)
  let carrying = moving(n.frame, n.fps, moves)
  let placed = n.frame >= lift + span
  let grabIn = interpolate(n.frame, [lift - n.fps * 0.5, lift], [0, 1], .clamp)
  let letGo = interpolate(n.frame, [lift + span, lift + span + n.fps * 0.5], [0, 1], .clamp)
  let hands = grabIn * (1 - letGo)
  let base = mix(mix(PRESENTER.restR, latch, reach), PRESENTER.gestureR, letGo)
  let handR = mix(base, holdR(r), hands)
  let handL = mix(PRESENTER.restL, holdL(r), hands)
  let penIn = n.ease(1, -0.1)
  let warn = n.at(2, 0.1)
  Stage {
    g(opacity: penIn, transform: [.translate(0, (1 - penIn) * 30)]) {
      Shadow(x: PEN.x, w: 290)
      PenBack(x: PEN.x, y: PEN.y)
      if placed { Rabbit(x: r.x, y: r.y, scale: RABBIT_SCALE, nibble: n.frame > warn) }
      PenFront(x: PEN.x, y: PEN.y)
    }
    Shadow(x: CAGE.x, w: 620)
    CageSet(door: door, dirt: 1, rabbit: n.frame < lift)
    if carrying { Rabbit(x: r.x, y: r.y, scale: RABBIT_SCALE, held: 1) }
    Hearts(x: IN_PEN.x - 40, y: IN_PEN.y - 170, on: placed && n.frame < warn ? 1 : 0)
    Presenter(handL: handL, handR: handR)
    Pop(at: warn, x: PEN.x, y: PEN.y - 300) {
      rect(x: -190, y: -40, width: 380, height: 80, rx: 40, fill: "#fff", stroke: "#d14b3b", strokeWidth: 4)
      Icon(name: "warning", x: -140, y: 0, size: 46, color: "#d14b3b")
      T("逃走・誤飲に注意", x: 24, y: 0, size: 30, weight: 900, color: palette.ink)
    }
    Callout(x: CAGE.x, y: CAGE.y - 470, text: "扉はゆっくり開ける", at: n.at(0, 0.3))
  }
}
