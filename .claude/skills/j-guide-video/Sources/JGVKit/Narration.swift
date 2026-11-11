// ナレーションに同期したアニメーションを作るためのフック (useNarration)。工程の visual の中で使う
@_exported import Foundation
@_exported import JGVCore

/// シーン内のナレーション 1 行 (フレームはシーン先頭からの相対値)
public struct NarrationLine {
  public var index: Int
  public var text: String
  public var cue: String?
  public var start: Double
  public var end: Double
  public var captions: [Caption]
  /// 読点・句点で区切った句ごとの区間
  public var phrases: [Caption]
  public init(index: Int, text: String, cue: String?, start: Double, end: Double, captions: [Caption], phrases: [Caption]) {
    self.index = index; self.text = text; self.cue = cue; self.start = start; self.end = end; self.captions = captions; self.phrases = phrases
  }
}

public struct SceneInfo {
  public var sceneIndex: Int
  public var heading: String
  public var lines: [NarrationLine]
  public var accent: Paint
  public var textColor: Paint
  public var fontFamily: String
  /// 画面上の文言 (script.json の strings)。多言語版で差し替える
  public var strings: [String: String]
  public init(sceneIndex: Int, heading: String, lines: [NarrationLine], accent: Paint, textColor: Paint, fontFamily: String, strings: [String: String]) {
    self.sceneIndex = sceneIndex; self.heading = heading; self.lines = lines; self.accent = accent; self.textColor = textColor
    self.fontFamily = fontFamily; self.strings = strings
  }
}

/// 行の指定: 行番号 (0 始まり) または script.json の lines[].cue
public enum LineKey: ExpressibleByIntegerLiteral, ExpressibleByStringLiteral {
  case index(Int)
  case cue(String)
  public init(integerLiteral value: Int) { self = .index(value) }
  public init(stringLiteral value: String) { self = .cue(value) }
}

public struct Narration {
  public let sceneIndex: Int
  public let heading: String
  public let lines: [NarrationLine]
  public let accent: Paint
  public let textColor: Paint
  public let fontFamily: String
  public let strings: [String: String]
  /// シーン先頭からのフレーム
  public let frame: Double
  /// シーン先頭からの秒
  public let sec: Double
  public let fps: Double
  public let width: Double
  public let height: Double
  /// シーンの長さ (フレーム)
  public let durationInFrames: Double
  public let portrait: Bool
  /// 見出し (タイトル・工程バッジ) と字幕バーを除いた描画領域
  public let safe: Box
  /// 説明文を表示するか (script.json の style.notes)。visual に直接書く説明の文字は if n.notes { … } で囲む
  public let notes: Bool

  func find(_ key: LineKey) -> NarrationLine? {
    switch key {
    case let .index(i): return i >= 0 && i < lines.count ? lines[i] : nil
    case let .cue(c): return lines.first { $0.cue == c }
    }
  }

  // 該当行が無いとき (多言語版で文の数が少ないなど) は、シーンの外の十分先を返す。
  // 行番号・句番号の順序は保つので、interpolate の範囲が逆転しない
  func missing(_ key: LineKey, _ phrase: Int = 0) -> Double {
    let k: Int
    if case let .index(i) = key { k = i } else { k = lines.count }
    return durationInFrames + 1000 + Double(k) * 100 + Double(phrase) * 10
  }

  /// 行の読み上げ開始フレーム (+ offsetSec 秒)。該当行が無ければシーンの外 (動きは起きない)
  public func at(_ key: LineKey, _ offsetSec: Double = 0) -> Double {
    (find(key)?.start ?? missing(key)) + jsRound(offsetSec * fps)
  }

  /// 行の中の k 番目の句 (読点・句点区切り) の開始フレーム。句が無ければ行の中で順番どおりの位置
  public func atPhrase(_ key: LineKey, _ k: Int, _ offsetSec: Double = 0) -> Double {
    let k = max(0, k)
    guard let l = find(key) else { return missing(key, k) + jsRound(offsetSec * fps) }
    return phraseStart(l, k) + jsRound(offsetSec * fps)
  }

  /// 行の読み上げ終了フレーム
  public func endOf(_ key: LineKey) -> Double { find(key)?.end ?? missing(key, 5) }

