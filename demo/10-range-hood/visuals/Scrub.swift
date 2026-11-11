// 油汚れを落とす (拡大): フィルターをシンクに置く → ぬるま湯で流す → スポンジに中性洗剤をつけてこする (泡) → 隙間は歯ブラシで
import JGVKit

private let BASE_L = Pt(760, 790)
private let BASE_R = Pt(1480, 790)
private let IDLE = Pt(1450, 700)

func Scrub(_ props: Props) {
  let n = useNarration()
  let fs = n.fps
  // 1 行目: 上からシンクへ
  let fpos = track(n.frame, fs, Pt(F.x, 120), [Move(at: n.at(0, 0.2), to: Pt(F.x, F.y), dur: 1.0)])
  let holdL = place(fpos.x, fpos.y, F.scale, 0, FILTER_PARTS.holdL)
  let holdR = place(fpos.x, fpos.y, F.scale, 0, FILTER_PARTS.holdR)
  let letGo = interpolate(n.frame, [n.endOf(0) - 8, n.endOf(0) + 8], [0, 1], .clamp)
  // 2 行目: ぬるま湯
  let water = n.frame >= n.atPhrase(1, 0, 0.2) && n.frame < n.at(2, -0.2)
  let rinse = interpolate(n.frame, [n.atPhrase(1, 1), n.endOf(1)], [0, 1], .clamp)
  let wet = interpolate(n.frame, [n.atPhrase(1, 0, 0.2), n.atPhrase(1, 0, 0.6)], [0, 1], .clamp)
  // 3 行目: 洗剤をスポンジに → こする
  let SP0 = Pt(1440, 520)
  let pourAt = n.atPhrase(2, 0, 0.3)
  let bottleIn = interpolate(n.frame, [n.at(2, -0.2), n.at(2, 0.3), n.atPhrase(2, 1, -0.2), n.atPhrase(2, 1, 0.2)], [0, 1, 1, 0], .clamp)
  let scrub = interpolate(n.frame, [n.atPhrase(2, 1), n.endOf(2)], [0, 1], .clamp)
  let scrubbing = scrub > 0 && scrub < 1
  let ang = (n.frame - n.atPhrase(2, 1)) * 0.35
  let sp = scrub > 0 ? Pt(990 + 320 * scrub + cos(ang) * 46, 560 + sin(ang) * 56) : mix(IDLE, SP0, n.ease(2, -0.1))
  let oil = (0..<3).map { i -> Double in
    let a = Double(i) / 3
    let b = Double(i + 1) / 3
    return (1 - 0.2 * rinse) * (1 - interpolate(scrub, [a, b], [0, 1], .clamp))
  }
  let foam = interpolate(n.frame, [n.atPhrase(2, 1), n.atPhrase(2, 1, 1)], [0, 1], .clamp)
  let spongeAway = n.ease(3, -0.1)
  // 4 行目: 歯ブラシで隙間
  let brushU = interpolate(n.frame, [n.atPhrase(3, 1, -0.2), n.endOf(3)], [0, 1], .clamp)
  let brushTip = Pt(1000 + 300 * brushU, 540 + sin(n.frame * 0.9) * 34)
  let BR_ANGLE = -55.0
  let rel = place(0, 0, 1.2, BR_ANGLE, TOOTHBRUSH_PARTS.head)
  let brushO = Pt(brushTip.x - rel.x, brushTip.y - rel.y)
  let brushGrip = place(brushO.x, brushO.y, 1.2, BR_ANGLE, TOOTHBRUSH_PARTS.grip)
  let gaps = 0.9 * (1 - brushU)
  // 右手 (下から)
  var hR = mix(holdR, IDLE, letGo)
  if n.frame >= n.at(2, -0.2) { hR = mix(hR, Pt(sp.x, sp.y - 24), n.ease(2, -0.2)) }
  if n.frame >= n.at(3, -0.2) { hR = mix(Pt(sp.x, sp.y - 24), brushGrip, n.ease(3, -0.2)) }
  let hL = mix(holdL, BASE_L, letGo)
  // 上から入る手 (洗剤ボトル)
  let BOT = (x: SP0.x, y: SP0.y - 300, scale: 0.8, angle: 170.0)
  let botY = BOT.y - (1 - bottleIn) * 260
  let nozzle = place(BOT.x, botY, BOT.scale, BOT.angle, DETERGENT_PARTS.nozzle)
  let botGrip = place(BOT.x, botY, BOT.scale, BOT.angle, DETERGENT_PARTS.grip)
  let dropK = jsMod((n.frame - pourAt) / (fs * 0.45), 1)

  Stage {
    Worker(handR: mix(LOW, POINT, n.ease(0, -0.3)), gloves: 1)
    CloseUp(steps: [
      CloseUpStep("シンクに置く", at: n.at(0, -0.2)),
      CloseUpStep("ぬるま湯で軽く流す", at: n.at(1, -0.2)),
      CloseUpStep("洗剤をつけて優しくこする", at: n.at(2, -0.2)),
      CloseUpStep("隙間は歯ブラシで", at: n.at(3, -0.2)),
    ]) {
      Sink(x: SINK.x, y: SINK.y)
      Faucet(x: TAP.x, y: TAP.y, side: .right, height: 110)
      HoodFilter(x: fpos.x, y: fpos.y, scale: F.scale, oil: Oil(oil), gaps: gaps, foam: foam, wet: wet, seed: "sf")
      Stream(from: Pt(TAP.x, TAP.y + 4), to: Pt(TAP.x + 6, F.y - 40), color: "#a9d8ea", width: 20, active: water)
      if water { Drips(x: F.x, y: F.y + 150, w: 360, fall: 60, color: rinse < 0.6 ? "#c9a05a" : "#8fcbe6", count: 9, seed: "sw") }
      if water {
        g(fill: "none", stroke: "#353b35", strokeWidth: 4, strokeLinecap: .round, opacity: 0.45) {
          for i in 0..<2 {
            let k = jsMod(n.sec * 0.6 + Double(i) / 2, 1)
            path("M \(TAP.x - 60 + Double(i) * 120) \(F.y - 70 - k * 60) q 10 -14 0 -28 q -10 -14 0 -28", opacity: sin(k * Double.pi))
          }
        }
      }
      // 洗剤
      if bottleIn > 0.01 {
        Detergent(x: BOT.x, y: botY, scale: BOT.scale, angle: BOT.angle)
        if n.frame >= pourAt && n.frame < n.atPhrase(2, 1, -0.2) {
          ellipse(cx: nozzle.x, cy: nozzle.y + 20 + dropK * (SP0.y - 60 - nozzle.y), rx: 9, ry: 13, fill: "#8cc7b0", stroke: "#353b35", strokeWidth: 3)
        }
        SleeveArm(from: Pt(1640, 240), to: botGrip, bend: -0.1)
        GloveHand(x: botGrip.x, y: botGrip.y)
      }
      // スポンジ
      if n.frame >= n.at(2, -0.2) {
        g(opacity: (1 - spongeAway) * n.ease(2, -0.2)) {
          Sponge(x: sp.x, y: sp.y + 36, scale: 0.9, angle: scrubbing ? sin(ang) * 8 : 0, foam: foam)
        }
      }
      // 歯ブラシ
      if n.frame >= n.at(3, -0.2) {
        g(opacity: n.ease(3, -0.2)) {
          ToothBrush(x: brushO.x, y: brushO.y, scale: 1.2, angle: BR_ANGLE)
        }
      }
      SleeveArm(from: BASE_L, to: hL, bend: 0.12)
      SleeveArm(from: BASE_R, to: hR, bend: -0.12)
      GloveHand(x: hL.x, y: hL.y)
      GloveHand(x: hR.x, y: hR.y)
      g(opacity: 1 - n.ease(2, -0.3)) {
        Callout(x: 1340, y: 360, text: "ぬるま湯で表面を軽く", at: n.atPhrase(1, 0, 0.3))
      }
      g(opacity: n.ease(3, 0.2)) {
        Callout(x: 860, y: 720, text: "柔らかい歯ブラシで", at: n.at(3, 0.2))
      }
    }
  }
}
