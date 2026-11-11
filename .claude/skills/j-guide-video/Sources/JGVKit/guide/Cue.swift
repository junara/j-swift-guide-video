// 工程の動きを短い文字の列 (キュー) で書く。プロジェクトの cues/<名前>.cue を実行時に読む (変えてもビルドし直さない)。
// 道具の描き方・持つ所・置き場所は、動画ごとに 1 回だけ CueBinding に Swift で書き、どの工程のキューからも名前で指す。
//
// 文法 (1 行 = 1 つの時刻。# から行末はコメント):
//   init [<前の工程] k=v … o@PLACE …   始まりの状態。<Load で cues/Load.cue の終わりの状態を引き継ぎ、続けて書いた値で上書きする
//   <時刻> 命令;命令;…                時刻は L.P (行 L の句 P の読み始め) か end、+秒 / -秒 でずらす (例 0.2+.45、end-.5)
// 命令 (時刻は、手は「着く」時刻、ほかは「始まる」時刻):
//   H>点[~秒]   人物の右手がその時刻に点へ着く (既定 0.4 秒かけて伸ばす)。着いた後は点が動いても付いていく。最後は自動で定位置へ
//   C>点[~秒]   拡大カードの中の手 (袖の腕。付け根は点 c.sleeve、初めは点 c.away)
//   P 点        右手で点を押す
//   k=数[~秒]   値を変える (~秒 で変わる時間、@時刻 でその時刻まで)。k=文字 は文字にする
//   k=cd A B@時刻      文字の値を A から B まで数え下ろす (2:00 → 0:00)
//   k=wave 幅 周期@時刻  値に揺れを足す (H.dx C.dx などで手を揺らす)
//   o@PLACE[~秒]       物を置き場所へ動かす (o.x o.y o.s。途中は弧を描く)
//   drop o[~高さ]      物が落ちてきて置かれる (o.vis が 1 になり、o.dy が 0 に向かう)
//   card 文字@時刻|文字@時刻|…  拡大カードを出し、小手順ラベルを切り替える (init の card.enter=0 / card.exit=0 で開いたまま)
//   shrink 点[~秒]     拡大カードを点へ縮めて消す
//   notes 文字@時刻|文字@時刻|…  右側のポイントメモ (画面操作型。位置は点 notes)
//   parts 記号:名前:数@時刻|…    部品リスト (組み立て説明書型。その時刻に行が光る。位置は点 parts)
//   say 点 文字[@時刻] / timer 点 文字@時刻 / pulse 点[@時刻] / steam 点[@時刻] / sparkle 点[@時刻] / check 点
//                      注釈・円弧タイマー・波紋・湯気・きらめき・完了のチェック。点が c. で始まると拡大カードの中に描く
// 点: 名前 (binding.points、rest、gesture、c.away、c.sleeve)、名前+dx,dy、(x,y)
// 文字 (say・timer・card・notes): $キー:既定の文 と書くと、台本の strings[キー] (多言語版の訳) を使う
// 値: smile (人物の笑顔 0〜1) は kit が使う。H.x H.y C.x C.y (手の位置) と pressed (P で押している間、押した点の名前) は
//   kit が入れるので、binding の描画で使える
// binding.hand: .presenter (人物の右手) / .finger (指のタップ。人物は描かない) / .cursor (マウスカーソル)。
//   / .none (kit は手を描かない。binding が H.x H.y に TopHand などを描く)。.presenter 以外のときの定位置は点 rest (binding.points に書く)
import Foundation
import JGVCore

public struct CueState {
  public var num: [String: Double] = [:]
  public var str: [String: String] = [:]
  public init() {}
  public subscript(_ k: String) -> Double { num[k] ?? 0 }
  public func s(_ k: String) -> String { str[k] ?? "" }
  /// 物 o の位置と倍率 (落ちてくる途中の o.dy を足した位置)
  public func obj(_ o: String) -> (x: Double, y: Double, s: Double) { (self["\(o).x"], self["\(o).y"] + self["\(o).dy"], num["\(o).s"] ?? 1) }
  public func on(_ k: String) -> Bool { self[k] > 0.5 }
}

public enum CueHand { case presenter, finger, cursor, none }

/// 動画ごとの道具の描き方と名前 (全工程で共通)
public struct CueBinding {
  public var hand: CueHand = .presenter
  public var keys: Set<String>
  public var objects: Set<String>
  public var points: [String: (CueState) -> Pt]
  public var places: [String: (x: Double, y: Double, s: Double)]
  /// 全景 (人物より奥)・全景 (人物より手前。運んでいる物など)・拡大カードの中 (袖の腕より奥)
  public var draw: (CueState) -> Void
  public var front: (CueState) -> Void
  public var card: (CueState) -> Void
  public init(keys: Set<String>, objects: Set<String> = [], points: [String: (CueState) -> Pt], places: [String: (x: Double, y: Double, s: Double)] = [:],
              hand: CueHand = .presenter,
              draw: @escaping (CueState) -> Void, front: @escaping (CueState) -> Void = { _ in }, card: @escaping (CueState) -> Void = { _ in }) {
    self.hand = hand
    self.keys = keys
    self.objects = objects
    self.points = points
    self.places = places
    self.draw = draw
    self.front = front
    self.card = card
  }
}

/// jgv check のときに集める報告 (工程ごと)。
/// ロックは無い: active にするのは jgv check (VideoMain の check) だけで、check は工程を 1 つずつ同じスレッドで描く。
/// 並列に描く経路 (snapshots / render) では active を立てないこと
public enum CueCheck {
  nonisolated(unsafe) public static var active = false
  /// 言語版の台本 (script.<言語>.json) を確かめているか。そのときだけ、無い句を推定で埋めて注意 (?) にとどめる
  /// (基準の台本では、無い句は打ち間違いなので誤り (!) にする)
  nonisolated(unsafe) public static var languageVariant = false
  nonisolated(unsafe) public static var report: [Int: [String]] = [:]
  nonisolated(unsafe) public static var start: [Int: [String: String]] = [:]
  nonisolated(unsafe) public static var end: [Int: [String: String]] = [:]
  /// 拡大カードを開いたまま次の工程へつなぐか (card.exit=0) / 前の工程から開いたまま受けるか (card.enter=0)
  nonisolated(unsafe) public static var cardOut: [Int: Bool] = [:]
  nonisolated(unsafe) public static var cardIn: [Int: Bool] = [:]
}

