// 工程の visual でよく使う動きの計算 (フレームから値を出す純粋な関数)。
// at はシーン先頭からのフレーム (n.at() / n.atPhrase() の戻り値をそのまま渡す)
import Foundation

/// at から始まるなめらかな 0→1 (行や句に結びつかない任意のフレームから始めたいときの n.ease)
public func easeAt(_ frame: Double, _ fps: Double, _ at: Double) -> Double {
  spring(frame: frame - at, fps: fps, damping: 200)
}

/// at から始まる「上から落ちて弾んで止まる」0→1 (1 を超えないので、置いた物がカウンターにめり込まない)
public func dropAt(_ frame: Double, _ fps: Double, _ at: Double) -> Double {
  min(1, spring(frame: frame - at, fps: fps, damping: 14, stiffness: 140))
}

private func easeInOutCubic(_ u: Double) -> Double { u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2 }

/// track の 1 つの移動: at は動き始めのフレーム、dur は秒 (既定 0.6)、lift は弧の高さ (px)
public struct Move {
  public var at: Double
  public var to: Pt
  public var dur: Double
  public var lift: Double
  public init(at: Double, to: Pt, dur: Double = 0.6, lift: Double = 0) {
    self.at = at; self.to = to; self.dur = dur; self.lift = lift
  }
}

/// start から moves を順に移動した現在位置 (手や道具を「取りに行く → 運ぶ → 戻す」と順に動かす)
public func track(_ frame: Double, _ fps: Double, _ start: Pt, _ moves: [Move]) -> Pt {
  var cur = start
  for m in moves {
    let u = min(1, max(0, (frame - m.at) / (m.dur * fps)))
    if u <= 0 { break }
    let e = easeInOutCubic(u)
    let p = Pt(cur.x + (m.to.x - cur.x) * e, cur.y + (m.to.y - cur.y) * e - sin(Double.pi * e) * m.lift)
    if u < 1 { return p }
    cur = m.to
  }
  return cur
}

/// 拭く・こする手の動き: 範囲 (x0〜x1, y0〜y1) を u (0〜1) で passes 回ジグザグに往復する
public func zigzag(_ u: Double, _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ passes: Int = 3) -> Pt {
  let pc = Double(passes)
  let k = min(1, max(0, u)) * pc
  let row = min(pc - 1, k.rounded(.down))
  let s = k - row
  let dir: Double = Int(row) % 2 == 0 ? 1 : -1
  let x = dir > 0 ? x0 + (x1 - x0) * s : x1 - (x1 - x0) * s
  let y = y0 + ((y1 - y0) * (row + s * 0.5)) / max(1, pc - 0.5)
  return Pt(x, y)
}

/// 秒数を "m:ss" にする (タイマー・電子レンジの表示窓など)
public func clock(_ sec: Double) -> String {
  // 有限でない値・大きすぎる値で Int() が落ちないように (100 時間未満)
  let s = sec.isFinite ? max(0, Int(min(sec, 359_999).rounded(.up))) : 0
  return "\(s / 60):\(String(format: "%02d", s % 60))"
}
