// フレームから値を出す計算 (interpolate / spring / random / Easing)
import Foundation

/// 画面座標の点
public struct Pt: Equatable, Hashable, Sendable, CustomStringConvertible {
  public var x: Double
  public var y: Double
  public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
  public init(x: Double, y: Double) { self.x = x; self.y = y }
  public var description: String { "(\(x), \(y))" }
}

public enum Extrapolate: Sendable { case extend, clamp, identity, wrap }

public typealias EasingFn = (Double) -> Double

/// interpolate の範囲外の扱い (clamp は範囲の端の値で止める。既定の extend は延長する)
public struct InterpolateOptions {
  public var left: Extrapolate
  public var right: Extrapolate
  public var easing: EasingFn
  public init(left: Extrapolate = .extend, right: Extrapolate = .extend, easing: @escaping EasingFn = { $0 }) {
    self.left = left; self.right = right; self.easing = easing
  }
  /// 両端で止める ({ extrapolateLeft: "clamp", extrapolateRight: "clamp" })
  public static let clamp = InterpolateOptions(left: .clamp, right: .clamp)
  public static func clamp(easing: @escaping EasingFn) -> InterpolateOptions { InterpolateOptions(left: .clamp, right: .clamp, easing: easing) }
}

/// 入力の範囲 input を出力の範囲 output に対応づける
public func interpolate(_ value: Double, _ input: [Double], _ output: [Double], _ options: InterpolateOptions = InterpolateOptions()) -> Double {
  precondition(input.count == output.count && input.count >= 2, "interpolate: input と output は同じ長さ (2 以上) にする")
  var seg = 1
  while seg < input.count - 1, input[seg] < value { seg += 1 }
  let i0 = seg - 1
  return interpolateSegment(value, input[i0], input[i0 + 1], output[i0], output[i0 + 1], options)
}

/// 1 区間ぶんの interpolate
private func interpolateSegment(_ input: Double, _ inMin: Double, _ inMax: Double, _ outMin: Double, _ outMax: Double, _ o: InterpolateOptions) -> Double {
  var result = input
  if result < inMin {
    switch o.left {
    case .identity: return result
    case .clamp: result = inMin
    case .wrap: let range = inMax - inMin; result = ((result - inMin).truncatingRemainder(dividingBy: range) + range).truncatingRemainder(dividingBy: range) + inMin
    case .extend: break
    }
  }
  if result > inMax {
    switch o.right {
    case .identity: return result
    case .clamp: result = inMax
    case .wrap: let range = inMax - inMin; result = ((result - inMin).truncatingRemainder(dividingBy: range) + range).truncatingRemainder(dividingBy: range) + inMin
    case .extend: break
    }
  }
  if outMin == outMax { return outMin }
  // 入力の範囲の幅が 0 (長さ 0 の工程・句など) は 0 で割らずに、範囲の手前なら outMin、それ以外は outMax
  if inMax == inMin { return input < inMin ? outMin : outMax }
  result = (result - inMin) / (inMax - inMin)
  result = o.easing(result)
  return result * (outMax - outMin) + outMin
}

// ---------- spring ----------

public struct SpringConfig: Sendable {
  public var damping: Double
  public var mass: Double
  public var stiffness: Double
  public var overshootClamping: Bool
  public init(damping: Double = 10, mass: Double = 1, stiffness: Double = 100, overshootClamping: Bool = false) {
    self.damping = damping; self.mass = mass; self.stiffness = stiffness; self.overshootClamping = overshootClamping
  }
}

private struct SpringState { var current: Double; var velocity: Double }

/// spring の 1 ステップ (advance)。経過時間 deltaMs だけ進めた位置と速度
private func springAdvance(_ s: SpringState, deltaMs: Double, _ c: SpringConfig) -> SpringState {
  let dt = min(deltaMs, 64)
  let v0 = -s.velocity
  let x0 = 1 - s.current
  let zeta = c.damping / (2 * (c.stiffness * c.mass).squareRoot())
  let omega0 = (c.stiffness / c.mass).squareRoot()
  let t = dt / 1000
  if zeta < 1 {
    let omega1 = omega0 * (1 - zeta * zeta).squareRoot()
    let sin1 = sin(omega1 * t), cos1 = cos(omega1 * t)
    let env = exp(-zeta * omega0 * t)
    let frag = env * (sin1 * ((v0 + zeta * omega0 * x0) / omega1) + x0 * cos1)
    let pos = 1 - frag
    let vel = zeta * omega0 * frag - env * (cos1 * (v0 + zeta * omega0 * x0) - omega1 * x0 * sin1)
    return SpringState(current: pos, velocity: vel)
  }
  let env = exp(-omega0 * t)
  let pos = 1 - env * (x0 + (v0 + omega0 * x0) * t)
  let vel = env * (v0 * (t * omega0 - 1) + t * x0 * omega0 * omega0)
  return SpringState(current: pos, velocity: vel)
}

// フレームごとの状態のキャッシュ (1 フレームずつ進めるので、毎回最初から計算しないように)
private final class SpringTable {
  var states: [SpringState] = []
}
nonisolated(unsafe) private var springTables: [String: SpringTable] = [:]
private let springLock = NSLock()

