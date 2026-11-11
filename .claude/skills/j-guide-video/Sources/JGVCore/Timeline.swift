// timeline.json (jgv tts が書き出す、工程・行・句の時刻) の型。形式は Node 版と同じ
import Foundation

public struct Caption {
  public var text: String
  public var start: Double
  public var end: Double
  public init(text: String, start: Double, end: Double) { self.text = text; self.start = start; self.end = end }
  init(_ j: JSON) {
    text = j["text"]?.string ?? ""
    start = j["start"]?.double ?? 0
    end = j["end"]?.double ?? 0
  }
  public var json: JSON { ["text": .string(text), "start": .number(start), "end": .number(end)] }
}

public struct Line {
  public var sceneIndex: Int
  public var text: String
  public var audio: String
  public var cue: String?
  public var start: Double
  public var duration: Double
  public var captions: [Caption]
  public var phrases: [Caption]
  init(_ j: JSON) {
    sceneIndex = j["sceneIndex"]?.int ?? 0
    text = j["text"]?.string ?? ""
    audio = j["audio"]?.string ?? ""
    cue = j["cue"]?.string
    start = j["start"]?.double ?? 0
    duration = j["duration"]?.double ?? 0
    captions = (j["captions"]?.array ?? []).map(Caption.init)
    phrases = (j["phrases"]?.array ?? []).map(Caption.init)
  }
}

/// 工程の visual (type は visuals/ のファイル名、props は script.json の visual のほかのキー)
public struct VisualRef {
  public var type: String
  public var props: Props
}

public struct Scene {
  public var index: Int
  public var heading: String
  public var visual: VisualRef?
  public var start: Double
  public var end: Double
  init(_ j: JSON) {
    index = j["index"]?.int ?? 0
    heading = j["heading"]?.string ?? ""
    if let v = j["visual"], let t = v["type"]?.string {
      visual = VisualRef(type: t, props: Props(v["props"] ?? .object([])))
    } else {
      visual = nil
    }
    start = j["start"]?.double ?? 0
    end = j["end"]?.double ?? 0
  }
}

public struct Style {
  public var fontFamily: String?
  public var subtitleFontSize: Double?
  public var textColor: String?
  public var accentColor: String?
  public var maxCharsPerCaption: Int?
  /// false で字幕バーを出さない (読み上げだけで伝える)。既定 true
  public var captions: Bool?
  /// false で説明文 (Callout・StepNotes・小手順ラベルなど) を出さない。既定 true
  public var notes: Bool?
  init(_ j: JSON) {
    fontFamily = j["fontFamily"]?.string
    subtitleFontSize = j["subtitleFontSize"]?.double
    textColor = j["textColor"]?.string
    accentColor = j["accentColor"]?.string
    maxCharsPerCaption = j["maxCharsPerCaption"]?.int
    captions = j["captions"]?.bool
    notes = j["notes"]?.bool
  }
}

public struct Timeline {
  public var lang: String?
  public var strings: [String: String]
  /// "guide" | "guide-screen" | "guide-topdown" | "guide-manual"
  public var layout: String
  public var kicker: String?
  public var palette: [String: String]
  /// 人物の見た目 (guide.presenter: "male" / "female" / "neutral")
  public var presenter: String?
  public var credit: String
  public var fps: Double
  public var width: Double
  public var height: Double
  public var durationInSeconds: Double
  public var title: String
  public var style: Style
  public var scenes: [Scene]
  public var lines: [Line]
  public var json: JSON

  public init(_ j: JSON) {
    json = j
    lang = j["lang"]?.string
    var s: [String: String] = [:]
    for (k, v) in j["strings"]?.object ?? [] { if let t = v.string { s[k] = t } }
    strings = s
    layout = j["layout"]?.string ?? "guide"
    let guide = j["guide"]
    kicker = guide?["kicker"]?.string
    var p: [String: String] = [:]
    for (k, v) in guide?["palette"]?.object ?? [] { if let t = v.string { p[k] = t } }
    palette = p
    presenter = guide?["presenter"]?.string
    credit = j["credit"]?.string ?? ""
    fps = j["fps"]?.double ?? 30
    width = j["width"]?.double ?? 1920
    height = j["height"]?.double ?? 1080
    durationInSeconds = j["durationInSeconds"]?.double ?? 3
    title = j["title"]?.string ?? ""
    style = Style(j["style"] ?? .object([]))
    scenes = (j["scenes"]?.array ?? []).map(Scene.init)
    lines = (j["lines"]?.array ?? []).map(Line.init)
    sourceScript = j["source"]?["script"]?.string
    sourceHash = j["source"]?["sha256"]?.string
  }