// ---------- 解析 ----------

struct CueAnchor {
  var line: Int?
  var phrase: Int
  var off: Double
  /// 工程の中の順番 (時刻が分からないときに並べるため)
  var order: Double { line.map { Double($0) * 100 + Double(phrase) + off / 100 } ?? 1e6 + off }
}

enum CueCmd {
  case hand(String, String, Double, press: Bool)
  case num(String, Double, dur: Double, until: CueAnchor?)
  case str(String, String)
  case countdown(String, String, String, until: CueAnchor)
  case wave(String, Double, Double, until: CueAnchor)
  case move(String, String, dur: Double)
  case drop(String, Double)
  case card([(String, CueAnchor)])
  case notes([(String, CueAnchor)])
  case parts([(String, CueAnchor)])
  case shrink(String, Double)
  case fx(String, String, String, until: CueAnchor?)
}

struct CueProgram {
  var inherit: String?
  var initNum: [String: Double] = [:]
  var initStr: [String: String] = [:]
  var initPlace: [(String, String)] = []
  var cues: [(lineNo: Int, at: CueAnchor, cmd: CueCmd)] = []
  var errors: [String] = []
}

nonisolated(unsafe) private var cueCache: [String: (Date, CueProgram)] = [:]
private let cueLock = NSLock()

func loadCue(_ name: String) -> CueProgram {
  let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("cues/\(name).cue")
  let mtime = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .distantPast
  cueLock.lock()
  defer { cueLock.unlock() }
  if let (t, p) = cueCache[url.path], t == mtime { return p }
  var p = CueProgram()
  if let text = try? String(contentsOf: url, encoding: .utf8) { p = parseCue(text) } else { p.errors.append("cues/\(name).cue がありません") }
  cueCache[url.path] = (mtime, p)
  return p
}

private func cueNum(_ s: Substring) -> Double? {
  // 10 進の数だけ (Double() に任せると inf / nan / 1e3 も数になってしまう)
  guard s.range(of: "^[+-]?([0-9]+(\\.[0-9]*)?|\\.[0-9]+)$", options: .regularExpression) != nil else { return nil }
  var t = String(s)
  if t.hasPrefix(".") { t = "0" + t }
  if t.hasPrefix("+.") || t.hasPrefix("-.") { t = String(t.first!) + "0" + t.dropFirst() }
  if t.hasPrefix("+") { t.removeFirst() }
  // 大きすぎる値は誤り (時刻の計算が巨大になり、メモリが尽きる・Int() で落ちる)
  guard let v = Double(t), abs(v) < 1e7 else { return nil }
  return v
}
/// 秒の長さ・ずらし秒の上限 (動画は 2 時間まで)
private let cueMaxSec = 7200.0

func parseAnchor(_ s: String) -> CueAnchor? {
  var body = s
  var off = 0.0
  if let r = s.range(of: "[+-][0-9.]+$", options: .regularExpression), r.lowerBound != s.startIndex {
    guard let o = cueNum(s[r]), abs(o) <= cueMaxSec else { return nil }
    off = o
    body = String(s[..<r.lowerBound])
  }
  if body == "end" { return CueAnchor(line: nil, phrase: 0, off: off) }
  // 行・句は 0 以上 (負の数を通すと lines[l] / phrases[k] の範囲外で落ちる)
  let parts = body.split(separator: ".")
  guard parts.count == 2, let l = Int(parts[0]), let ph = Int(parts[1]), l >= 0, ph >= 0, l < 100_000, ph < 100_000 else { return nil }
  return CueAnchor(line: l, phrase: ph, off: off)
}

private let untilRe = "@(?:[0-9]+\\.[0-9]+|end)(?:[+-][0-9.]+)?$"

