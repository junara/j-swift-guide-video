// macOS の音声 (AVSpeechSynthesizer) で読み上げる。
// コンパイルしたバイナリからはプレミアム/ニューラル音声 (Sakura など) が見えないので、
// 合成のソースをキャッシュに書き出し、swift コマンド (インタプリタ) で子プロセスとして実行する
import CryptoKit
import Foundation
import JGVCore

public enum AVTTS {
  /// swift で直接実行する合成のソース (usage は先頭のコメント)
  static let source = #"""
// AVSpeechSynthesizer で読み上げ音声をファイルに書き出す (jgv が swift で実行する)。
// usage:
//   avtts --list [lang]                          利用可能な音声を JSON で一覧
//   avtts --best [lang]                          最高品質の音声 identifier を出力
//   avtts <identifier> <out.caf> <text> [rate] [pitch]
import AVFoundation
import Foundation

func fail(_ msg: String) -> Never {
  FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
  exit(2)
}

func voices(_ lang: String) -> [AVSpeechSynthesisVoice] {
  AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(lang) }
}

// 品質 (premium > enhanced > default) → ニューラル → 一般的な声 の順で選ぶ
func score(_ v: AVSpeechSynthesisVoice) -> Int {
  var s = v.quality.rawValue * 100
  if v.identifier.contains("neural") { s += 10 }
  if v.identifier.contains("eloquence") || v.identifier.contains("super-compact") { s -= 50 }
  // Bells / Bubbles などのノベルティ音声は選ばない
  if v.identifier.contains("speech.synthesis.voice") { s -= 80 }
  return s
}

func best(_ lang: String) -> AVSpeechSynthesisVoice? {
  voices(lang).max { score($0) < score($1) }
}

let args = CommandLine.arguments
guard args.count >= 2 else { fail("usage: avtts --list [lang] | --best [lang] | <identifier> <out> <text> [rate] [pitch]") }

if args[1] == "--list" {
  let lang = args.count > 2 ? args[2] : "ja"
  let list = voices(lang).sorted { score($0) > score($1) }.map {
    ["name": $0.name, "identifier": $0.identifier, "language": $0.language, "quality": "\($0.quality.rawValue)"]
  }
  let data = try! JSONSerialization.data(withJSONObject: list, options: [.prettyPrinted])
  print(String(data: data, encoding: .utf8)!)
  exit(0)
}

if args[1] == "--best" {
  guard let v = best(args.count > 2 ? args[2] : "ja") else { fail("voice not found") }
  print(v.identifier)
  exit(0)
}

guard args.count >= 4 else { fail("usage: avtts <identifier> <out> <text> [rate] [pitch]") }
let (id, out, text) = (args[1], args[2], args[3])
guard let voice = AVSpeechSynthesisVoice(identifier: id) else {
  fail("voice not found: \(id) (jgv voices で確認)")
}

let utterance = AVSpeechUtterance(string: text)
utterance.voice = voice
if args.count > 4, let r = Float(args[4]) { utterance.rate = r }
if args.count > 5, let p = Float(args[5]) { utterance.pitchMultiplier = p }

let synth = AVSpeechSynthesizer()
var file: AVAudioFile?
var finished = false
synth.write(utterance) { buffer in
  guard let pcm = buffer as? AVAudioPCMBuffer else { return }
  if pcm.frameLength == 0 {
    finished = true
    return
  }
  do {
    if file == nil {
      file = try AVAudioFile(
        forWriting: URL(fileURLWithPath: out), settings: pcm.format.settings,
        commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved)
    }
    try file!.write(from: pcm)
  } catch {
    fail("write failed: \(error)")
  }
}