  /// この timeline を作った台本 (プロジェクトからの相対パス) と、そのときの中身の SHA-256。前の版の jgv が作った timeline では nil
  public var sourceScript: String?
  public var sourceHash: String?

  public static func load(_ url: URL) throws -> Timeline {
    let tl = Timeline(try JSON.read(url))
    if let m = tl.invalidReason { throw JGVError("\(url.lastPathComponent): \(m)") }
    return tl
  }

  /// 描けない値 (fps が 0、幅が 0、長さが無限大など) のときの理由。描ける値なら nil
  public var invalidReason: String? {
    if !fps.isFinite || fps < 1 || fps > 240 { return "fps は 1 以上 240 以下にしてください (\(fps))" }
    if !width.isFinite || !height.isFinite || width < 16 || height < 16 || width > 8192 || height > 8192 {
      return "width / height は 16〜8192 にしてください (\(width)×\(height))"
    }
    // H.264 は偶数の大きさだけ (奇数・小数は、黙って別の大きさの動画になり、絵の座標とずれる)
    if width != width.rounded() || height != height.rounded() || Int(width) % 2 != 0 || Int(height) % 2 != 0 {
      return "width / height は偶数の整数にしてください (\(width)×\(height))"
    }
    // H.264 (レベル 5.2) で書ける大きさ: 16×16 のブロックが 36864 個まで (4096×2304 ほど。8192×8192 などは書き出しの途中で失敗する)
    if (width / 16).rounded(.up) * (height / 16).rounded(.up) > 36864 {
      return "width × height が大きすぎて H.264 で書き出せません (\(width)×\(height)。4096×2304 ほどまで)"
    }
    // 音声は全編を 1 本のメモリに持つので、長さは 2 時間まで (48kHz で約 1.4 GB)
    if !durationInSeconds.isFinite || durationInSeconds < 0 || durationInSeconds > 7200 { return "durationInSeconds は 0〜7200 (2 時間) にしてください (\(durationInSeconds))" }
    func inRange(_ x: Double) -> Bool { x.isFinite && x >= -1 && x <= durationInSeconds + 60 }
    // 工程の index は並びの順 (0, 1, 2 …)。ビルドのターゲット名 (Scene<N>)・--scene=N・行の sceneIndex が、どれも同じ工程を指すように
    for (i, s) in scenes.enumerated() where s.index != i { return "scenes[\(i)] の index が \(s.index) です (並びの順の \(i) のはず。jgv tts で作り直してください)" }
    for s in scenes where !inRange(s.start) || !inRange(s.end) { return "工程 \(s.index) の start / end が動画の長さの外です (\(s.start)〜\(s.end))" }
    for (i, l) in lines.enumerated() {
      if l.sceneIndex < 0 || l.sceneIndex >= max(1, scenes.count) { return "lines[\(i)] の sceneIndex (\(l.sceneIndex)) の工程がありません" }
      if !inRange(l.start) || !l.duration.isFinite || l.duration < 0 || l.duration > durationInSeconds + 60 { return "lines[\(i)] の start / duration が動画の長さの外です" }
      if l.phrases.contains(where: { !inRange($0.start) || !inRange($0.end) }) { return "lines[\(i)] の phrases の時刻が動画の長さの外です" }
      // 音声はプロジェクトの .jgv/narration/ の中のファイルだけ (../ などで外のファイルを動画に入れない)
      if !l.audio.isEmpty && l.audio.range(of: "^narration/[A-Za-z0-9_-]+\\.wav$", options: .regularExpression) == nil { return "lines[\(i)] の audio「\(l.audio)」は narration/<名前>.wav の形ではありません" }
    }
    // visual 名はファイル名・Swift の名前になる (../ などを含む名前で、プロジェクトの外のファイルを指させない)
    for s in scenes {
      if let t = s.visual?.type, !Safety.isVisualName(t) {
        return "工程 \(s.index) の visual「\(t)」は使えない名前です (英大文字で始まる英数字・_ だけ。jgv tts で作り直してください)"
      }
    }
    return nil
  }

  public var durationInFrames: Int { max(1, Int((durationInSeconds * fps).rounded(.up))) }
}

/// visual に script.json から渡す値 ("visual": { "type": "Pour", "cups": 2 } の cups など)
public struct Props {
  public let json: JSON
  public init(_ json: JSON = .object([])) { self.json = json }
  public subscript(key: String) -> JSON? { json[key] }
  public func double(_ key: String, _ fallback: Double) -> Double { json[key]?.double ?? fallback }
  public func string(_ key: String, _ fallback: String) -> String { json[key]?.string ?? fallback }
  public func bool(_ key: String, _ fallback: Bool) -> Bool { json[key]?.bool ?? fallback }
}