func parseCue(_ text: String) -> CueProgram {
  var p = CueProgram()
  func splitUntil(_ s: String) -> (String, CueAnchor?) {
    if let r = s.range(of: untilRe, options: .regularExpression) { return (String(s[..<r.lowerBound]), parseAnchor(String(s[r].dropFirst()))) }
    return (s, nil)
  }
  func splitDur(_ s: String, _ d: Double) -> (String, Double) {
    if let r = s.range(of: "~[0-9.]+$", options: .regularExpression) { let v = cueNum(s[r].dropFirst()).flatMap { $0 <= cueMaxSec ? $0 : nil }; return (String(s[..<r.lowerBound]), v ?? d) }
    return (s, d)
  }
  for (i, raw) in text.components(separatedBy: "\n").enumerated() {
    let ln = i + 1
    // CRLF の \r も落とす
    let line = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
    if line.isEmpty { continue }
    if line.hasPrefix("init") {
      for tok in line.dropFirst(4).split(whereSeparator: { $0 == " " || $0 == "\t" }) {
        if tok.hasPrefix("<") {
          // 前の工程の名前は visual 名だけ (cues/<名前>.cue を読むので、../ などで cues/ の外のファイルを読まない)
          let name = String(tok.dropFirst())
          if Safety.isVisualName(name) { p.inherit = name } else { p.errors.append("\(ln): init <\(name) は工程の visual 名ではない (英大文字で始まる英数字・_)") }
          continue
        }
        if let at = tok.firstIndex(of: "@"), !tok.contains("=") { p.initPlace.append((String(tok[..<at]), String(tok[tok.index(after: at)...]))); continue }
        let kv = tok.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard kv.count == 2 else { p.errors.append("\(ln): init の \(tok) が読めない"); continue }
        if let v = cueNum(kv[1]) { p.initNum[String(kv[0])] = v } else { p.initStr[String(kv[0])] = String(kv[1]) }
      }
      continue
    }
    guard let sp = line.firstIndex(where: { $0 == " " || $0 == "\t" }), let anchor = parseAnchor(String(line[..<sp])) else { p.errors.append("\(ln): 時刻が読めない (L.P[+秒] か end)"); continue }
    for c in line[line.index(after: sp)...].split(separator: ";") {
      // タブもスペースと同じ区切りにする (エディタがタブを入れても読めるように)
      let cmd = c.replacingOccurrences(of: "\t", with: " ").trimmingCharacters(in: .whitespaces)
      if cmd.isEmpty { continue }
      if cmd.count > 2, ["H>", "C>"].contains(String(cmd.prefix(2))) {
        let (pt, d) = splitDur(String(cmd.dropFirst(2)), 0.4)
        p.cues.append((ln, anchor, .hand(String(cmd.prefix(1)), pt, d, press: false)))
      } else if cmd.hasPrefix("P ") {
        p.cues.append((ln, anchor, .hand("H", String(cmd.dropFirst(2)), 0.35, press: true)))
      } else if let kind = ["card", "notes", "parts"].first(where: { cmd.hasPrefix($0 + " ") }) {
        var steps: [(String, CueAnchor)] = []
        for st in cmd.dropFirst(kind.count + 1).split(separator: "|") {
          let (label, a) = splitUntil(String(st))
          if let a { steps.append((label, a)) } else { p.errors.append("\(ln): \(st) に @時刻 が無い") }
          if kind == "parts" && label.split(separator: ":").count != 3 { p.errors.append("\(ln): parts は 記号:名前:数@時刻 (\(st))") }
        }
        p.cues.append((ln, anchor, kind == "card" ? .card(steps) : kind == "notes" ? .notes(steps) : .parts(steps)))
      } else if cmd.hasPrefix("shrink ") {
        let (pt, d) = splitDur(String(cmd.dropFirst(7)), 0.4)
        p.cues.append((ln, anchor, .shrink(pt, d)))
      } else if cmd.hasPrefix("drop ") {
        let (o, h) = splitDur(String(cmd.dropFirst(5)), 320)
        p.cues.append((ln, anchor, .drop(o, h)))
      } else if let kind = ["say", "timer", "pulse", "steam", "sparkle", "check"].first(where: { cmd.hasPrefix($0 + " ") }) {
        let (body, until) = splitUntil(cmd)
        let parts = body.split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        let needsText = kind == "say" || kind == "timer"
        if parts.count != (needsText ? 3 : 2) || (kind == "timer" && until == nil) { p.errors.append("\(ln): \(cmd) の形が違う"); continue }
        p.cues.append((ln, anchor, .fx(kind, parts[1], needsText ? parts[2] : "", until: until)))
      } else if let eq = cmd.firstIndex(of: "=") {
        let k = String(cmd[..<eq])
        let v = String(cmd[cmd.index(after: eq)...])
        if v.hasPrefix("cd ") {
          let (body, until) = splitUntil(String(v.dropFirst(3)))
          let ab = body.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
          if ab.count == 2, let until, clockSec(ab[0]) != nil, clockSec(ab[1]) != nil { p.cues.append((ln, anchor, .countdown(k, ab[0], ab[1], until: until))) } else { p.errors.append("\(ln): cd は k=cd 分:秒 分:秒@時刻 (例 cd 3:00 0:00@1.0)") }
        } else if v.hasPrefix("wave ") {
          let (body, until) = splitUntil(String(v.dropFirst(5)))
          let ab = body.split(whereSeparator: { $0 == " " || $0 == "\t" }).compactMap { cueNum($0) }
          if ab.count == 2, ab[1] > 0, let until { p.cues.append((ln, anchor, .wave(k, ab[0], ab[1], until: until))) } else { p.errors.append("\(ln): wave は k=wave 幅 周期@時刻 (周期は 0 より大きい秒)") }
        } else {
          let (b1, until) = splitUntil(v)
          let (b2, d) = splitDur(b1, 0)
          if let x = cueNum(Substring(b2)) { p.cues.append((ln, anchor, .num(k, x, dur: d, until: until))) }
          // 文字の値は一瞬で変わる (~秒 / @時刻 を付けると、そのまま文字になってしまうので誤りにする)
          else if until != nil || b2 != b1 { p.errors.append("\(ln): \(k)=\(v) は文字の値なので ~秒 / @時刻 は付けられない") }
          else { p.cues.append((ln, anchor, .str(k, v))) }
        }
      } else if let at = cmd.firstIndex(of: "@") {
        let (place, d) = splitDur(String(cmd[cmd.index(after: at)...]), 0.6)
        p.cues.append((ln, anchor, .move(String(cmd[..<at]), place, dur: d)))
      } else {
        p.errors.append("\(ln): \(cmd) は知らない命令")
      }
    }
  }
  return p
}

/// 工程 name の時刻 (読み上げの時刻が NarratedVideo から渡されているとき)。キューの時刻をフレームにする
private func cueFrameOf(_ name: String) -> ((CueAnchor) -> Double)? {
  guard let t = useContextValue(SceneTimings.self)?.byVisual[name] else { return nil }
  let fps = useVideoConfig().fps
  return { a in
    guard let l = a.line else { return t.durationInFrames + jsRound(a.off * fps) }
    let base = l < t.lines.count ? phraseStart(t.lines[l], a.phrase) : t.durationInFrames + 1000 + Double(l) * 100 + Double(a.phrase) * 10
    return base + jsRound(a.off * fps)
  }
}

