// script.json から読み上げ音声を生成し、タイムライン (.jgv/timeline.json) と字幕ファイル (out/subtitles.srt) を書き出す。
//
// usage: jgv tts [script.json] [--keep-audio]
// 日本語の台本は、最後に読みの区切りの誤りと、漢数字と助数詞の読みを警告する (jgv yomi --warn-only と同じ)
//
// 音声は script.json の tts.engine で選ぶ:
//   "apple"   macOS の AVSpeechSynthesizer (既定 / オフライン / 無料)。プレミアム/ニューラル音声 (Sakura など) が使える。
//             voice: "auto" で最高品質を自動選択。書き出した動画は個人的・非商用の利用に限る (macOS の使用許諾)
//   "command" tts.command に書いたコマンドで 1 行ずつ音声ファイルを作る (クラウドの TTS などを自分でつなぐ)。
//             引数の {text} {out} {lang} {voice} を置き換え、同じ値を環境変数 TTS_TEXT / TTS_OUT / TTS_LANG / TTS_VOICE にも入れる
//   "google"  Google Cloud Text-to-Speech。環境変数 GOOGLE_TTS_API_KEY に API キー (か GOOGLE_APPLICATION_CREDENTIALS にサービスアカウントの鍵のパス) を入れるだけで使える (voice は jgv voices --google)
//   "azure"   Azure AI Speech。環境変数 AZURE_SPEECH_KEY と AZURE_SPEECH_REGION (voice は jgv voices --azure)
//   "openai"  OpenAI の音声合成。環境変数 OPENAI_API_KEY (voice は alloy など。tts.model / tts.instructions。クレジットの既定は「AI 音声」)
//   "amazon"  Amazon Polly。環境変数 AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_REGION (voice は jgv voices --amazon。tts.pollyEngine で neural など)
import CryptoKit
import Foundation
import JGVCore

public enum TTS {
  struct Job {
    var speak: String
    var rawPath: URL
    var wavPath: URL
  }

