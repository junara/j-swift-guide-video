// 読み上げ音声の後処理: ラウドネスをそろえる (ITU-R BS.1770 の積分ラウドネスで -16 LUFS、ピークは -1.5 dBFS まで) と、
// 句読点の間の無音を探す (ffmpeg の loudnorm / silencedetect の代わり)
import Foundation

public enum AudioProcess {
  /// ITU-R BS.1770-4 の積分ラウドネス (LUFS)。48kHz のモノラル
  public static func integratedLoudness(_ x: [Float], sampleRate: Double = 48000) -> Double {
    // K 特性 (48kHz の係数): 高域シェルフ → ハイパス
    let b1: [Double] = [1.53512485958697, -2.69169618940638, 1.19839281085285]
    let a1: [Double] = [1, -1.69065929318241, 0.73248077421585]
    let b2: [Double] = [1, -2, 1]
    let a2: [Double] = [1, -1.99004745483398, 0.99007225036621]
    var y = [Double](repeating: 0, count: x.count)
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
    for i in 0 ..< x.count {
      let v = Double(x[i])
      let o = b1[0] * v + b1[1] * x1 + b1[2] * x2 - a1[1] * y1 - a1[2] * y2
      x2 = x1; x1 = v; y2 = y1; y1 = o
      y[i] = o
    }
    x1 = 0; x2 = 0; y1 = 0; y2 = 0
    for i in 0 ..< y.count {
      let v = y[i]
      let o = b2[0] * v + b2[1] * x1 + b2[2] * x2 - a2[1] * y1 - a2[2] * y2
      x2 = x1; x1 = v; y2 = y1; y1 = o
      y[i] = o
    }
    // 400ms の区間 (75% 重ねる) の平均二乗
    let block = Int(0.4 * sampleRate)
    let step = Int(0.1 * sampleRate)
    var powers: [Double] = []
    if y.count < block {
      let p = y.reduce(0) { $0 + $1 * $1 } / Double(max(1, y.count))
      powers = [p]
    } else {
      var start = 0
      while start + block <= y.count {
        var s = 0.0
        for i in start ..< start + block { s += y[i] * y[i] }
        powers.append(s / Double(block))
        start += step
      }
    }
    let lk = { (p: Double) in -0.691 + 10 * log10(max(p, 1e-12)) }
    let abs = powers.filter { lk($0) > -70 }
    guard !abs.isEmpty else { return -70 }
    let rel = lk(abs.reduce(0, +) / Double(abs.count)) - 10
    let gated = abs.filter { lk($0) > rel }
    guard !gated.isEmpty else { return -70 }
    return lk(gated.reduce(0, +) / Double(gated.count))
  }

  /// 積分ラウドネスを target (LUFS) にそろえ、ピークを peakDb (dBFS) 以下に抑える (先読みのリミッター)
  public static func normalize(_ x: [Float], sampleRate: Double = 48000, target: Double = -16, peakDb: Double = -1.5) -> [Float] {
    let loud = integratedLoudness(x, sampleRate: sampleRate)
    let gain = Float(pow(10, (target - loud) / 20))
    var y = x.map { $0 * gain }
    let limit = Float(pow(10, peakDb / 20))
    // 必要な減衰を、先読み 5ms の範囲の最小値にして、50ms で戻す
    let look = Int(0.005 * sampleRate)
    let release = Float(exp(-1 / (0.05 * sampleRate)))
    var need = [Float](repeating: 1, count: y.count)
    var any = false
    for i in 0 ..< y.count {
      let a = Swift.abs(y[i])
      if a > limit { need[i] = limit / a; any = true }
    }
    guard any else { return y }
    // 先読みの最小値 (前後 look サンプル)
    var minNeed = need
    for i in 0 ..< need.count where need[i] < 1 {
      let lo = max(0, i - look)
      for k in lo ... i where minNeed[k] > need[i] { minNeed[k] = need[i] }
    }
    var g: Float = 1
    for i in 0 ..< y.count {
      let t = minNeed[i]
      g = t < g ? t : t - (t - g) * release
      y[i] *= g
    }
    return y
  }

  /// 無音の区間 (ffmpeg の silencedetect=noise=-35dB:d=0.08 と同じ判定)。行頭・行末に接する無音は除く
  public static func silences(_ x: [Float], sampleRate: Double = 48000, noiseDb: Double = -35, minDuration: Double = 0.08) -> [(start: Double, end: Double)] {
    let thr = Float(pow(10, noiseDb / 20))
    let minLen = Int(minDuration * sampleRate)
    let duration = Double(x.count) / sampleRate
    var out: [(Double, Double)] = []
    var runStart: Int? = nil
    for i in 0 ... x.count {
      let quiet = i < x.count && Swift.abs(x[i]) < thr
      if quiet {
        if runStart == nil { runStart = i }
      } else if let s = runStart {
        if i - s >= minLen {
          let start = Double(s) / sampleRate, end = Double(i) / sampleRate
          if start > 0.02 && end < duration - 0.02 { out.append((start, end)) }
        }
        runStart = nil
      }
    }
    return out
  }
}