/// 工程の終わりの状態 (時刻に関係なく、すべての変化が終わった後の値)。init <前の工程 で使う。
/// 同じ値を何度も変えるときは最後 (時刻の順) の値。前の工程の読み上げの時刻が分かるときは実際の時刻で並べ、
/// 分からないとき (時刻表が無い) は 行.句+秒 の順の近似で並べる
/// visiting はたどっている途中の工程 (init <前 の循環で止めるため。段数の上限は無い)
func cueEndState(_ name: String, _ places: [String: (x: Double, y: Double, s: Double)], visiting: Set<String> = []) -> CueState {
  let p = loadCue(name)
  var s = cueStartState(p, places, visiting: visiting.union([name]))
  let ordered: [(lineNo: Int, at: CueAnchor, cmd: CueCmd)]
  if let frameOf = cueFrameOf(name) {
    ordered = p.cues.enumerated().sorted { (frameOf($0.element.at), $0.offset) < (frameOf($1.element.at), $1.offset) }.map(\.element)
  } else {
    ordered = p.cues.enumerated().sorted { ($0.element.at.order, $0.offset) < ($1.element.at.order, $1.offset) }.map(\.element)
  }
  for (_, _, cmd) in ordered {
    switch cmd {
    case let .num(k, v, _, _): s.num[k] = v
    case let .str(k, v): s.str[k] = v
    case let .countdown(k, _, b, _): s.str[k] = b
    case let .move(o, pl, _): if let q = places[pl] { s.num["\(o).x"] = q.x; s.num["\(o).y"] = q.y; s.num["\(o).s"] = q.s }
    case let .drop(o, _): s.num["\(o).vis"] = 1; s.num["\(o).dy"] = 0
    // カードの中の手が最後にいた点 (次の工程の始まりの手の位置。カードを縮めたら初めの点に戻す)
    case let .hand(who, pt, _, _) where who == "C": s.str["C.at"] = pt
    case .shrink: s.str["C.at"] = nil
    default: break
    }
  }
  return s
}

func cueStartState(_ p: CueProgram, _ places: [String: (x: Double, y: Double, s: Double)], visiting: Set<String> = []) -> CueState {
  var s = CueState()
  // init <前 は循環で止めるほか、段数も限る (工程の数だけ再帰するので、数百個をつないだキューでスタックがあふれないように)
  if let prev = p.inherit, !visiting.contains(prev), visiting.count < 200 { s = cueEndState(prev, places, visiting: visiting) }
  // 前の工程の一時的な値 (手の揺れ・カード) は引き継がない
  for k in s.num.keys where k.hasPrefix("H.") || k.hasPrefix("C.") || k.hasPrefix("card.") { s.num[k] = nil }
  if p.inherit == nil { s.str["C.at"] = nil }
  for (k, v) in p.initNum { s.num[k] = v }
  for (k, v) in p.initStr { s.str[k] = v }
  for (o, pl) in p.initPlace { if let q = places[pl] { s.num["\(o).x"] = q.x; s.num["\(o).y"] = q.y; s.num["\(o).s"] = q.s } }
  return s
}

// ---------- 実行 ----------

private func easeIO(_ u: Double) -> Double { u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2 }
private func clockSec(_ s: String) -> Double? {
  let a = s.split(separator: ":", omittingEmptySubsequences: false).compactMap { cueNum($0) }
  // 100 時間未満だけ (大きすぎる値で表示の計算が落ちないように)
  guard a.count == 2, s.split(separator: ":", omittingEmptySubsequences: false).count == 2 else { return nil }
  let v = a[0] * 60 + a[1]
  return abs(v) < 360000 ? v : nil
}