  /// 言語版の台本 (script.<言語>.json) で、画面の文言 (strings) が訳されていないものを知らせる。
  /// 基準の台本 (script.json) と同じ文のままのもの・無いもの、キュー ($キー) と visual (n.t("キー")) で使うのに strings に無いもの
  static func warnUntranslated(root: URL, scriptURL: URL, script: JSON, lang: String) {
    guard scriptURL.lastPathComponent != "script.json", scriptURL.lastPathComponent.hasPrefix("script."),
          let base = try? JSON.read(root.appendingPathComponent("script.json")) else { return }
    func primary(_ l: String) -> String { String(l.lowercased().split(separator: "-").first ?? "") }
    guard primary(base["lang"]?.string ?? "ja-JP") != primary(lang) else { return }
    let mine = Dictionary((script["strings"]?.object ?? []).map { ($0.0, $0.1.string ?? "") }, uniquingKeysWith: { a, _ in a })
    var keys = Set((base["strings"]?.object ?? []).map(\.0))
    // キューの $キー と、Swift の n.t("キー") / .t("キー", …) で使うキー
    let fm = FileManager.default
    for (dir, pattern) in [("cues", "\\$([A-Za-z][A-Za-z0-9_.-]*)"), ("visuals", "\\.t\\(\"([^\"]+)\"")] {
      let d = root.appendingPathComponent(dir)
      for f in (try? fm.contentsOfDirectory(atPath: d.path)) ?? [] {
        guard let text = try? String(contentsOf: d.appendingPathComponent(f), encoding: .utf8),
              let re = try? NSRegularExpression(pattern: pattern) else { continue }
        for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
          if let r = Range(m.range(at: 1), in: text) { keys.insert(String(text[r])) }
        }
      }
    }
    let baseStrings = Dictionary((base["strings"]?.object ?? []).map { ($0.0, $0.1.string ?? "") }, uniquingKeysWith: { a, _ in a })
    let missing = keys.filter { mine[$0] == nil }.sorted()
    let same = keys.filter { k in mine[k].map { !$0.isEmpty && $0 == baseStrings[k] } ?? false }.sorted()
    if !missing.isEmpty { note("WARN: \(scriptURL.lastPathComponent) の strings に無いキーがあります (画面には既定の文がそのまま出ます): \(missing.joined(separator: ", "))") }
    if !same.isEmpty { note("WARN: \(scriptURL.lastPathComponent) の strings が script.json と同じ文のままです (未翻訳?): \(same.joined(separator: ", "))") }
    // キューに $キー を使わずに直接書いた文字 (say / card / notes / timer など) は訳されない。
    // 漢字・かなを使わない言語の台本なのに、漢字・かなの直書きがあれば知らせる
    if !["ja", "zh"].contains(primary(lang)) {
      var hits: [String] = []
      let cues = root.appendingPathComponent("cues")
      let keyRe = try? NSRegularExpression(pattern: "\\$[A-Za-z][A-Za-z0-9_.-]*(:[^@|;]*)?")
      for f in ((try? fm.contentsOfDirectory(atPath: cues.path)) ?? []).sorted() where f.hasSuffix(".cue") {
        guard let text = try? String(contentsOf: cues.appendingPathComponent(f), encoding: .utf8) else { continue }
        for (i, raw) in text.components(separatedBy: "\n").enumerated() {
          var line = String(raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
          if let keyRe { line = keyRe.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "") }
          if line.unicodeScalars.contains(where: { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }) {
            hits.append("cues/\(f):\(i + 1)")
          }
        }
      }
      if !hits.isEmpty {
        note("WARN: \(scriptURL.lastPathComponent) (\(lang)) なのに、キューに漢字・かなを直接書いた文字があります (訳されずにそのまま出ます。$キー:既定の文 にして strings で訳す): \(hits.prefix(10).joined(separator: ", "))\(hits.count > 10 ? " ほか \(hits.count - 10) 件" : "")")
      }
    }
  }

  public static func run(_ args: [String]) throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    try Project.requireProject(root)
    let scriptArg = args.first { !$0.hasPrefix("--") } ?? "script.json"
    let scriptURL = URL(fileURLWithPath: scriptArg, relativeTo: root).standardizedFileURL
    let keepAudio = args.contains("--keep-audio")
    // build-langs が中断で残した控えは、build-langs の外で timeline を作り直すなら要らない (後で古い timeline に戻されないように消す)
    if !args.contains("--from-build-langs") {
      let backup = Project.workDir(root).appendingPathComponent("build-langs-backup")
      // ただし、控えを作った build-langs がまだ動いているなら消さない
      let ownerFile = backup.appendingPathComponent("owner")
      let running = Safety.isRegularFile(ownerFile) && ((try? String(contentsOf: ownerFile, encoding: .utf8)).map(Project.markIsAlive) ?? false)
      // .jgv/ がシンボリックリンクなら触らない (この後の確かめで止まる)
      if FileManager.default.fileExists(atPath: backup.path) && (try? Safety.requireNoSymlinks(under: root, backup)) != nil && !running { try? FileManager.default.removeItem(at: backup) }
    }
    let script = try JSON.read(scriptURL)

    let fps = script["fps"]?.double ?? 30
    let width = script["width"]?.double ?? 1920
    let height = script["height"]?.double ?? 1080
    let gap = script["gap"]?.double ?? 0.35
    let padStart = script["padStart"]?.double ?? 0.5
    let padEnd = script["padEnd"]?.double ?? 1.0
    let sceneGap = script["sceneGap"]?.double ?? 0.6
    // 間の秒は 0〜60 秒 (大きすぎる値で字幕の時刻の計算が落ちたり、何時間もの無音を作ったりしないように)
    for (k, v) in [("gap", gap), ("padStart", padStart), ("padEnd", padEnd), ("sceneGap", sceneGap)] where !v.isFinite || v < 0 || v > 60 {
      throw ToolError("script.json の \(k) は 0〜60 (秒) にしてください (\(v))")
    }
    for (k, v) in [("fps", fps), ("width", width), ("height", height)] where !v.isFinite || v <= 0 {
      throw ToolError("script.json の \(k) は正の数にしてください (\(v))")
    }
    let LAYOUTS = ["guide", "guide-screen", "guide-topdown", "guide-manual"]
    if let l = script["layout"], !LAYOUTS.contains(l.string ?? "") {
      throw ToolError("layout \"\(l.string ?? l.description)\" は使えません。\(LAYOUTS.joined(separator: " / ")) のどれかを指定してください")
    }

    let style = script["style"] ?? .object([])
    let lang = script["lang"]?.string ?? "ja-JP"
    let wide = (script["lang"]?.string ?? "ja").range(of: "^(ja|zh|ko)", options: .regularExpression) != nil // 文字が全角幅の言語は字幕 1 枚の文字数を少なくする
    // 0 や小数 (切り捨てて 0) は字幕の分割で 0 で割って落ちるので、先に止める
    if let m = style["maxCharsPerCaption"], !(m.double.map { $0 >= 1 } ?? false) {
      throw ToolError("style.maxCharsPerCaption は 1 以上の数で書いてください: \(m.description)")
    }
    let maxChars = style["maxCharsPerCaption"]?.int ?? (wide ? 28 : 64)
    var tts: JSON = ["engine": "apple"]
    for (k, v) in script["tts"]?.object ?? [] { tts[k] = v }
    let engine = tts["engine"]?.string ?? "apple"
    let isJa = lang.hasPrefix("ja")

    // engine ごとに書ける設定 (別の engine の設定が混ざっていたら、効かないまま気づかないので止める)
    let TTS_KEYS: [String: [String]] = [
      "apple": ["engine", "voice", "rate", "pitch"],
      "command": ["engine", "command", "voice", "format", "parallel"],
      "google": ["engine", "voice"] + CloudTTS.settings("google"),
      "azure": ["engine", "voice"] + CloudTTS.settings("azure"),
      "amazon": ["engine", "voice"] + CloudTTS.settings("amazon"),
      "openai": ["engine", "voice"] + CloudTTS.settings("openai"),
    ]
    let isCloud = CloudTTS.engines.contains(engine)
    // 有料の API (合成も、声の一覧も) を呼ぶのは、利用者がこのプロジェクトで一度 --allow-cloud を付けて選んだときだけ
    // (他人の台本の tts.engine だけで、環境変数のキーを使って料金がかかったりキーが送られたりしないように)。
    // 選んだことはキャッシュに覚える (プロジェクトのフォルダに置くと、配られたプロジェクトに印を入れておけてしまうので)
    let consent = Project.cacheDir(root).appendingPathComponent("allow-cloud-\(engine)")
    // 認めたのが「このパスにある、このプロジェクト」であることの印。同じパスに別のプロジェクト (他人の zip を展開し直したものなど) を
    // 置いたときに前の同意が効かないよう、フォルダと jgv.json のファイルの番号 (inode) と jgv.json を作った日時を書いておき、違えば聞き直す
    func projectIdentity() -> String {
      let fm = FileManager.default
      let d = try? fm.attributesOfItem(atPath: root.path)
      let j = try? fm.attributesOfItem(atPath: root.appendingPathComponent("jgv.json").path)
      let born = (j?[.creationDate] as? Date)?.timeIntervalSince1970 ?? 0
      return "\(d?[.systemFileNumber] ?? 0):\(j?[.systemFileNumber] ?? 0):\(Int(born))"
    }
    // --allow-cloud を付けたら、合成する行が無くても (すべてキャッシュにあっても) 認めた印を書く
    if isCloud && args.contains("--allow-cloud") {
      try FileManager.default.createDirectory(at: consent.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data((projectIdentity() + "\n").utf8).write(to: consent, options: .atomic)
      // どのプロジェクトのものかの印 (プロジェクトを消した後に jgv clean --stale が見分ける)
      try? (root.standardizedFileURL.path + "\n").write(to: consent.deletingLastPathComponent().appendingPathComponent("project-path"), atomically: true, encoding: .utf8)
    }
    func requireConsent(_ what: String) throws {
      let saved = (try? String(contentsOf: consent, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
      if let saved, saved != projectIdentity() {
        throw ToolError("この台本は \(CloudTTS.name(engine)) (有料のクラウドの TTS) で\(what)。前に認めた印がありますが、このフォルダか jgv.json が置き直されている (git checkout・別のプロジェクトを同じ場所に置いた など) ので、もう一度確かめます。使ってよければ jgv tts \(scriptArg) --allow-cloud を実行してください")
      }
      if saved == nil {
        throw ToolError("この台本は \(CloudTTS.name(engine)) (有料のクラウドの TTS) で\(what)。このプロジェクトで使ってよければ jgv tts \(scriptArg) --allow-cloud を一度実行してください (次からは聞きません)")
      }
    }
    guard let allowed = TTS_KEYS[engine] else { throw ToolError("未対応の tts.engine: \(engine) (apple / command / \(CloudTTS.engines.joined(separator: " / ")) のどれか)") }
    let unknownKeys = tts.keys.filter { !allowed.contains($0) }
    if !unknownKeys.isEmpty {
      throw ToolError("tts.engine \"\(engine)\" では tts.\(unknownKeys.joined(separator: ", tts.")) は使えません (使えるのは \(allowed.joined(separator: " / ")))")
    }
    if let v = tts["voice"], v.string == nil {
      throw ToolError("tts.voice は声の名前 (文字列) で書いてください: \(v.description)")
    }
    // "rate": "0.4" のように文字列で書くと、黙って既定の速さ (0.5) で読んでしまうので止める
    for k in ["rate", "pitch"] { if let v = tts[k], v.double == nil { throw ToolError("tts.\(k) は数で書いてください (例: 0.5): \(v.description)") } }
    var command: [String] = []
    if engine == "command" {
      guard let arr = tts["command"]?.array, !arr.isEmpty, arr.allSatisfy({ $0.string != nil }) else {
        throw ToolError("tts.command はコマンドと引数の配列で書いてください (例: [\"swift\", \"/path/to/tts.swift\", \"{text}\", \"{out}\"])")
      }
      command = arr.compactMap { $0.string }
      if let f = tts["format"], f.string?.range(of: "^[a-z0-9]+$", options: .regularExpression) == nil {
        throw ToolError("tts.format \"\(f.string ?? f.description)\" は拡張子 (wav / mp3 など) で書いてください")
      }
    }
    if let p = tts["parallel"], !(p.double.map { $0 >= 1 && $0 == $0.rounded() } ?? false) { throw ToolError("tts.parallel は 1 以上の整数で書いてください") }
    // 空の instructions は送らないので、書かなかったのと同じにする (確かめる前に外す)
    if isCloud && tts["instructions"]?.string == "" { tts["instructions"] = nil }
    if isCloud { try CloudTTS.validate(engine, tts) }

    let narrationDir = Project.narrationDir(root)
    let generatedDir = Project.workDir(root)
    let outDir = root.appendingPathComponent("out")
    // out/ がシンボリックリンクなら、tts (コードを実行しない) はリンクの先に字幕を書かない
    // (他人のプロジェクトの out -> ~ などで、データだけでプロジェクトの外のファイルを上書きしないように)。
    // build-langs (visual をビルドして実行するコマンド) から呼ばれたときは、別のディスクへのリンクにも書く
    let outLinked = (try? Safety.requireNoSymlinks(under: root, outDir)) == nil
    let writeSubtitles = !outLinked || args.contains("--from-build-langs")
    for d in [narrationDir, generatedDir, outDir] {
      // .jgv/・.jgv/narration/ がシンボリックリンクだと、音声の掃除でリンク先のファイルを消してしまうので止める
      if d != outDir { try Safety.requireNoSymlinks(under: root, d) } else if outLinked { continue }
      try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    }
    /// jgv が作った音声・書きかけのファイルか (名前の形と、リンクでないふつうのファイルか。ほかのファイルは消さない)
    func isOurAudio(_ f: String) -> Bool {
      f.range(of: "^([a-z]+-)?[0-9a-f]{16}\\.wav(\\.[0-9]+\\.part)?$", options: .regularExpression) != nil && Safety.isRegularFile(narrationDir.appendingPathComponent(f))
    }

    // ---------- visuals ----------
    let customNames = try Registry.visualNames(root)
    // "visual": "Name" | { "type": "Name", ...props } を { type, props } に正規化
    func normalizeVisual(_ v: JSON?, _ si: Int) throws -> JSON {
      guard let v, !v.isNull else { return .null }
      var type = ""
      var props: [(String, JSON)] = []
      if let s = v.string { type = s } else {
        for (k, x) in v.object ?? [] { if k == "type" { type = x.string ?? "" } else { props.append((k, x)) } }
      }
      if !customNames.contains(type) {
        throw ToolError("scenes[\(si)].visual \"\(type)\" が見つかりません。visuals/\(type).swift を用意してください (中に func \(type)(_ props: Props)。キューの工程なら jgv md2script procedure.md --stubs visuals で雛形を作れる)")
      }
      return ["type": .string(type), "props": .object(props)]
    }
    let scenesIn = script["scenes"]?.array ?? []
    // 工程が無い台本は、音声の掃除 (使っていない音声を消す) より前に止める (全部の音声を消してしまわないように)
    if scenesIn.isEmpty { throw ToolError("\(scriptArg) の scenes が空です (工程が 1 つも無い)") }
    // 音声を作る前に、すべての工程の visual があるか確かめる
    for (si, scene) in scenesIn.enumerated() { _ = try normalizeVisual(scene["visual"], si) }

    // 合成の途中のファイルは .jgv/narration/tmp-<プロセスの番号>/ に置く (中断で残っても、次の jgv tts が消す)
    for f in (try? FileManager.default.contentsOfDirectory(atPath: narrationDir.path)) ?? [] where f.hasPrefix("tmp-") {
      let pid = Int32(f.dropFirst(4)) ?? 0
      let d = narrationDir.appendingPathComponent(f)
      if !Safety.isSymlink(d), pid == 0 || kill(pid, 0) != 0 && errno != EPERM { try? FileManager.default.removeItem(at: d) }
    }
    let tmpDir = narrationDir.appendingPathComponent("tmp-\(getpid())")
    try? FileManager.default.removeItem(at: tmpDir)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    // ---------- TTS engines ----------
    var resolvedVoice = ""
    if engine == "apple" {
      let v = tts["voice"]?.string
      resolvedVoice = v != nil && v != "auto" ? v! : try AVTTS.best(lang)
      note("voice: \(resolvedVoice)")
      // キャッシュキーに実際の音声を含める (auto のまま新しい音声を入れた場合に再生成されるように)
      tts["resolvedVoice"] = .string(resolvedVoice)
    } else if isCloud {
      // apple から engine だけ変えた台本の "voice": "auto" と、空の "voice": "" は、書かなかったのと同じにする (クラウドの TTS に auto という声は無い)
      if tts["voice"]?.string == "auto" || tts["voice"]?.string == "" { tts["voice"] = nil }
      // 既定の設定は書いたのと同じキャッシュキーにする (既定のまま → 既定値を書く、の編集で有料の API を呼び直さないように)
      if engine == "amazon" && tts["pollyEngine"] == nil { tts["pollyEngine"] = .string(AmazonTTS.engines[1]) }
      if engine == "openai" && tts["model"] == nil { tts["model"] = .string(OpenAITTS.defaultModel) }
      // 声を書かなかったときは、選んだ声をこのあと別の行で出す (google は API が選ぶ)
      let shown = tts["voice"]?.string ?? (engine == "google" ? "言語の既定" : nil)
      note("tts: \(CloudTTS.name(engine))\(shown.map { " (voice: \($0))" } ?? "")")
      // キャッシュキーに送る言語を含める (voice を書かないと、多言語版で同じ文の音声を別の言語に流用してしまうため)
      tts["resolvedLang"] = .string(CloudTTS.cacheLang(engine, voice: tts["voice"]?.string ?? "", lang: lang))
      if engine == "openai" { note("WARN: \(OpenAITTS.shutdownNotice)") }
      // azure / amazon / openai で voice を書かなかったときは、キャッシュキーを作る前に声を決めて tts.voice に入れる
      // (voice を書いたときと同じキーになる。既定の声が変わっても、古い声と新しい声が 1 本の動画に混ざらない)。
      // azure / amazon が一覧から選んだ声はプロジェクトに覚えておき、次からは一覧の API を呼ばない。google は API が言語から選ぶので空のまま
      if (tts["voice"]?.string ?? "").isEmpty && engine != "google" {
        let memoURL = narrationDir.appendingPathComponent(".default-voices.json")
        var memo = (try? JSON.read(memoURL)) ?? .object([])
        let memoKey = [engine, lang, tts["pollyEngine"]?.string ?? ""].joined(separator: "|")
        let v: String
        if engine == "openai" {
          v = try CloudTTS.defaultVoice(engine, lang: lang, tts: tts)
          note("voice: \(v) (tts.voice が無いので、既定の声を使います)")
        } else if let saved = memo[memoKey]?.string, !saved.isEmpty {
          v = saved
          note("voice: \(v) (tts.voice が無いので、このプロジェクトで前に選んだ声を使います)")
        } else {
          // 声の一覧の API も、キーを送るので同意を確かめてから呼ぶ
          try requireConsent("、声の一覧を API から取ります (手元のキーを使います)")
          try CloudTTS.requireCredentials(engine)
          v = try CloudTTS.defaultVoice(engine, lang: lang, tts: tts)
          memo[memoKey] = .string(v)
          try? (memo.stringify() as String).write(to: memoURL, atomically: true, encoding: .utf8)
          note("voice: \(v) (tts.voice が無いので、\(lang) の声から選びました。次からもこの声を使います)")
        }
        tts["voice"] = .string(v)
        tts["resolvedLang"] = .string(CloudTTS.cacheLang(engine, voice: v, lang: lang))
      }
    } else {
      note("tts: \(command.joined(separator: " "))\(tts["voice"]?.string.map { " (voice: \($0))" } ?? "")")
      // コマンドには {lang} / TTS_LANG で言語を渡すので、キャッシュキーにも言語を含める (多言語版で同じ文の音声を流用しないように)
      tts["resolvedLang"] = .string(lang)
    }
    let voiceArg = tts["voice"]?.string ?? ""

    func synth(_ text: String, _ rawPath: URL) throws {
      if engine == "apple" {
        var a = [resolvedVoice, rawPath.path, text]
        if tts["rate"] != nil || tts["pitch"] != nil { a.append(JSON.jsNumber(tts["rate"]?.double ?? 0.5)) }
        if let p = tts["pitch"]?.double { a.append(JSON.jsNumber(p)) }
        do { _ = try AVTTS.run(a) } catch let e as Shell.Failure {
          // 子プロセス (swift) の失敗を「/usr/bin/swift が失敗しました」ではなく、読み上げの失敗として理由 (voice not found など) を出す
          throw ToolError("macOS の読み上げに失敗しました: \(e.stderr.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))\n文: \(text)")
        }
        return
      }
      if isCloud {
        try CloudTTS.synth(engine, text: text, lang: lang, voice: voiceArg, tts: tts, to: rawPath)
        return
      }
      // tts.command を 1 行ずつ実行する。シェルを通さずに実行するので、文に記号があっても引数がずれない
      // (パイプなどを使うなら ["bash", "-c", "… \"$TTS_TEXT\" … > \"$TTS_OUT\""] のように環境変数で受け取る)
      let vars = ["text": text, "out": rawPath.path, "lang": lang, "voice": voiceArg]
      let re = try! NSRegularExpression(pattern: "\\{(text|out|lang|voice)\\}")
      let replaced = command.map { a -> String in
        var s = a
        for m in re.matches(in: a, range: NSRange(a.startIndex..., in: a)).reversed() {
          let key = String(a[Range(m.range(at: 1), in: a)!])
          s.replaceSubrange(Range(m.range, in: s)!, with: vars[key] ?? "")
        }
        return s
      }
      var env = ProcessInfo.processInfo.environment
      env["TTS_TEXT"] = text; env["TTS_OUT"] = rawPath.path; env["TTS_LANG"] = lang; env["TTS_VOICE"] = voiceArg
      let cmd = replaced[0]
      do {
        try Shell.run(cmd, Array(replaced.dropFirst()), env: env, cwd: root)
      } catch let e as Shell.Failure {
        if e.status == 127 { throw ToolError("tts.command のコマンド \(cmd) が見つかりません (PATH にあるか、パスを確かめてください)") }
        throw ToolError("tts.command が失敗しました (\(e.status)): \(text)\n\(e.stderr.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))")
      } catch let e as ToolError {
        throw e
      } catch {
        // パスで書いたコマンドが無い・実行できない (Process.run の失敗)
        throw ToolError("tts.command のコマンド \(cmd) を実行できません: \(userMessage(error))")
      }
      let size = (try? FileManager.default.attributesOfItem(atPath: rawPath.path)[.size] as? Int) ?? 0
      if size == 0 { throw ToolError("tts.command が音声ファイル {out} を書きませんでした: \(text)") }
    }

    // ---------- helpers ----------
    // (?s): 文の途中に改行があっても、改行より前を落とさない
    let phraseRe = try! NSRegularExpression(pattern: "(?s).+?(?:[。！？、，]+|[.,!?]+(?:\\s+|$)|$)")
    func pieces(_ text: String) -> [String] {
      let m = phraseRe.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text).map { String(text[$0]) } }.filter { !$0.isEmpty }
      return m.isEmpty ? [text] : m
    }
    // 長いセリフを句読点優先で maxChars 以内の字幕チャンクに分割する
    func splitCaption(_ text: String) -> [String] {
      if text.unicodeScalars.count <= maxChars { return [text] }
      var chunks: [String] = []
      var cur = ""
      for p in pieces(text) {
        if (cur + p).unicodeScalars.count <= maxChars { cur += p; continue }
        if !cur.isEmpty { chunks.append(cur) }
        cur = ""
        let chars = Array(p.unicodeScalars)
        // 収まる句は次の句とつなげられるように残す
        if chars.count <= maxChars { cur = p; continue }
        // 少しの超過なら句読点の区切りを優先して分割しない
        if Double(chars.count) <= (Double(maxChars) * 1.25).rounded(.up) { chunks.append(p); continue }
        // それでも長い場合は均等な長さに分割する
        let n = Int((Double(chars.count) / Double(maxChars)).rounded(.up))
        let size = Int((Double(chars.count) / Double(n)).rounded(.up))
        var i = 0
        while i < chars.count {
          var s = String.UnicodeScalarView()
          s.append(contentsOf: chars[i ..< min(chars.count, i + size)])
          chunks.append(String(s))
          i += size
        }
      }
      if !cur.isEmpty { chunks.append(cur) }
      return chunks
    }

    // ---------- main ----------
    // 行ごとの音声ファイル名 (読み上げ文と TTS 設定のハッシュ)。設定や文が変わったときだけ作り直す
    // (command とクラウドの TTS の parallel は音声に関係しないので含めない。並列数を変えただけで有料の API を呼び直さないように)
    let ttsKey = JSON.object((tts.object ?? []).filter { $0.0 != "parallel" }.sorted { $0.0 < $1.0 })
    func audioFile(_ speak: String) -> String {
      let key = JSON.object([("tts", ttsKey), ("speak", .string(speak))]).stringify(indent: 0)
      let digest = Insecure.SHA1.hash(data: Data(key.utf8)).hex
      // クラウドの TTS と command の音声は名前の頭に engine を付ける (apple の実行で、使っていない音声として消さないように)
      return (engine != "apple" ? "\(engine)-" : "") + String(digest.prefix(16)) + ".wav"
    }
    // 前の版の command の音声の名前 (接頭辞が無く、キーに言語を含めなかった)。見つかれば今の名前に直して使う (有料の TTS を呼び直さないように)
    let legacyCommandKey = JSON.object((tts.object ?? []).filter { $0.0 != "parallel" && $0.0 != "resolvedLang" }.sorted { $0.0 < $1.0 })
    func legacyCommandFile(_ speak: String) -> String {
      let key = JSON.object([("tts", legacyCommandKey), ("speak", .string(speak))]).stringify(indent: 0)
      return String(Insecure.SHA1.hash(data: Data(key.utf8)).hex.prefix(16)) + ".wav"
    }
    func lineOf(_ raw: JSON) -> JSON { raw.string.map { JSON.object([("text", .string($0))]) } ?? raw }
    func speakOf(_ line: JSON) -> String { line["speak"]?.string ?? line["text"]?.string ?? "" }

    // .jgv/narration/ の中のシンボリックリンクは jgv が作らない。音声の名前のリンクは、書き込みや読み込みでリンクの先を
    // 使わないように消す (消えるのはリンク自体で、リンクの先は消えない)
    for f in (try? FileManager.default.contentsOfDirectory(atPath: narrationDir.path)) ?? []
    where Safety.isSymlink(narrationDir.appendingPathComponent(f)) && f.range(of: "\\.(wav|part)$", options: .regularExpression) != nil {
      try? FileManager.default.removeItem(at: narrationDir.appendingPathComponent(f))
    }
    // 中断した実行が残した書きかけ (.part) を消す。名前に書いたプロセスの番号が動いていれば、同時に実行中なので残す
    for f in (try? FileManager.default.contentsOfDirectory(atPath: narrationDir.path)) ?? [] where f.hasSuffix(".part") && isOurAudio(f) {
      let pid = f.split(separator: ".").dropLast().last.flatMap { Int32($0) } ?? 0
      if pid == 0 || kill(pid, 0) != 0 && errno != EPERM { try? FileManager.default.removeItem(at: narrationDir.appendingPathComponent(f)) }
    }

    // まだ無い音声をまとめて生成する (同じ文は 1 回だけ)
    var pending: [String: Job] = [:]
    var order: [String] = []
    let rawExt = engine == "command" ? (tts["format"]?.string ?? "wav") : isCloud ? CloudTTS.rawExt(engine) : "caf"
    for scene in scenesIn {
      for raw in scene["lines"]?.array ?? [] {
        let speak = speakOf(lineOf(raw))
        let file = audioFile(speak)
        if engine == "command", !FileManager.default.fileExists(atPath: narrationDir.appendingPathComponent(file).path) {
          let old = narrationDir.appendingPathComponent(legacyCommandFile(speak))
          if FileManager.default.fileExists(atPath: old.path) { try? FileManager.default.moveItem(at: old, to: narrationDir.appendingPathComponent(file)) }
        }
        if pending[file] != nil || FileManager.default.fileExists(atPath: narrationDir.appendingPathComponent(file).path) { continue }
        pending[file] = Job(speak: speak, rawPath: tmpDir.appendingPathComponent("raw-\(file.dropLast(4)).\(rawExt)"), wavPath: narrationDir.appendingPathComponent(file))
        order.append(file)
      }
    }
    let jobs = order.map { pending[$0]! }
    if !jobs.isEmpty {
      // キーは作る音声があるときだけ要る (すべてキャッシュにあれば、キーが無くても timeline を作り直せる)
      if isCloud {
        // 空の文は API がエラーにするので、呼ぶ前に止める (有料の API を途中まで呼んでから止まらないように)
        if let j = jobs.first(where: { $0.speak.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
          throw ToolError("読み上げる文が空の行があります (scenes の lines の text / speak を確かめてください): \"\(j.speak)\"")
        }
        // 1 回に送れる長さ (google 5000 バイト、amazon 3000 字、openai 4096 字。azure は 1 回の音声が 10 分までなので、余裕を見て 5000 字) を超える行も、呼ぶ前に止める
        let limit: (String) -> Bool = engine == "google" ? { $0.utf8.count > 5000 } : engine == "amazon" ? { $0.count > 3000 } : engine == "openai" ? { $0.count > 4096 } : { $0.count > 5000 }
        if let j = jobs.first(where: { limit($0.speak) }) {
          throw ToolError("\(CloudTTS.name(engine)) に 1 回で送れる長さを超える行があります (行を分けてください): \"\(j.speak.prefix(40))…\"")
        }
        try CloudTTS.requireCredentials(engine)
        try requireConsent(" \(jobs.count) 行・\(jobs.reduce(0) { $0 + $1.speak.count }) 字を合成します")
      }
      // apple は 1 行ずつ別のプロセスで並列に合成する (swift の起動待ちが重なって速くなる)。
      // 1 つのプロセスでまとめて合成すると 2 行目以降の音声が単独のときとわずかに変わるので、プロセスは分ける。
      // command とクラウドの TTS は tts.parallel (既定 2。クラウドの TTS の同時接続の上限に当たりにくいように少なめ)
      let cores = ProcessInfo.processInfo.activeProcessorCount
      // 同時に動かす子のプロセスは 16 まで (Ctrl-C で一緒に止める表の大きさと、相手の API の上限のため)
      let parallel = engine != "apple" ? min(16, tts["parallel"]?.int ?? 2) : min(8, max(1, cores - 1))
      try pool(jobs, parallel) { j in
        note("TTS: \(j.speak)")
        try synth(j.speak, j.rawPath)
        // 音量をそろえて 48kHz モノラルの wav にする。途中で止まっても書きかけの wav がキャッシュとして残らないよう、
        // 一時ファイルに書いてから名前を変える (キャッシュはファイルの有無だけで判断している)
        let samples: [Float]
        do { samples = try AudioFile.readMono(j.rawPath, sampleRate: 48000) } catch {
          // AVAudioFile のエラーは番号だけ (error 1954115647 など) で、どの行の何が悪いか分からないので補う
          let hint = engine == "command" ? " (tts.command は {out} に wav / mp3 / m4a など AVAudioFile が読める形式で書いてください)" : ""
          throw ToolError("読み上げの音声ファイルが読めません: \(userMessage(error))\(hint)\n文: \(j.speak)")
        }
        // 中身の無い音声 (ヘッダーだけの wav など) を、長さ 0 の行としてキャッシュに残さない (残すと、消すまで無音の行のままになる)
        if samples.isEmpty {
          let hint = engine == "command" ? " (tts.command が {out} に書いた音声を確かめてください)" : ""
          throw ToolError("読み上げの音声が空です\(hint)。記号だけの行なら、読める文にするか行を消してください\n文: \(j.speak)")
        }
        let normalized = AudioProcess.normalize(samples)
        let tmpWav = URL(fileURLWithPath: "\(j.wavPath.path).\(getpid()).part")
        try AudioFile.writeWav(normalized, sampleRate: 48000, to: tmpWav)
        // 同じプロジェクトで jgv tts (jgv dev) が同時に動いて同じ行を作っていても失敗しないよう、rename で置き換える
        // (moveItem は行き先があると失敗する。消してから移すと、その間に相手が置いたものと衝突する)
        if rename(tmpWav.path, j.wavPath.path) != 0 {
          let reason = String(cString: strerror(errno))
          try? FileManager.default.removeItem(at: tmpWav)  // 書きかけの .part を残さない
          throw ToolError("\(j.wavPath.path) に書けません: \(reason)")
        }
      }
    }

    // 行ごとの音声の長さと無音区間 (行ごとに独立しているので並列に調べる)
    var allFiles: [String] = []
    for scene in scenesIn { for raw in scene["lines"]?.array ?? [] { let f = audioFile(speakOf(lineOf(raw))); if !allFiles.contains(f) { allFiles.append(f) } } }
    let infoLock = NSLock()
    var audioInfo: [String: (duration: Double, silences: [(start: Double, end: Double)])] = [:]
    try pool(allFiles, max(1, ProcessInfo.processInfo.activeProcessorCount - 1)) { file in
      let samples: [Float]
      do { samples = try AudioFile.readMono(narrationDir.appendingPathComponent(file), sampleRate: 48000) } catch {
        // キャッシュの wav が壊れている (0 バイトなど。AVAudioFile のエラーは番号だけなので、どのファイルかと直し方を出す)
        throw ToolError(".jgv/narration/\(file) が読めません: \(userMessage(error))\nこのファイルを消して jgv tts をやり直してください (消した行の音声だけ作り直します)")
      }
      if samples.isEmpty {
        throw ToolError(".jgv/narration/\(file) の音声が空です\nこのファイルを消して jgv tts をやり直してください (消した行の音声だけ作り直します)")
      }
      let info = (Double(samples.count) / 48000, AudioProcess.silences(samples))
      infoLock.lock(); audioInfo[file] = info; infoLock.unlock()
    }

    var lines: [JSON] = []
    var scenes: [JSON] = []
    var t = padStart
    var used = Set<String>()
    var srtCaptions: [(text: String, start: Double, end: Double)] = []
    for (si, scene) in scenesIn.enumerated() {
      let sceneStart = si == 0 ? 0 : t - sceneGap / 2
      for raw in scene["lines"]?.array ?? [] {
        let line = lineOf(raw)
        let text = line["text"]?.string ?? ""
        let file = audioFile(speakOf(line))
        used.insert(file)
        // 字幕の塊と、読点・句点ごとの句。区切りの時刻は音声の無音に合わせる
        let info = audioInfo[file]!
        let captions = segments(splitCaption(text), t, info.duration, info.silences)
        let phrases = segments(pieces(text), t, info.duration, info.silences)
        srtCaptions += captions
        lines.append([
          "sceneIndex": .number(Double(si)), "text": .string(text), "cue": line["cue"] ?? .null, "audio": .string("narration/\(file)"),
          "start": .number(t), "duration": .number(info.duration),
          "captions": .array(captions.map { ["text": .string($0.text), "start": .number($0.start), "end": .number($0.end)] }),
          "phrases": .array(phrases.map { ["text": .string($0.text), "start": .number($0.start), "end": .number($0.end)] }),
        ])
        t += info.duration + gap
      }
      t += sceneGap
      scenes.append([
        "index": .number(Double(si)), "heading": scene["heading"] ?? "", "visual": try normalizeVisual(scene["visual"], si),
        "start": .number(sceneStart), "end": .number(t - sceneGap / 2),
      ])
    }
    let durationInSeconds = t - gap - sceneGap + padEnd
    if !scenes.isEmpty { scenes[scenes.count - 1]["end"] = .number(durationInSeconds) }

    // 使われなくなった古い音声を削除 (--keep-audio のときは残す: 多言語の一括書き出し用)。
    // 消すのは作り直しが無料の apple だけ。command とクラウドの TTS は、ほかの言語版の台本の音声を消して API を呼び直す (料金がかかる) ことがないよう残す
    // (apple でも、クラウドの TTS と command で作った音声 (名前の頭が google- / command- など) は残す)
    if !keepAudio && engine == "apple" {
      for f in (try? FileManager.default.contentsOfDirectory(atPath: narrationDir.path)) ?? []
      where f.hasSuffix(".wav") && isOurAudio(f) && !used.contains(f) && !(CloudTTS.engines + ["command"]).contains(where: { f.hasPrefix("\($0)-") }) {
        try? FileManager.default.removeItem(at: narrationDir.appendingPathComponent(f))
      }
    }

    // クレジット表記 (script.json の credit が優先)。command はどの TTS か分からないので既定は無し。クラウドの TTS も既定は無し。
    // openai は利用規約で AI が作った音声であることを伝える必要があるので、既定で出す
    func defaultCredit() -> String {
      if engine == "openai" { return isJa ? "ナレーション: AI 音声 (OpenAI)" : "Narration: AI-generated voice (OpenAI)" }
      if engine != "apple" { return "" }
      let id = resolvedVoice
      var name = id.split(separator: ".").last.map(String.init) ?? id
      if let r = id.range(of: "_([A-Za-z]+)_[a-z]{2}-[A-Z]{2}", options: .regularExpression) {
        name = String(id[r].dropFirst().split(separator: "_").first ?? "")
      }
      return "\(isJa ? "ナレーション" : "Narration"): macOS \(name)"
    }
    let credit = script["credit"]?.string ?? defaultCredit()
    if engine != "apple" && engine != "openai" && script["credit"] == nil {
      note("WARN: tts.engine が \(engine) なので、クレジットを出していません。使った TTS が表記を求めるなら script.json の credit に書いてください")
    }

    let timeline: JSON = [
      "fps": .number(fps),
      "width": .number(width),
      "height": .number(height),
      "durationInSeconds": .number(durationInSeconds),
      "title": script["title"] ?? "",
      "lang": .string(lang),
      "strings": script["strings"] ?? .object([]),
      "layout": script["layout"] ?? "guide",
      "guide": script["guide"] ?? .null,
      "credit": .string(credit),
      "style": style,
      "scenes": .array(scenes),
      "lines": .array(lines),
      // どの台本から作ったか (jgv check / render が、台本を直した後に jgv tts をし忘れていないか確かめる)
      "source": [
        "script": .string(scriptURL.path.hasPrefix(root.standardizedFileURL.path + "/") ? String(scriptURL.path.dropFirst(root.standardizedFileURL.path.count + 1)) : scriptURL.path),
        "sha256": .string(sha256Hex(of: scriptURL) ?? ""),
      ],
    ]
    // 読む側 (check / render) と同じ決まりで確かめてから書く (描けない timeline を書いて、後のコマンドがすべて止まらないように)
    if let m = Timeline(timeline).invalidReason { throw ToolError("\(scriptArg) から作った timeline が正しくありません: \(m) (gap / padStart などの値を確かめてください)") }
    try (timeline.stringify() as String).write(to: generatedDir.appendingPathComponent("timeline.json"), atomically: true, encoding: .utf8)

    let srt = srtCaptions.enumerated().map { i, c in "\(i + 1)\n\(srtTime(c.start)) --> \(srtTime(c.end))\n\(c.text)\n" }.joined(separator: "\n")
    if writeSubtitles {
      try srt.write(to: outDir.appendingPathComponent("subtitles.srt"), atomically: true, encoding: .utf8)
      print("OK: \(lines.count) lines, \(String(format: "%.2f", durationInSeconds))s -> .jgv/timeline.json, out/subtitles.srt")
    } else {
      FileHandle.standardError.write("WARN: out/ がシンボリックリンクなので、字幕 out/subtitles.srt は書きませんでした (字幕が要るなら out/ をふつうのフォルダにするか、jgv build-langs で書き出す)\n".data(using: .utf8)!)
      print("OK: \(lines.count) lines, \(String(format: "%.2f", durationInSeconds))s -> .jgv/timeline.json")
    }

    // 日本語の台本は、speak のひらがなの読みが区切りを誤りそうな所と、漢数字と助数詞 (一本) を警告する (確かめられなくても止めない)
    if isJa { Yomi.warn(scriptURL: scriptURL) }
    warnUntranslated(root: root, scriptURL: scriptURL, script: script, lang: lang)
    // jgv new が途中で止まった後に jgv tts で続けたなら、もう「途中」ではない
    let incomplete = Project.workDir(root).appendingPathComponent("new-incomplete")
    if Safety.isRegularFile(incomplete) { try? FileManager.default.removeItem(at: incomplete) }
  }

  // ---------- 区切りの時刻 ----------

  static func weight(_ s: String) -> Double {
    Double(max(1, s.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.count))
  }

  /// texts (字幕の塊や句) を順に読んだとき、texts[1] 以降の読み始めの時刻 (行頭からの秒) を返す。
  /// 句読点で終わる区切りは、文字数から推定した時刻に近い無音へ順番どおりに合わせ、無音の終わり (声が戻る時刻) を読み始めにする。
  /// 無音に合わない区切り (句読点でない区切り・間を取らずに読んだ読点) は、前後の確定した時刻の間を文字数の比率で埋める
  static func boundaryTimes(_ texts: [String], _ duration: Double, _ silences: [(start: Double, end: Double)]) -> [Double] {
    let total = texts.reduce(0) { $0 + weight($1) }
    var acc = 0.0
    let punctRe = try! NSRegularExpression(pattern: "[。！？、，；：.,!?;:][\"'”’）」』)]*\\s*$")
    let bs: [(cum: Double, est: Double, punct: Bool)] = texts.dropLast().map { tx in
      acc += weight(tx)
      return (acc / total, (duration * acc) / total, punctRe.firstMatch(in: tx, range: NSRange(tx.startIndex..., in: tx)) != nil)
    }
    let n = bs.count, m = silences.count
    if n == 0 { return [] }
    // dp[i][j]: 最初の i 個の区切りに、最初の j 個の無音から順番どおりに割り当てたときの最小コスト
    let SKIP = max(0.6, duration * 0.15) // 区切りを無音に合わせないときのコスト
    var dp = (0 ... n).map { i in [Double](repeating: i == 0 ? 0 : .infinity, count: m + 1) }
    var how = (0 ... n).map { _ in [String](repeating: "", count: m + 1) }
    for i in 1 ... n {
      for j in 0 ... m {
        var best = dp[i - 1][j] + SKIP
        var h = "skip"
        if j > 0 && dp[i][j - 1] < best { best = dp[i][j - 1]; h = "unused" }
        if j > 0 && bs[i - 1].punct {
          let mid = (silences[j - 1].start + silences[j - 1].end) / 2
          let c = dp[i - 1][j - 1] + abs(mid - bs[i - 1].est)
          if c < best { best = c; h = "match" }
        }
        dp[i][j] = best
        how[i][j] = h
      }
    }
    var times = [Double?](repeating: nil, count: n)
    var i = n, j = m
    while i > 0 {
      let h = how[i][j]
      if h == "match" { i -= 1; j -= 1; times[i] = silences[j].end } else if h == "unused" { j -= 1 } else { i -= 1 }
    }
    // 合わせられなかった区切りを、前後の確定した時刻 (行頭 0・行末 duration を含む) の間で文字数の比率で埋める
    var anchors: [(cum: Double, t: Double)] = [(0, 0)]
    for (k, b) in bs.enumerated() { if let tk = times[k] { anchors.append((b.cum, tk)) } }
    anchors.append((1, duration))
    return bs.enumerated().map { k, b in
      if let tk = times[k] { return tk }
      let a = anchors.last { $0.cum <= b.cum }!
      let z = anchors.first { $0.cum >= b.cum && !($0.cum == a.cum && $0.t == a.t) } ?? anchors.last!
      return z.cum == a.cum ? a.t : a.t + ((z.t - a.t) * (b.cum - a.cum)) / (z.cum - a.cum)
    }
  }

  /// 行頭 t0 から、texts を区切り時刻どおりに並べた (text, start, end) の列
  static func segments(_ texts: [String], _ t0: Double, _ duration: Double, _ silences: [(start: Double, end: Double)]) -> [(text: String, start: Double, end: Double)] {
    let starts = [0] + boundaryTimes(texts, duration, silences)
    return texts.enumerated().map { k, text in (text, t0 + starts[k], t0 + (k + 1 < starts.count ? starts[k + 1] : duration)) }
  }

  static func srtTime(_ sec: Double) -> String {
    let ms = Int(jsRound(sec * 1000))
    return String(format: "%02d:%02d:%02d,%03d", ms / 3_600_000, (ms % 3_600_000) / 60000, (ms % 60000) / 1000, ms % 1000)
  }

  /// items を最大 n 個ずつ並列に処理する。1 つでも失敗したら、新しい項目は始めず、最初のエラーを投げる
  static func pool<T>(_ items: [T], _ n: Int, _ fn: @escaping (T) throws -> Void) throws {
    let lock = NSLock()
    var next = 0
    var failure: Error?
    let group = DispatchGroup()
    for _ in 0 ..< min(n, items.count) {
      group.enter()
      Thread.detachNewThread {
        defer { group.leave() }
        while true {
          lock.lock()
          if failure != nil || next >= items.count { lock.unlock(); return }
          let k = next
          next += 1
          lock.unlock()
          do { try fn(items[k]) } catch {
            lock.lock(); if failure == nil { failure = error }; lock.unlock()
          }
        }
      }
    }
    group.wait()
    if let failure { throw failure }
  }
}