/// 0 → 1 のばねの動き (frame は動き始めからのフレーム、負なら 0)
public func spring(frame: Double, fps: Double, config: SpringConfig = SpringConfig()) -> Double {
  // ばねは数秒で落ち着くので、10 分より先は 10 分の値を使う (大きな frame で表を際限なく伸ばさない・Int() で落ちない)
  let f = frame.isNaN ? 0 : min(max(0, frame), 600 * max(1, fps))
  let whole = Int(f.rounded(.down))
  let key = "\(fps)-\(config.damping)-\(config.mass)-\(config.stiffness)"
  springLock.lock()
  let table: SpringTable
  if let t = springTables[key] { table = t } else { table = SpringTable(); springTables[key] = table }
  if table.states.isEmpty {
    table.states.append(springAdvance(SpringState(current: 0, velocity: 0), deltaMs: 0, config))
  }
  while table.states.count <= whole {
    let k = table.states.count
    let prevTime = Double(k - 1) / fps * 1000
    let now = Double(k) / fps * 1000
    table.states.append(springAdvance(table.states[k - 1], deltaMs: now - prevTime, config))
  }
  var st = table.states[whole]
  springLock.unlock()
  let rest = f - Double(whole)
  if rest > 0 {
    st = springAdvance(st, deltaMs: f / fps * 1000 - Double(whole) / fps * 1000, config)
  }
  if config.overshootClamping { return min(st.current, 1) }
  return st.current
}

/// spring({ frame, fps, config: { damping, stiffness, mass } }) の書き方に合わせた版
public func spring(frame: Double, fps: Double, damping: Double, stiffness: Double = 100, mass: Double = 1) -> Double {
  spring(frame: frame, fps: fps, config: SpringConfig(damping: damping, mass: mass, stiffness: stiffness))
}

// ---------- random ----------

private func mulberry32(_ a: Int32) -> Double {
  var t = UInt32(bitPattern: a) &+ 0x6D2B_79F5
  t = (t ^ (t >> 15)) &* (t | 1)
  t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
  return Double(t ^ (t >> 14)) / 4_294_967_296
}

/// 文字列から決まる疑似乱数 0〜1
public func random(_ seed: String) -> Double {
  var hash: Int32 = 0
  for unit in seed.utf16 {
    hash = (hash << 5) &- hash &+ Int32(unit)
  }
  return mulberry32(hash)
}

/// 数値から決まる疑似乱数 0〜1
public func random(_ seed: Double) -> Double {
  // JS の ToInt32 (Math.imul などに渡したときの 32 ビット整数への変換)
  let v = seed * 10_000_000_000
  guard v.isFinite else { return mulberry32(0) }
  let m = v.rounded(.towardZero).truncatingRemainder(dividingBy: 4_294_967_296)
  let u = m < 0 ? m + 4_294_967_296 : m
  let i = Int32(bitPattern: UInt32(u))
  // mulberry32(a) の a + 0x6d2b79f5 は JS では浮動小数の加算だが、続く演算で 32 ビットに丸められるので同じ
  return mulberry32(i)
}

// ---------- Easing ----------

public enum Easing {
  public static let linear: EasingFn = { $0 }
  public static let quad: EasingFn = { $0 * $0 }
  public static let cubic: EasingFn = { $0 * $0 * $0 }
  public static let sin: EasingFn = { 1 - Foundation.cos($0 * .pi / 2) }
  public static let circle: EasingFn = { 1 - (1 - $0 * $0).squareRoot() }
  public static let exp: EasingFn = { Foundation.pow(2, 10 * ($0 - 1)) }
  public static func poly(_ n: Double) -> EasingFn { { Foundation.pow($0, n) } }
  public static func back(_ s: Double = 1.70158) -> EasingFn { { $0 * $0 * ((s + 1) * $0 - s) } }
  public static func elastic(_ bounciness: Double = 1) -> EasingFn {
    let p = bounciness * .pi
    return { 1 - Foundation.pow(Foundation.cos($0 * .pi / 2), 3) * Foundation.cos($0 * p) }
  }
  public static let bounce: EasingFn = { t in
    if t < 1 / 2.75 { return 7.5625 * t * t }
    if t < 2 / 2.75 { let t2 = t - 1.5 / 2.75; return 7.5625 * t2 * t2 + 0.75 }
    if t < 2.5 / 2.75 { let t2 = t - 2.25 / 2.75; return 7.5625 * t2 * t2 + 0.9375 }
    let t2 = t - 2.625 / 2.75
    return 7.5625 * t2 * t2 + 0.984375
  }
  public static func bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> EasingFn {
    return { t in
      if t <= 0 { return 0 }
      if t >= 1 { return 1 }
      // x(u) = t となる u を二分法で求めて y(u) を返す
      var lo = 0.0, hi = 1.0, u = t
      for _ in 0 ..< 40 {
        u = (lo + hi) / 2
        let x = 3 * (1 - u) * (1 - u) * u * x1 + 3 * (1 - u) * u * u * x2 + u * u * u
        if x < t { lo = u } else { hi = u }
      }
      return 3 * (1 - u) * (1 - u) * u * y1 + 3 * (1 - u) * u * u * y2 + u * u * u
    }
  }
  public static func `in`(_ e: @escaping EasingFn) -> EasingFn { e }
  public static func out(_ e: @escaping EasingFn) -> EasingFn { { 1 - e(1 - $0) } }
  public static func inOut(_ e: @escaping EasingFn) -> EasingFn {
    { $0 < 0.5 ? e($0 * 2) / 2 : 1 - e((1 - $0) * 2) / 2 }
  }
}

// ---------- JS と同じ丸め・剰余 ----------

/// JS の Math.round (0.5 は +∞ 方向に丸める)
public func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

/// JS の % (符号は左辺に合わせる)
public func jsMod(_ a: Double, _ b: Double) -> Double { a.truncatingRemainder(dividingBy: b) }

public func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