/// キューの工程を描く。name は cues/<name>.cue
public func CueScene(_ name: String, _ bind: CueBinding) {
  let n = useNarration()
  let st = useStage()
  let fps = n.fps
  let prog = loadCue(name)
  var issues = prog.errors
  // 注意 (? で出す。jgv check は止めない)
  var soft: [String] = []
  // 時刻を推定で埋めた (句が足りない) キューの行。その行が起こす重なり・遅れも推定によるものなので注意にとどめる
  var estimated: Set<Int> = []
  /// 推定の時刻 (estimated の行) が起こす問題は注意 (?) にとどめ、それ以外は誤り (!) にする
  func report(_ lns: [Int], _ m: String) { if lns.contains(where: estimated.contains) { soft.append(m + " (句の時刻が推定のため)") } else { issues.append(m) } }
  let end = n.durationInFrames
  /// $キー:既定の文 → 台本の strings の訳
  func tr(_ t: String) -> String {
    guard t.hasPrefix("$") else { return t }
    guard let c = t.firstIndex(of: ":") else { return n.t(String(t.dropFirst())) }   // parts の名前は : を含められないので $キー だけで書く
    return n.t(String(t[t.index(after: t.startIndex)..<c]), String(t[t.index(after: c)...]))
  }
  // end±秒 も L.P±秒 (atPhrase) と同じく、ずらす秒をフレームに丸める
  func frameOf(_ a: CueAnchor) -> Double { a.line.map { n.atPhrase($0, a.phrase, a.off) } ?? end + jsRound(a.off * fps) }
  func sec(_ x: Double) -> String { String(format: "%.2f", x / fps) }

  // ---- 名前と時刻の確かめ ----
  let known = bind.keys.union(["smile", "card.enter", "card.exit"])
  func knownKey(_ k: String) -> Bool {
    known.contains(k) || k.hasPrefix("H.") || k.hasPrefix("C.") || bind.objects.contains { k.hasPrefix($0 + ".") }
  }
  func checkAnchor(_ ln: Int, _ a: CueAnchor) {
    guard let l = a.line else { return }
    if n.lines.isEmpty { issues.append("\(ln): この工程には読み上げる行が無いので、行.句 の時刻は使えない (台本に文を足すか、この命令を消す)") }
    else if l >= n.lines.count { issues.append("\(ln): 行 \(l) は無い (行は 0〜\(n.lines.count - 1))") }
    // 行はあるが句が足りない: 言語版で句の数が違うときに起きる。時刻は推定で埋めるので注意にとどめる
    else if a.phrase >= max(1, n.lines[l].phrases.count) && !CueCheck.languageVariant { issues.append("\(ln): 行 \(l) の句 \(a.phrase) は無い (句は 0〜\(max(1, n.lines[l].phrases.count) - 1)。秒ではなく 行.句 で書く)") }
    else if a.phrase >= max(1, n.lines[l].phrases.count) { estimated.insert(ln); soft.append("\(ln): 行 \(l) の句 \(a.phrase) は無い (句は 0〜\(max(1, n.lines[l].phrases.count) - 1))") }
  }
  for (ln, a, cmd) in prog.cues {
    checkAnchor(ln, a)
    // @時刻 の側
    switch cmd {
    case let .num(_, _, _, u), let .fx(_, _, _, u): if let u { checkAnchor(ln, u) }
    case let .countdown(_, _, _, u), let .wave(_, _, _, u): checkAnchor(ln, u)
    case let .card(st), let .notes(st), let .parts(st): for x in st { checkAnchor(ln, x.1) }
    default: break
    }
    switch cmd {
    case let .num(k, _, _, _), let .str(k, _), let .countdown(k, _, _, _), let .wave(k, _, _, _):
      if !knownKey(k) { issues.append("\(ln): \(k) は binding に無い値") }
    case let .move(o, pl, _):
      if !bind.objects.contains(o) { issues.append("\(ln): \(o) は動かせる物ではない") }
      if bind.places[pl] == nil { issues.append("\(ln): 置き場所 \(pl) が無い") }
    case let .drop(o, _): if !bind.objects.contains(o) { issues.append("\(ln): \(o) は動かせる物ではない") }
    default: break
    }
  }
  for k in (Array(prog.initNum.keys) + Array(prog.initStr.keys)).sorted() where !knownKey(k) { issues.append("init: \(k) は binding に無い値") }
  for (o, pl) in prog.initPlace {
    if !bind.objects.contains(o) { issues.append("init: \(o) は動かせる物ではない") }
    if bind.places[pl] == nil { issues.append("init: 置き場所 \(pl) が無い") }
  }
  if let prev = prog.inherit, loadCue(prev).errors.contains(where: { $0.hasSuffix("がありません") }) { issues.append("init: <\(prev) の cues/\(prev).cue が無い") }
  // init <前 の循環 (A <B, B <A など)
  do {
    var seen: Set<String> = [name], cur = prog.inherit
    while let c = cur {
      if seen.contains(c) { issues.append("init: <\(prog.inherit!) をたどると \(c) に戻る (init <前 が循環している)"); break }
      seen.insert(c)
      cur = loadCue(c).inherit
    }
  }
  // 人物を描かない型では、手の定位置 rest は binding に書く (無いと人物の右手の位置に指・道具が出る)
  if bind.hand != .presenter, bind.points["rest"] == nil { issues.append("binding: hand が .presenter ではないので points に rest (手の定位置) が要る") }

  // ---- 時間変化の表 ----
  struct Seg { var key: String; var t0: Double; var t1: Double; var to: Double; var lift: Double; var ln: Int }
  var segs: [Seg] = []
  var strs: [(t: Double, key: String, v: String)] = []
  var cds: [(t0: Double, t1: Double, key: String, a: Double, b: Double)] = []
  var waves: [(t0: Double, t1: Double, key: String, amp: Double, per: Double)] = []
  var drops: [(t: Double, o: String, h: Double)] = []
  var hands: [String: [(arrive: Double, dur: Double, pt: String, press: Bool, ln: Int)]] = ["H": [], "C": []]
  var effects: [(ln: Int, t0: Double, t1: Double, kind: String, pt: String, text: String)] = []
  var cardSteps: [CloseUpStep] = []
  var noteItems: [(label: String, at: Double)] = []
  var partItems: [PartsListItem] = []
  var cardAt: Double? = nil
  var shrink: (t: Double, dur: Double, pt: String)? = nil
  for (ln, a, cmd) in prog.cues {
    let t = frameOf(a)
    /// @時刻 (終わり) が始まりより前なら誤り (何も起きない・一瞬で変わる)
    func untilFrame(_ u: CueAnchor, _ what: String) -> Double {
      let t1 = frameOf(u)
      if t1 < t - 0.5 { issues.append("\(ln): \(what) の @時刻 (\(sec(t1))s) が始まり (\(sec(t))s) より前") }
      return t1
    }
    switch cmd {
    case let .num(k, v, d, until): segs.append(Seg(key: k, t0: t, t1: until.map { untilFrame($0, k) } ?? t + d * fps, to: v, lift: 0, ln: ln))
    case let .str(k, v): strs.append((t, k, v))
    case let .countdown(k, a1, b1, until): cds.append((t, untilFrame(until, k), k, clockSec(a1) ?? 0, clockSec(b1) ?? 0))
    case let .wave(k, amp, per, until): waves.append((t, untilFrame(until, k), k, amp, per))
    case let .move(o, pl, d):
      if let q = bind.places[pl] {
        segs.append(Seg(key: "\(o).x", t0: t, t1: t + d * fps, to: q.x, lift: 0, ln: ln))
        segs.append(Seg(key: "\(o).y", t0: t, t1: t + d * fps, to: q.y, lift: 60, ln: ln))
        segs.append(Seg(key: "\(o).s", t0: t, t1: t + d * fps, to: q.s, lift: 0, ln: ln))
      }
    case let .drop(o, h): drops.append((t, o, h))
    case let .hand(who, pt, d, press): hands[who, default: []].append((t, d, pt, press, ln))
    case let .card(steps):
      cardAt = t
      cardSteps = steps.map { CloseUpStep(tr($0.0), at: frameOf($0.1)) }
    case let .shrink(pt, d): shrink = (t, d, pt)
    case let .notes(items): noteItems = items.map { (label: tr($0.0), at: frameOf($0.1)) }
    case let .parts(items):
      partItems = items.map { it in
        let f = it.0.split(separator: ":", maxSplits: 2).map(String.init) + ["", "", ""]
        return PartsListItem(letter: f[0], name: tr(f[1]), qty: f[2], at: frameOf(it.1))
      }
    case let .fx(kind, pt, text, until): effects.append((ln, t, until.map { untilFrame($0, kind) } ?? (kind == "check" ? end : (kind == "pulse" ? t + 0.9 * fps : end)), kind, pt, tr(text)))
    }
  }
  // カードの中の手 (C) は拡大カードの中にだけ描くので、人物の型では card 命令が要る
  if bind.hand == .presenter, cardAt == nil, let h = hands["C"]?.first { issues.append("\(h.ln): C>\(h.pt) を使っているが card 命令が無い (カードの中の手は拡大カードの中にだけ描く)") }
  // 手を描かない型 (手元俯瞰) では、左手 C の定位置 c.away も binding に書く (無いと拡大カードの右の画面の中の点になる)
  if bind.hand == .none, !(hands["C"] ?? []).isEmpty, bind.points["c.away"] == nil { issues.append("binding: hand が .none で C を使うので points に c.away (C の定位置) が要る") }
  // ポイントメモ・部品リストの既定の位置は横型の値なので、縦型では binding に点を書く
  if n.portrait, !noteItems.isEmpty, bind.points["notes"] == nil { issues.append("binding: 縦型では points に notes (ポイントメモの位置) が要る (既定の (1000, 270) は横型の値)") }
  if n.portrait, !partItems.isEmpty, bind.points["parts"] == nil { issues.append("binding: 縦型では points に parts (部品リストの位置) が要る (既定の (1340, 250) は横型の値)") }
  // 同じ値の変化は時刻の順に当てはめる (書いた順ではなく。終わりの状態 cueEndState と同じ順)
  segs = segs.enumerated().sorted { ($0.element.t0, $0.offset) < ($1.element.t0, $1.offset) }.map(\.element)
  let base = cueStartState(prog, bind.places)

  func state(_ f: Double) -> CueState {
    var s = base
    var lifts: [String: Double] = [:]
    for g in segs where f > g.t0 || (g.t1 <= g.t0 && f >= g.t0) {
      let from = s.num[g.key] ?? 0
      let u = g.t1 > g.t0 ? min(1, max(0, (f - g.t0) / (g.t1 - g.t0))) : 1
      let e = easeIO(u)
      s.num[g.key] = from + (g.to - from) * e
      if g.lift > 0 && u < 1 { lifts[g.key] = sin(Double.pi * e) * g.lift }
    }
    for (k, l) in lifts { s.num[k] = (s.num[k] ?? 0) - l }
    // 終わりの時刻 (揺れは 0) では足さない (@end の揺れが、終わりの状態に値 0 の名前を残して S→S の「片方だけ」にならないように)
    for w in waves where f >= w.t0 && f < w.t1 {
      let env = min(1, (f - w.t0) / (0.25 * fps), (w.t1 - f) / (0.25 * fps))
      s.num[w.key] = (s.num[w.key] ?? 0) + w.amp * sin(2 * Double.pi * (f - w.t0) / (w.per * fps)) * env
    }
    for d in drops where f >= d.t {
      s.num["\(d.o).vis"] = 1
      s.num["\(d.o).dy"] = -d.h * (1 - dropAt(f, fps, d.t))
    }
    var last: [String: Double] = [:]
    for x in strs where f >= x.t && x.t >= (last[x.key] ?? -1e9) { s.str[x.key] = x.v; last[x.key] = x.t }
    for c in cds where f >= c.t0 && c.t0 >= (last[c.key] ?? -1e9) {
      let u = min(1, max(0, (f - c.t0) / max(1, c.t1 - c.t0)))
      let v = Int((c.a + (c.b - c.a) * u).rounded(.up))
      s.str[c.key] = String(format: "%d:%02d", v / 60, v % 60)
      last[c.key] = c.t0
    }
    return s
  }

  /// 座標の数 (有限で、大きすぎないものだけ。inf / nan / 1e999 は読めない値にする)
  func cueCoord(_ s: Substring) -> Double? {
    guard let v = Double(s.trimmingCharacters(in: .whitespaces)), v.isFinite, abs(v) < 1e7 else { return nil }
    return v
  }

  func point(_ spec: String, _ s: CueState) -> Pt? {
    if spec.hasPrefix("(") {
      let a = spec.trimmingCharacters(in: CharacterSet(charactersIn: "()")).split(separator: ",").compactMap { cueCoord($0) }
      return a.count == 2 ? Pt(a[0], a[1]) : nil
    }
    var name = spec
    var d = Pt(0, 0)
    if let plus = spec.firstIndex(of: "+") {
      name = String(spec[..<plus])
      let a = spec[spec.index(after: plus)...].split(separator: ",").compactMap { cueCoord($0) }
      if a.count == 2 { d = Pt(a[0], a[1]) }
    }
    let p: Pt?
    if let b = bind.points[name] { p = b(s) } else {
      switch name {
      case "rest": p = st.pose.restR
      case "gesture": p = st.pose.gestureR
      case "c.away": let b = useGuide().layout.closeUp; p = Pt(b.x + b.w + 120, b.y + b.h / 2 + 60)
      // 袖の腕の付け根: カードの右下の外 (手の右下について動く)
      case "c.sleeve": let b = useGuide().layout.closeUp; p = Pt(min(b.x + b.w + 60, s["C.x"] + 300), b.y + b.h + 40)
      default: p = nil
      }
    }
    return p.map { Pt($0.x + d.x, $0.y + d.y) }
  }
  for (who, hs) in hands { for h in hs where point(h.pt, base) == nil { issues.append("\(h.ln): \(who) の点 \(h.pt) が無い") } }
  for e in effects where point(e.pt, base) == nil { issues.append("\(e.ln): 点 \(e.pt) が無い") }
  if let sh = shrink, point(sh.pt, base) == nil { issues.append("shrink の点 \(sh.pt) が無い") }

  // ---- 手: 着く時刻に点へ。着いた後は点に付いていく。右手は最後に自動で定位置に戻る ----
  // 手の命令も書いた順ではなく着く時刻の順に (segs と同じ。end-… の行を先に書いても動きが跳ばない)
  for who in hands.keys { hands[who] = hands[who]!.enumerated().sorted { ($0.element.arrive, $0.offset) < ($1.element.arrive, $1.offset) }.map(\.element) }
  if let last = hands["H"]!.last, last.pt != "rest" { hands["H"]!.append((end - 0.6 * fps, 0.45, "rest", false, 0)) }
  func handAt(_ who: String, _ f: Double) -> Pt {
    var target = who == "H" ? "rest" : (base.str["C.at"] ?? "c.away")
    var press: (Double, Bool) = (0, false)
    func at(_ t: String, _ g: Double) -> Pt {
      let s = state(g)
      var p = point(t, s) ?? st.pose.restR
      p = Pt(p.x + s["\(who).dx"], p.y + s["\(who).dy"])
      if press.1 && g >= press.0 && g < press.0 + 0.3 * fps {
        let k = sin(Double.pi * (g - press.0) / (0.3 * fps))
        p = Pt(p.x + 4 * k, p.y + 7 * k)
      }
      return p
    }
    for h in hands[who] ?? [] {
      let start = h.arrive - h.dur * fps
      if f < start { return at(target, f) }
      if f < h.arrive {
        let from = at(target, start)
        let to = at(h.pt, f)
        let e = easeIO((f - start) / max(1, h.arrive - start))
        return Pt(from.x + (to.x - from.x) * e, from.y + (to.y - from.y) * e - sin(Double.pi * e) * 20)
      }
      target = h.pt
      press = (h.arrive, h.press)
    }
    return at(target, f)
  }

  // ---- 描く ----
  let f = n.frame
  var s = state(f)
  let hand = handAt("H", f)
  let chand = handAt("C", f)
  s.num["H.x"] = hand.x; s.num["H.y"] = hand.y; s.num["C.x"] = chand.x; s.num["C.y"] = chand.y
  // 押している間 (押した点の名前) と、指の波紋 (0〜1)
  var tapT = 0.0
  for h in hands["H"] ?? [] where h.press && f >= h.arrive && f < h.arrive + 0.35 * fps {
    let t = (f - h.arrive) / (0.35 * fps)
    tapT = t
    if t < 0.4 { s.str["pressed"] = h.pt.split(separator: "+").first.map(String.init) }
  }
  func fade(_ e: (ln: Int, t0: Double, t1: Double, kind: String, pt: String, text: String)) -> Double {
    min(1, max(0, (e.t1 + 0.4 * fps - f) / (0.4 * fps)), max(0, (f - e.t0) / (0.25 * fps)))
  }
  func drawFx(card: Bool, kinds: Set<String>) {
    for e in effects where kinds.contains(e.kind) && e.pt.hasPrefix("c.") == card && f >= e.t0 && f <= e.t1 + 0.4 * fps {
      guard let p = point(e.pt, s) else { continue }
      let o = fade(e)
      LayoutProbe.tagged("L\(e.ln) \(e.kind)") {
        switch e.kind {
        case "steam": Steam(x: p.x, y: p.y, count: 3, height: 90, opacity: 0.55 * o)
        case "sparkle": Sparkles(x: p.x - 80, y: p.y - 60, w: 160, h: 120, on: o)
        case "say": g(opacity: o) { Callout(x: p.x, y: p.y, text: e.text, at: e.t0) }
        case "timer":
          g(opacity: o, transform: [.translate(0, sin(f * 0.12) * 3)]) {
            ArcTimer(x: p.x, y: p.y, r: 62, progress: min(1, (f - e.t0) / max(1, e.t1 - e.t0)), label: e.text, size: 34)
          }
        case "pulse": if f <= e.t1 { Pulse(x: p.x, y: p.y, r: 40, period: 0.9, count: 2) }
        case "check": CheckBadge(x: p.x, y: p.y, at: e.t0, r: 38)
        default: break
        }
      }
    }
  }
  Stage {
    bind.draw(s)
    drawFx(card: false, kinds: ["steam", "sparkle"])
    if bind.hand == .presenter { Presenter(handL: st.pose.restL, handR: hand, smile: s["smile"]) }
    bind.front(s)
    if !noteItems.isEmpty, let p = point("notes", s) ?? Optional(Pt(1000, 270)) { StepNotes(x: p.x, y: p.y, w: 820, items: noteItems) }
    if !partItems.isEmpty, let p = point("parts", s) ?? Optional(Pt(1340, 250)) { PartsList(x: p.x, y: p.y, w: 480, title: n.t("parts.title", guideLabels(useGuide().lang).parts), items: partItems) }
    drawFx(card: false, kinds: ["say", "timer", "pulse", "check"])
    if let cardAt {
      let sh = shrink.map { min(1, max(0, (f - $0.t) / ($0.dur * fps))) } ?? 0
      if sh < 0.999 {
        let box = useGuide().layout.closeUp
        let c = Pt(box.x + box.w / 2, box.y + box.h / 2)
        let to = shrink.flatMap { point($0.pt, s) } ?? c
        let tc = mix(c, to, easeIO(sh))
        let k = 1 - 0.92 * easeIO(sh)
        g(opacity: 1 - sh, transform: [.translate(tc.x, tc.y), .scale(k), .translate(-c.x, -c.y)]) {
          CloseUp(steps: cardSteps, at: cardAt, enter: (base.num["card.enter"] ?? 1) != 0,
                  exit: (base.num["card.exit"] ?? 1) != 0 && shrink == nil) {
            bind.card(s)
            drawFx(card: true, kinds: ["steam", "sparkle"])
            if (hands["C"] ?? []).count > 0 || base.str["C.at"] != nil, let from = point("c.sleeve", s) { SleeveArm(from: from, to: chand, bend: 0.15) }
            drawFx(card: true, kinds: ["say", "timer", "pulse", "check"])
          }
        }
      }
    }
    switch bind.hand {
    case .finger: Tap(x: hand.x, y: hand.y, press: tapT)
    case .cursor: Cursor(x: hand.x, y: hand.y, click: tapT)
    case .presenter, .none: break
    }
  }

  // ---- jgv check: 工程の最初のフレームで 1 回だけ、手の時刻表・計算した状態・問題を文字で残す ----
  if CueCheck.active && f < 1.5 {
    let shoulder = Pt(st.presenter.x + 60, st.counterY - 330)
    let reachMax = 760.0
    let limit = end - 0.5 * fps
    var table: [String] = []
    for who in ["H", "C"] {
      var prev = who == "H" ? "rest" : (base.str["C.at"] ?? "c.away")
      for h in hands[who] ?? [] {
        let start = h.arrive - h.dur * fps
        table.append("  \(who) \(sec(start))-\(sec(h.arrive))s \(prev)→\(h.pt)\(h.press ? " (押す)" : "")\(h.ln > 0 ? " L\(h.ln)" : " (自動)")")
        prev = h.pt
        if who == "H" && h.ln > 0 && bind.hand == .presenter {
          let p = handAt("H", h.arrive)
          let d = hypot(p.x - shoulder.x, p.y - shoulder.y)
          if d > reachMax { issues.append("\(h.ln): 手が遠い \(d.isFinite ? String(Int(d)) : "∞")px (目安 \(Int(reachMax)) まで) at \(h.pt)") }
        }
      }
    }
    // 手が点から離れ始めるとき、その点がまだ動いている (つまんだ物を動かしている途中で手を離している)
    for who in ["H", "C"] {
      let hs = hands[who] ?? []
      for (a, b) in zip(hs, hs.dropFirst()) {
        let leave = b.arrive - b.dur * fps
        // 前の動きが着く前に次の動きが始まる (手が途中で跳ぶ)。最後の自動の戻りなら、前の動きが遅すぎる
        if leave < a.arrive - 0.5 {
          report(b.ln > 0 ? [a.ln, b.ln] : [a.ln], b.ln > 0
            ? "\(b.ln): \(who) が \(b.pt) へ \(sec(leave))s に動き始めるが、\(a.pt) に着く (\(sec(a.arrive))s) より前 (動きが重なる)"
            : "L\(a.ln) の後: \(who) が \(a.pt) に着く (\(sec(a.arrive))s) より前の \(sec(leave))s に定位置へ戻り始める (終わりの 1.05 秒前までに着くようにする)")
          continue
        }
        if let p1 = point(a.pt, state(leave)), let p2 = point(a.pt, state(leave + 0.3 * fps)), hypot(p2.x - p1.x, p2.y - p1.y) > 3 {
          report(b.ln > 0 ? [a.ln, b.ln] : [a.ln], "\(b.ln > 0 ? "\(b.ln)" : "L\(a.ln) の後"): \(who) が \(a.pt) から \(sec(leave))s に\(b.ln > 0 ? "" : "定位置へ戻るために")離れるが、\(a.pt) はまだ動いている")
        }
      }
    }
    // 指・カーソルで押した後、そのまま止まっている (押し続けているように見える)。見せ方の好みもあるので注意 (?) にする
    var notes: [String] = []
    // 工程の始まりより 0.15 秒以上前に動き始める手は、工程の頭で飛んで見える (前の工程の終わりの位置から動けない)
    for (who, hs) in hands {
      for h in hs where h.ln > 0 && h.arrive - h.dur * fps < -0.15 * fps {
        notes.append("\(h.ln): \(who) が工程の始まりより前 (\(sec(h.arrive - h.dur * fps))s) に \(h.pt) へ動き始める (頭で手が飛んで見える。~秒 を短くするか、着く時刻を後にする)")
      }
    }
    if bind.hand == .finger || bind.hand == .cursor {
      let hs = hands["H"] ?? []
      for (i, h) in hs.enumerated() where h.press {
        let leave = i + 1 < hs.count ? hs[i + 1].arrive - hs[i + 1].dur * fps : limit
        if leave - h.arrive > 1.0 * fps {
          notes.append("\(h.ln): \(bind.hand == .finger ? "指" : "カーソル") が \(h.pt) を押した後 \(sec(leave - h.arrive))s そのまま (押し続けて見える。押したら H>rest などで離す)")
        }
      }
    }
    for (ln, a, _) in prog.cues where frameOf(a) > limit { report([ln], "\(ln): 終わりの 0.5 秒前 (\(sec(limit))s) より後に始まる") }
    for g in segs where g.t1 > limit { report([g.ln], "\(g.ln): \(g.key) が終わりの 0.5 秒前 (\(sec(limit))s) より後まで変わる") }
    var byKey: [String: [Seg]] = [:]
    for g in segs { byKey[g.key, default: []].append(g) }
    for (k, gs) in byKey { for (a, b) in zip(gs, gs.dropFirst()) where b.t0 < a.t1 - 0.5 { report([a.ln, b.ln], "\(b.ln): \(k) の変化が前の変化 (L\(a.ln)) と重なる") } }
    let he = handAt("H", limit)
    if let r = point("rest", state(limit)), hypot(he.x - r.x, he.y - r.y) > 2 { issues.append("右手が終わりの 0.5 秒前 (\(sec(limit))s) に定位置に戻っていない") }
    func flat(_ s: CueState) -> [String: String] {
      var d: [String: String] = [:]
      for (k, v) in s.num where !(k.hasPrefix("H.") || k.hasPrefix("C.") || k.hasPrefix("card.") || k.hasSuffix(".dy")) { d[k] = String(format: "%g", (v * 100).rounded() / 100) }
      for (k, v) in s.str where k != "C.at" { d[k] = v }
      return d
    }
    /// 同じ注意を 1 回だけ (順は保つ)
    func uniq(_ a: [String]) -> [String] { var seen: Set<String> = []; return a.filter { seen.insert($0).inserted } }
    func dump(_ d: [String: String]) -> String { d.keys.sorted().map { "\($0)=\(d[$0]!)" }.joined(separator: " ") }
    let s0 = flat(state(0)), s1 = flat(state(end))
    CueCheck.cardOut[n.sceneIndex] = cardAt != nil && shrink == nil && base.num["card.exit"] == 0
    CueCheck.cardIn[n.sceneIndex] = cardAt != nil && base.num["card.enter"] == 0
    CueCheck.start[n.sceneIndex] = s0
    CueCheck.end[n.sceneIndex] = s1
    CueCheck.report[n.sceneIndex] = issues.map { "  ! \($0)" } + uniq(soft + notes).map { "  ? \($0)" } + table + ["  start: \(dump(s0))", "  end:   \(dump(s1))"]
  }
}
