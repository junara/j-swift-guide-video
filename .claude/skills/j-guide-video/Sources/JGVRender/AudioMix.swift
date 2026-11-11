// ナレーションの音声 (行ごとの wav) を timeline の時刻に並べて 1 本にする
import AVFoundation
import Foundation
import JGVCore

public enum AudioMix {
  public static let sampleRate = 48000.0

  public static func readMono(_ url: URL, sampleRate: Double = sampleRate) throws -> [Float] { try AudioFile.readMono(url, sampleRate: sampleRate) }

  /// timeline の各行の音声を、その行の開始時刻に置いた動画全体の音声 (モノラル)
  public static func mix(_ tl: Timeline, publicDir: URL) throws -> [Float] {
    let total = Int((Double(tl.durationInFrames) / tl.fps * sampleRate).rounded(.up))
    var out = [Float](repeating: 0, count: total)
    var cache: [String: [Float]] = [:]
    for line in tl.lines {
      // audio が空の行は無音 (読み上げの無い行)
      if line.audio.isEmpty { continue }
      let samples: [Float]
      if let c = cache[line.audio] {
        samples = c
      } else {
        let url = publicDir.appendingPathComponent(line.audio)
        guard FileManager.default.fileExists(atPath: url.path) else { throw err("音声 \(url.path) がありません (jgv tts を実行してください)") }
        // jgv tts が作ったふつうのファイルだけ読む (リンクでプロジェクトの外の音声を動画に入れない)
        guard Safety.isRegularFile(url), !Safety.isSymlink(publicDir), !Safety.isSymlink(url.deletingLastPathComponent()) else {
          throw err("音声 \(url.path) (またはそのフォルダ) がシンボリックリンクです。jgv tts で作り直してください")
        }
        samples = try readMono(url)
        cache[line.audio] = samples
      }
      // 行の始まりをフレームの境に合わせ、行の長さで切る (fps が整数でなくても、フレーム → サンプルの換算を切り捨てない)
      let start = Int(((line.start * tl.fps).rounded() / tl.fps * sampleRate).rounded())
      let maxLen = Int(((line.duration * tl.fps).rounded(.up) / tl.fps * sampleRate).rounded())
      for k in 0 ..< min(samples.count, maxLen) where start + k < total && start + k >= 0 {
        out[start + k] += samples[k]
      }
    }
    for k in 0 ..< out.count { out[k] = max(-1, min(1, out[k])) }
    return out
  }

  static func err(_ m: String) -> JGVError { JGVError(m) }
}
