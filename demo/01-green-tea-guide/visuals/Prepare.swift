// STEP 1: 道具が句ごとに並び、2 行目でやかんを持ち上げて湯のみ 2 つにお湯を注ぐ
import JGVKit

private let Y = GUIDE.counterY
private let CUPS: [Double] = [1150, 1300]

func Prepare(_ props: Props) {
  let n = useNarration()
  let drop = { (at: Double) in spring(frame: n.frame - at, fps: n.fps, damping: 13, stiffness: 140) }
  // 句ごとに道具が置かれる: 急須と湯のみ → 茶葉
  let potIn = drop(n.atPhrase(0, 0, -0.2))
  let cupIn = drop(n.atPhrase(0, 0, 0.3))
  let canIn = drop(n.atPhrase(0, 1, -0.1))
  let kettleIn = drop(n.at(1, -0.4))

  // 2 行目: 持ち上げ → 湯のみ 1 → 湯のみ 2 → 戻す
  let t0 = n.atPhrase(1, 0)
  let t1 = n.atPhrase(1, 1)
  let tEnd = n.endOf(1)
  let lift = interpolate(n.frame, [t0, t0 + 14], [0, 1], .clamp)
  let back = interpolate(n.frame, [tEnd + 4, tEnd + 18], [0, 1], .clamp)
  let toCup2 = interpolate(n.frame, [t1 + (tEnd - t1) * 0.45, t1 + (tEnd - t1) * 0.55], [0, 1], .clamp)
  let tilt = 34 * interpolate(n.frame, [t1 - 6, t1 + 4], [0, 1], .clamp) * (1 - back)
  let rest = Pt(1500, Y)
  let pourAt = Pt(interpolate(toCup2, [0, 1], [CUPS[0] - 190, CUPS[1] - 190]), 610)
  let pos = mix(rest, pourAt, lift * (1 - back))
  let scale = 0.85
  let handle = place(pos.x, pos.y, scale, tilt, KETTLE_PARTS.handle)
  let spout = place(pos.x, pos.y, scale, tilt, KETTLE_PARTS.spout)
  let pouring = tilt > 25
  let cupFill = [
    interpolate(n.frame, [t1 + 4, t1 + (tEnd - t1) * 0.45], [0, 0.75], .clamp),
    interpolate(n.frame, [t1 + (tEnd - t1) * 0.55, tEnd], [0, 0.75], .clamp),
  ]
  let target = CUPS[toCup2 < 0.5 ? 0 : 1]

  // 右手: 1 行目は道具を指し示し、2 行目はやかんの取っ手へ
  let reach = interpolate(n.frame, [t0 - 10, t0], [0, 1], .clamp) * (1 - interpolate(n.frame, [tEnd + 18, tEnd + 30], [0, 1], .clamp))
  let gesture = mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.2))
  let handR = mix(gesture, handle, reach)

  Stage {
    Shadow(x: 760, w: 150 * canIn)
    Canister(x: 760, y: Y - (1 - canIn) * 300, scale: 0.9)
    Shadow(x: 960, w: 230 * potIn)
    Teapot(x: 960, y: Y - (1 - potIn) * 300, scale: 0.95)
    for (i, cx) in CUPS.enumerated() {
      Shadow(x: cx, w: 140 * cupIn)
      Yunomi(x: cx, y: Y - (1 - cupIn) * 300, scale: 0.9, fill: cupFill[i])
      if cupFill[i] > 0.6 { Steam(x: cx, y: Y - 130, count: 2, height: 110) }
    }
    Stream(from: spout, to: Pt(target, Y - 105), active: pouring && n.frame < tEnd)
    Shadow(x: rest.x, w: 220 * kettleIn * (1 - lift * (1 - back) * 0.6))
    g(opacity: kettleIn) {
      Kettle(x: pos.x, y: pos.y - (1 - kettleIn) * 300, scale: scale, angle: tilt)
    }
    Presenter(handR: handR)
    Callout(x: 1225, y: Y - 250, text: "お湯は約80℃まで冷ます", at: n.atPhrase(1, 1, 0.6))
  }
}