let deadline = Date().addingTimeInterval(120)
let parent = getppid()
while !finished && Date() < deadline {
  RunLoop.current.run(until: Date().addingTimeInterval(0.05))
  if getppid() != parent { exit(1) }  // jgv が先に終わっていたら (孤児になったら) 続けない
}
if !finished || file == nil { fail("synthesis failed or timed out") }
"""#

  /// 合成のソースのパス (キャッシュに無ければ書き出す)
  static func scriptPath() throws -> String {
    let hash = Insecure.SHA1.hash(data: Data(source.utf8)).hex.prefix(12)
    let dir = cacheDir().appendingPathComponent("avtts")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("avtts-\(hash).swift")
    // 中身が違えば (書きかけ・差し替えられた) 書き直す。キャッシュのファイルをそのまま実行するので、確かめてから使う
    if (try? String(contentsOf: file, encoding: .utf8)) != source { try source.write(to: file, atomically: true, encoding: .utf8) }
    return file.path
  }

  public static func cacheDir() -> URL {
    if let c = ProcessInfo.processInfo.environment["J_GUIDE_VIDEO_CACHE"], !c.isEmpty { return URL(fileURLWithPath: c) }
    return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("j-guide-video")
  }

  /// avtts を実行して標準出力を返す
  public static func run(_ args: [String]) throws -> String {
    try Shell.run("/usr/bin/swift", [try scriptPath()] + args, stop: SIGTERM).stdout
  }

  /// その言語でインストール済みの最高品質の音声
  public static func best(_ lang: String) throws -> String {
    do {
      return try run(["--best", lang]).trimmingCharacters(in: .whitespacesAndNewlines)
    } catch let e as Shell.Failure where e.stderr.contains("voice not found") {
      throw ToolError("\(lang) の macOS の音声がインストールされていません (システム設定 > アクセシビリティ > 読み上げコンテンツ > システムの声 で追加するか、script.json の tts.voice に jgv voices \(lang) で出る identifier を書いてください)")
    }
  }
}

/// 外部コマンドの実行
public enum Shell {
  public struct Failure: LocalizedError {
    public let command: String
    public let status: Int32
    public let stderr: String
    public var errorDescription: String? { "\(command) が失敗しました (\(status)): \(stderr.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))" }
  }

  /// 実行して終わるのを待つ。失敗 (終了コードが 0 以外) なら Failure を投げる
  @discardableResult
  public static func run(_ cmd: String, _ args: [String], env: [String: String]? = nil, cwd: URL? = nil, stdin: String? = nil, inheritOutput: Bool = false, stop: Int32 = SIGINT) throws -> (stdout: String, stderr: String) {
    let p = Process()
    if cmd.contains("/") {
      p.executableURL = URL(fileURLWithPath: cmd)
      p.arguments = args
    } else {
      p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      p.arguments = [cmd] + args
    }
    if let env { p.environment = env }
    if let cwd { p.currentDirectoryURL = cwd }
    let out = Pipe(), err = Pipe()
    if !inheritOutput {
      p.standardOutput = out
      p.standardError = err
    }
    var inPipe: Pipe?
    // 標準入力を渡さないときは読ませない (子は端末の前面のグループではないので、読むと止まったままになる)
    if stdin != nil { inPipe = Pipe(); p.standardInput = inPipe } else { p.standardInput = FileHandle.nullDevice }
    try Children.run(p, stop: stop)
    if let stdin, let inPipe {
      inPipe.fileHandleForWriting.write(stdin.data(using: .utf8)!)
      try? inPipe.fileHandleForWriting.close()
    }
    var outData = Data(), errData = Data()
    if !inheritOutput {
      // パイプが詰まらないよう、終わるのを待ちながら読む
      let group = DispatchGroup()
      group.enter()
      DispatchQueue.global().async { outData = out.fileHandleForReading.readDataToEndOfFile(); group.leave() }
      group.enter()
      DispatchQueue.global().async { errData = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
      group.wait()
    }
    p.waitUntilExit()
    Children.finished(p)
    let so = String(decoding: outData, as: UTF8.self), se = String(decoding: errData, as: UTF8.self)
    if p.terminationStatus != 0 {
      throw Failure(command: ([cmd] + args.prefix(1)).joined(separator: " "), status: p.terminationStatus, stderr: se)
    }
    return (so, se)
  }
}