  /// 行の開始から durSec 秒かけて 0→1 (線形)
  public func progress(_ key: LineKey, _ durSec: Double = 0.8, _ offsetSec: Double = 0) -> Double {
    let a = at(key, offsetSec)
    return interpolate(frame, [a, a + durSec * fps], [0, 1], .clamp)
  }

  /// 行の開始でなめらかに 0→1 (spring / オーバーシュートなし)
  public func ease(_ key: LineKey, _ offsetSec: Double = 0) -> Double {
    spring(frame: frame - at(key, offsetSec), fps: fps, damping: 200)
  }

  /// その行を読み上げ中か
  public func isSpeaking(_ key: LineKey) -> Bool {
    guard let l = find(key) else { return false }
    return frame >= l.start && frame < l.end
  }

  // 行番号を Int の変数で渡す版 (n.at(i) のように書ける)
  public func at(_ i: Int, _ offsetSec: Double = 0) -> Double { at(.index(i), offsetSec) }
  public func atPhrase(_ i: Int, _ k: Int, _ offsetSec: Double = 0) -> Double { atPhrase(.index(i), k, offsetSec) }
  public func endOf(_ i: Int) -> Double { endOf(.index(i)) }
  public func progress(_ i: Int, _ durSec: Double = 0.8, _ offsetSec: Double = 0) -> Double { progress(.index(i), durSec, offsetSec) }
  public func ease(_ i: Int, _ offsetSec: Double = 0) -> Double { ease(.index(i), offsetSec) }
  public func isSpeaking(_ i: Int) -> Bool { isSpeaking(.index(i)) }

  /// 画面上の文言を取得 (script.json の strings[key]、無ければ fallback)
  public func t(_ key: String, _ fallback: String? = nil) -> String { strings[key] ?? fallback ?? key }
}

/// 行 l の k 番目の句の開始フレーム (Narration.atPhrase の計算。CueScene が前の工程の時刻を求めるのにも使う)。
/// 句が足りない (言語によって読点の数が違う) ときは、最後にある句の始まりから行の終わりまでの間に、順番どおり
/// (ある句より前に来ない) に割り当てる。句が 1 つも無ければ行の始まりから
func phraseStart(_ l: NarrationLine, _ k: Int) -> Double {
  if k < l.phrases.count { return l.phrases[k].start }
  if let last = l.phrases.last {
    let m = Double(k - l.phrases.count + 1)
    return jsRound(last.start + ((l.end - last.start) * m) / (m + 1))
  }
  return jsRound(l.start + ((l.end - l.start) * Double(k)) / Double(k + 1))
}

/// 工程ごとの読み上げの時刻 (visual 名 → 行とフレーム数)。NarratedVideo が provide し、CueScene が
/// `init <前の工程` の終わりの状態を、前の工程の実際の時刻の順で求めるのに使う
public struct SceneTimings {
  public var byVisual: [String: (lines: [NarrationLine], durationInFrames: Double)]
  public init(byVisual: [String: (lines: [NarrationLine], durationInFrames: Double)]) { self.byVisual = byVisual }
}

/// ナレーションに同期したアニメーションを作るためのフック。工程の visual の中で使う
public func useNarration() -> Narration {
  guard let scene = useContextValue(SceneInfo.self) else {
    fatalError("useNarration() は visual の中で使ってください")
  }
  let frame = useCurrentFrame()
  let cfg = useVideoConfig()
  let guide = useGuide()
  return Narration(
    sceneIndex: scene.sceneIndex, heading: scene.heading, lines: scene.lines, accent: scene.accent, textColor: scene.textColor,
    fontFamily: scene.fontFamily, strings: scene.strings, frame: frame, sec: frame / cfg.fps, fps: cfg.fps, width: cfg.width,
    height: cfg.height, durationInFrames: cfg.durationInFrames, portrait: cfg.height > cfg.width, safe: guide.layout.content,
    notes: guide.notes
  )
}

/// 色・フォントだけ欲しいとき用 (シーンの外でも動く)
public func useTheme() -> (accent: Paint, textColor: Paint, fontFamily: String) {
  let scene = useContextValue(SceneInfo.self)
  let guide = useGuide()
  return (scene?.accent ?? guide.palette.accent, scene?.textColor ?? guide.palette.ink, scene?.fontFamily ?? guide.font)
}
