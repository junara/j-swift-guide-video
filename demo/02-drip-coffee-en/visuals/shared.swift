// このデモの全シーンで共通の配置と、やかんで注ぐ動き
import JGVKit

let Y = GUIDE.counterY
let MUG = Pt(1050, Y)
let KETTLE_REST = Pt(1420, Y)
let KETTLE_SCALE = 0.85
/// マグに掛けたバッグの原点 (マグの縁の少し下)
let BAG_ON_MUG = Pt(MUG.x, Y - 175 + 92)
let BAG_SCALE = 0.8

struct KettlePour {
  var pos: Pt
  var tilt: Double
  var handle: Pt
  var spout: Pt
  var pouring: Bool
  /// 手をやかんに伸ばしている度合い (0〜1)
  var reach: Double
}

/**
 * やかんで注ぐ。frame が [from, to] の間に 持ち上げ → 傾けて注ぐ → 戻す。
 * 注ぎ口がバッグの上 (target) に来るよう原点を逆算する。
 */
func kettlePour(_ frame: Double, _ from: Double, _ to: Double, _ target: Pt, _ angle: Double = 34) -> KettlePour {
  let lift = interpolate(frame, [from, from + 12], [0, 1], .clamp)
  let back = interpolate(frame, [to - 12, to], [0, 1], .clamp)
  let tilt = angle * interpolate(frame, [from + 8, from + 16, to - 16, to - 8], [0, 1, 1, 0], .clamp)
  let rel = place(0, 0, KETTLE_SCALE, angle, KETTLE_PARTS.spout)
  let pourPos = Pt(target.x - rel.x, target.y - rel.y)
  let pos = mix(KETTLE_REST, pourPos, lift * (1 - back))
  return KettlePour(
    pos: pos,
    tilt: tilt,
    handle: place(pos.x, pos.y, KETTLE_SCALE, tilt, KETTLE_PARTS.handle),
    spout: place(pos.x, pos.y, KETTLE_SCALE, tilt, KETTLE_PARTS.spout),
    pouring: tilt > angle * 0.8,
    reach: interpolate(frame, [from - 10, from, to, to + 10], [0, 1, 1, 0], .clamp)
  )
}
