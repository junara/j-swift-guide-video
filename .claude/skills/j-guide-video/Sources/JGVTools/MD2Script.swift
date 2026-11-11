// Markdown の手順書を、ガイドレイアウトの script.json に変換する (jgv md2script)。
//
//   # タイトル
//   ## 工程名 [tag]      ← [tag] は任意。visual 名になる (prepare → Prepare)。英字で始まる英数字・-・_ だけ。無ければ Step01, Step02 …
//   本文 (そのまま読み上げる文章。1 文 = 1 行に分割)
//   - 箇条書き・番号付きリストは 1 項目 = 1 文。強調・リンク・インラインコードの記法は外して読む
//   - 日本語・中国語は改行も文の区切り (読点で終わる行は次の行につなげる)。英語などは空行が段落の区切り
//
// usage: jgv md2script <procedure.md> [-o script.json] [--lang en-US] [--kicker "..."]
//                      [--stubs visuals]   ← キューの雛形を書き出す: cues/<Visual>.cue (行と句の番号つき)、
//                                             visuals/<Visual>.swift (CueScene を呼ぶ 1 行)、visuals/bind.swift (binding の雛形)
//                      [--swift-stubs]     ← --stubs で、キューではなく Swift の仮の visual を書き出す (前の書き方)
//                      [--base script.json]    ← 多言語版: 基準の台本から visual 名・配置・配色・字幕と説明文の表示設定を引き継ぐ
//                      [--layout guide | guide-screen | guide-topdown | guide-manual]  ← 型 (既定 guide = 部屋)
//                      [--vertical]            ← 縦型 1080x1920
//                      [--tts apple | command | google | azure | amazon | openai] ← 読み上げの engine (既定 apple = macOS の音声。command は defaults.json の tts.command を使う。google / azure / amazon / openai はクラウドの TTS で、キーは環境変数)
//                      [--no-captions]         ← 字幕バーを出さない (style.captions = false)
//                      [--no-notes]            ← 説明文 (注釈・ポイントメモ・小手順ラベル) を出さない (style.notes = false)
//                      [--no-text]             ← 上の 2 つの両方。読み上げだけで伝える
//                      [--no-library]          ← ユーザーのライブラリの defaults.json を使わない
//
// ユーザーのライブラリ ($J_GUIDE_VIDEO_LIBRARY、未設定なら $XDG_CONFIG_HOME/j-guide-video、それも無ければ ~/.config/j-guide-video。空文字で無効) に defaults.json があれば、
// kicker・人物の見た目・型・配色・声・速さ・字幕と説明文の表示・読み方の辞書 (readings) を既定値にする。優先順は 組み込みの既定 < defaults.json < コマンドのオプション。
// 多言語版 (--base) では、型・大きさ・kicker・人物の見た目・配色・字幕と説明文の表示を基準の台本から引き継ぐ (上書きできるのは --kicker・--presenter と --no-*)。
// 読み上げの engine も、--tts も defaults.json の tts.engine も無ければ基準の台本から引き継ぐ。
// 声と速さと読み方は言語ごとなので、--base があっても defaults.json の voices / rates / readings を使う
//
// 読み方: defaults.json の readings (言語ごとの { "語": "読み" }) を各行の speak に当てる
// Node 版 (scripts/md2script.mjs) の移植。出力する script.json とメッセージは Node 版と同じ
import Foundation
import JGVCore

public enum MD2Script {
  public static let usage =
    "usage: jgv md2script <procedure.md> [-o script.json] [--lang en-US] [--kicker ...] [--presenter male|female|neutral] [--stubs visuals] [--swift-stubs] [--base script.json] [--layout guide] [--vertical] [--tts apple|command|google|azure|amazon|openai] [--no-captions] [--no-notes] [--no-text] [--no-library]"
  static let valueOpts = ["-o", "--lang", "--kicker", "--presenter", "--stubs", "--base", "--layout", "--tts"]
  // engine ごとに tts に書ける設定 (engine と voice を除いたもの。voice は voices で言語ごとに決める)
  static let ttsSettings: [(String, [String])] = [("apple", ["rate", "pitch"]), ("command", ["command", "format", "parallel"]), ("google", CloudTTS.settings("google")), ("azure", CloudTTS.settings("azure")), ("amazon", CloudTTS.settings("amazon")), ("openai", CloudTTS.settings("openai"))]
  static let flagOpts = ["--vertical", "--no-captions", "--no-notes", "--no-text", "--no-library", "--swift-stubs"]
  static let layouts = ["guide", "guide-screen", "guide-topdown", "guide-manual"]
  /// 人物の見た目 (guide.presenter)
  static let presenters = ["male", "female", "neutral"]
  static let defaultKeys = ["layout", "kicker", "presenter", "palette", "tts", "voices", "rates", "readings", "captions", "notes"]

  struct Scene {
    var heading: String
    var visual: String
    var lines: [JSON]
  }

  static func fail(_ msg: String?) -> ToolError {
    ToolError(msg ?? usage, usage: msg == nil ? nil : usage)
  }

  public static func run(_ args: [String]) throws {
    let log = note, warn = JSCompat.warn
    var opts: [String: String] = [:]
    var flags = Set<String>()
    var positional: [String] = []
    var i = 0
    while i < args.count {
      let a = args[i]
      if valueOpts.contains(a) {
        if i + 1 >= args.count { throw fail("\(a) に値がありません") }
        i += 1
        opts[a] = args[i]
      } else if flagOpts.contains(a) {
        flags.insert(a)
      } else if a.hasPrefix("-") {
        throw fail("不明なオプション: \(a)")
      } else {
        positional.append(a)
      }
      i += 1
    }
    guard let input = positional.first, !input.isEmpty else { throw fail(nil) }

    // ユーザーのライブラリの既定値 (defaults.json)
    let env = ProcessInfo.processInfo.environment
    let library: String
    if let lib = env["J_GUIDE_VIDEO_LIBRARY"] {
      library = lib
    } else {
      let xdg = env["XDG_CONFIG_HOME"].flatMap { $0.isEmpty ? nil : $0 } ?? JSCompat.pathJoin(env["HOME"] ?? NSHomeDirectory(), ".config")
      library = JSCompat.pathJoin(xdg, "j-guide-video")
    }
    let defaultsFile: String? = !library.isEmpty && !flags.contains("--no-library") ? JSCompat.pathJoin(library, "defaults.json") : nil
    var defaults: JSON = .object([])
    if let defaultsFile, FileManager.default.fileExists(atPath: defaultsFile) {
      do {
        defaults = try JSON.parse(String(decoding: try Data(contentsOf: URL(fileURLWithPath: defaultsFile)), as: UTF8.self))
      } catch {
        throw fail("\(defaultsFile) が JSON として読めません: \(error)")
      }
      if !JSCompat.isPlainObject(defaults) { throw fail("\(defaultsFile) はオブジェクト ({ … }) で書いてください") }
      let unknown = defaults.keys.filter { !defaultKeys.contains($0) }
      if !unknown.isEmpty {
        warn("WARN: \(defaultsFile) の \(unknown.joined(separator: ", ")) は使えないので無視しました (\(defaultKeys.joined(separator: " / ")))")
      }
      for k in ["palette", "tts", "voices", "rates", "readings"] {
        if let v = defaults[k], !JSCompat.isPlainObject(v) {
          warn("WARN: \(defaultsFile) の \(k) はオブジェクト ({ … }) で書いてください。無視しました")
          defaults[k] = nil
        }
      }
      // voices の直下 (apple / command 用) も、声は文字列で書く (違う形のまま script.json に入ると jgv tts で止まるため)
      if var voices = defaults["voices"] {
        for (k, v) in voices.object ?? [] where !CloudTTS.engines.contains(k) && v.string == nil {
          warn("WARN: \(defaultsFile) の voices.\(k) は声の名前 (文字列) で書いてください。無視しました")
          voices[k] = nil
        }
        defaults["voices"] = voices
      }
      if var tts = defaults["tts"], tts["voice"] != nil {
        warn("WARN: \(defaultsFile) の tts.voice は使えないので無視しました。声は言語ごとに voices に書いてください (例: \"voices\": { \"ja\": \"…\" })")
        tts["voice"] = nil
        defaults["tts"] = tts
      }
      if let l = defaults["layout"], !(l.string.map { layouts.contains($0) } ?? false) {
        warn("WARN: \(defaultsFile) の layout \"\(JSCompat.string(l))\" は使えないので無視しました")
        defaults["layout"] = nil
      }
      if let p = defaults["presenter"], !(p.string.map { presenters.contains($0) } ?? false) {
        warn("WARN: \(defaultsFile) の presenter \"\(JSCompat.string(p))\" は使えないので無視しました (\(presenters.joined(separator: " / ")))")
        defaults["presenter"] = nil
      }
      log("library: \(defaultsFile) を既定値にしました")
    }

    let layout = opts["--layout"] ?? JSCompat.coalesce(defaults["layout"], nil)?.string ?? "guide"
    if !layouts.contains(layout) { throw fail("--layout \"\(layout)\" は使えません。\(layouts.joined(separator: " / ")) のどれかを指定してください") }
    if let p = opts["--presenter"], !presenters.contains(p) { throw fail("--presenter \"\(p)\" は使えません。\(presenters.joined(separator: " / ")) のどれかを指定してください") }

    var isDir: ObjCBool = false
    if !FileManager.default.fileExists(atPath: input, isDirectory: &isDir) || isDir.boolValue {
      throw fail("手順書のファイル \(input) がありません")
    }
    // UTF-8 でないファイル (Shift_JIS など) は、黙って文字化けした台本を作らずに止める
    guard let md = String(data: try Data(contentsOf: URL(fileURLWithPath: input)), encoding: .utf8) else {
      throw fail("手順書 \(input) が UTF-8 として読めません (Shift_JIS などで保存されていれば UTF-8 で保存し直してください)")
    }
    // 言語の自動判定: かながあれば日本語、ハングルなら韓国語、漢字だけなら中国語、それ以外は英語
    func detectLang(_ text: String) -> String {
      let u = text.utf16
      if u.contains(where: { $0 >= 0x3040 && $0 <= 0x30FF }) { return "ja-JP" }
      if u.contains(where: { $0 >= 0xAC00 && $0 <= 0xD7AF }) { return "ko-KR" }
      if u.contains(where: { $0 >= 0x4E00 && $0 <= 0x9FFF }) { return "zh-CN" }
      return "en-US"
    }
    // --lang は 言語-地域 (ja-JP / en-US など)。地域を省くと macOS の声がどの地域から選ばれるか決まらない (en → en-IN の声など) ので、よく使う地域を補う
    func normalizeLang(_ l: String) throws -> String {
      let parts = l.replacingOccurrences(of: "_", with: "-").split(separator: "-").map(String.init)
      guard let code = parts.first?.lowercased(), code.range(of: "^[a-z]{2,3}$", options: .regularExpression) != nil else {
        throw fail("--lang \(l) は言語のコードとして読めません (ja-JP / en-US / zh-CN のように書く)")
      }
      // macOS の一覧に無いコード (tl など、ほかの名前に置き換えられたもの) も止めずに通す
      if !Locale.LanguageCode.isoLanguageCodes.contains(where: { $0.identifier == code }) {
        warn("WARN: --lang \(l) の言語コード \(code) は macOS の一覧にありません (そのまま使います。声が見つからなければ jgv voices で確かめる)")
      }
      if parts.count > 1 { return ([code] + parts.dropFirst()).joined(separator: "-") }
      let regions = ["ja": "JP", "en": "US", "zh": "CN", "ko": "KR", "vi": "VN", "uk": "UA", "fr": "FR", "de": "DE", "es": "ES", "it": "IT", "pt": "BR", "ru": "RU", "th": "TH", "id": "ID"]
      guard let r = regions[code] else { warn("WARN: --lang \(l) に地域がありません (\(l)-XX のように書くと声の地域が決まります)"); return code }
      warn("WARN: --lang \(l) を \(code)-\(r) にしました (ほかの地域なら --lang \(code)-GB のように書く)")
      return "\(code)-\(r)"
    }
    let lang = try opts["--lang"].map(normalizeLang) ?? detectLang(md)
    let ja = lang.hasPrefix("ja")
    let cjk = lang.hasPrefix("ja") || lang.hasPrefix("zh") // 句読点で文を区切る言語

    // 多言語版の基準の台本 (--base)。読み上げの engine の引き継ぎにも使うので先に読む
    let baseFile = opts["--base"]
    var base: JSON? = nil
    if let baseFile {
      do { base = try JSON.read(URL(fileURLWithPath: baseFile)) } catch let e as JSON.ParseError {
        throw ToolError(e.message)
      } catch {
        throw ToolError("基準の台本 \(baseFile) が読めません: \(error.localizedDescription)")
      }
    }

    // 読み上げの engine (コマンドのオプション > defaults.json の tts.engine > 基準の台本の tts.engine > apple)。defaults.json の tts はその engine の設定だけを使う
    // 基準の台本の engine も引き継ぐ (基準の script.json を手で google などに直したとき、ほかの言語だけ macOS の声に戻らないように)
    let baseEngine = base?["tts"]?["engine"]
    // defaults.json の engine を空の文字にしたときは、基準の台本のせいにせず、そのファイルの誤りとして伝える
    if opts["--tts"] == nil, defaults["tts"]?["engine"]?.string == "" {
      throw fail("\(defaultsFile ?? "defaults.json") の tts.engine が空です (書かないか、\(ttsSettings.map { $0.0 }.joined(separator: " / ")) のどれかにする)")
    }
    let engineFromBase = opts["--tts"] == nil && !JSCompat.truthy(JSCompat.coalesce(defaults["tts"]?["engine"], nil)) && JSCompat.truthy(baseEngine)
    let engineJSON: JSON = opts["--tts"].map { .string($0) } ?? JSCompat.coalesce(defaults["tts"]?["engine"], nil) ?? (engineFromBase ? baseEngine! : "apple")
    let engine = JSCompat.string(engineJSON)
    guard let settings = (engineJSON.string.flatMap { e in ttsSettings.first { $0.0 == e }?.1 }) else {
      let from = !(opts["--tts"] ?? "").isEmpty ? "--tts" : engineFromBase ? "\(opts["--base"] ?? "") の tts.engine" : "\(defaultsFile ?? "defaults.json") の tts.engine"
      throw fail("\(from) の \"\(engine)\" は使えません。\(ttsSettings.map { $0.0 }.joined(separator: " / ")) のどれかを指定してください")
    }
    // engine が基準の台本と同じなら (引き継いだときも、--tts などで同じ engine を選んだときも)、その engine の設定
    // (command / format / parallel / pitch / pollyEngine / model / instructions) も基準の台本から引き継ぎ、defaults.json で上書きする。
    // 声と速さ (voice / rate) は言語ごとなので引き継がない
    var ttsDefaults: [(String, JSON)] = []
    if engineFromBase || (baseEngine?.string == engine) {
      ttsDefaults = (base?["tts"]?.object ?? []).filter { settings.contains($0.0) && $0.0 != "rate" }
      if engineFromBase { log("  tts: 基準の台本 \(opts["--base"] ?? "") から engine \"\(engine)\" を引き継ぎます") }
    }
    for (k, v) in (defaults["tts"]?.object ?? []) where settings.contains(k) {
      ttsDefaults.removeAll { $0.0 == k }
      ttsDefaults.append((k, v))
    }
    // 基準の台本のコマンドを使うことになるとき (defaults.json に自分の tts.command が無いとき) だけ、何を実行するかを見せる
    // (jgv tts がそのまま実行する。defaults.json のコマンドに置き換わるなら、基準の台本のコマンドは使わない)
    if engine == "command", !JSCompat.truthy(defaults["tts"]?["command"]), let c = base?["tts"]?["command"], JSCompat.truthy(c),
       ttsDefaults.last(where: { $0.0 == "command" })?.1 == c {
      warn("WARN: 基準の台本の tts.command \(c.description) を引き継ぎます。jgv tts はこのコマンドをそのまま実行します (信頼できる台本のときだけ使う)")
    }
    if engine == "command" && !JSCompat.truthy(ttsDefaults.last { $0.0 == "command" }?.1) {
      throw fail("tts の engine \"command\" には、ユーザーのライブラリの defaults.json (または基準の台本) に tts.command が必要です (書かないなら --tts apple や --tts google などで作ってから script.json の tts を直す)")
    }
    // クラウドの TTS のキーは音声を作る jgv tts で使う。ここでは止めずに、足りなければ先に伝える (jgv new の途中で気づけるように)
    if CloudTTS.engines.contains(engine), let m = CloudTTS.missingCredentials(engine) {
      warn("WARN: \(m)。jgv tts の前に設定してください")
    }
    // クラウドの TTS の声は voices.google / voices.azure / voices.amazon に { 言語: "声の名前" } で書く。
    // 形が違えば、黙って既定の声にならないよう警告して捨てる (使う engine の分だけ確かめる)
    for e in CloudTTS.engines where e == engine {
      guard var voices = defaults["voices"], let g = voices[e] else { continue }
      if !JSCompat.isPlainObject(g) {
        warn("WARN: \(defaultsFile ?? "defaults.json") の voices.\(e) は { \"ja-JP\": \"声の名前\" } のようにオブジェクトで書いてください。無視しました")
        voices[e] = nil
      } else {
        var kept = g
        for (k, v) in g.object ?? [] where v.string == nil {
          warn("WARN: \(defaultsFile ?? "defaults.json") の voices.\(e).\(k) は声の名前 (文字列) で書いてください。無視しました")
          kept[k] = nil
        }
        voices[e] = kept
      }
      defaults["voices"] = voices
    }
    let wide = lang.hasPrefix("ja") || lang.hasPrefix("zh") || lang.hasPrefix("ko") // 文字が全角幅の言語 (字幕 1 枚の文字数を少なくする)

    // Markdown のインライン記法を外す (読み上げ・字幕に記号が出ないように)
    let ws = JSCompat.ws, w = JSCompat.word
    let reImage = JSRegex(#"!\[[^\]]*\]\([^)]*\)"#)
    let reLink = JSRegex(#"\[([^\]]*)\]\([^)]*\)"#)
    let reCode = JSRegex(#"`([^`]*)`"#)
    let reBold = JSRegex(#"(\*\*|__)(.+?)\1"#)
    let reItalicStar = JSRegex("(^|[^\(w)*])\\*(?![\(ws)])(.+?)\\*(?![\(w)])")
    let reItalicUnder = JSRegex("(^|[^\(w)])_(?![\(ws)])(.+?)_(?![\(w)])")
    let reStrike = JSRegex("~~(.+?)~~")
    // HTML のコメント (<!-- … -->)・<!DOCTYPE …> と、よく使う HTML のタグ (<br> </p> <img src=…> など) だけを消す。
    // 「<夏>」のような文字の山かっこや、<Enter> <URL> <Tab> のようなキーの名前・書き換える所の印は、手順の一部なので残す
    // (属性は = のあるものだけ。"a<b and c>d" のような不等号を消さないため)
    let htmlTags = "a|abbr|audio|b|blockquote|br|center|code|dd|del|details|div|dl|dt|em|font|h[1-6]|hr|i|img|ins|kbd|li|mark|ol|p|pre|s|small|source|span|strong|sub|summary|sup|table|tbody|td|tfoot|th|thead|tr|u|ul|video"
    let reTag = JSRegex("<!--[\\s\\S]*?-->|<![A-Za-z][^<>]*>|</?(?i:\(htmlTags))(?:\\s*/?|\\s+[^<>]*=[^<>]*|\\s+open\\s*)>")
    // インラインコードの中身を守る印 (私用領域の文字で挟んだ番号。太字・斜体・タグの置き換えを中身に当てない)
    let reCodeMark = JSRegex("\u{E000}([0-9]+)\u{E001}")
    let reSpaces = JSRegex("[\(ws)]+")
    func plain(_ s: String) -> String {
      var t = reImage.replace(s) { _ in "" } // 画像
      t = reLink.replace(t) { $0[1] ?? "" } // リンク
      // インラインコードは中身をそのまま残す (`<Enter>` `snake_case` `a*b*c` を、タグ・斜体として消さない)
      var codes: [String] = []
      t = reCode.replace(t) { codes.append($0[1] ?? ""); return "\u{E000}\(codes.count - 1)\u{E001}" }
      t = reBold.replace(t) { $0[2] ?? "" } // 太字
      t = reItalicStar.replace(t) { ($0[1] ?? "") + ($0[2] ?? "") } // 斜体 *x*
      t = reItalicUnder.replace(t) { ($0[1] ?? "") + ($0[2] ?? "") } // 斜体 _x_ (snake_case は残す)
      t = reStrike.replace(t) { $0[1] ?? "" }
      // <br> は改行なので空白にする (前後の単語がつながらないように)。ほかのタグは消す
      t = reTag.replace(t) { ($0[0] ?? "").lowercased().hasPrefix("<br") ? " " : "" }
      t = reCodeMark.replace(t) { m in m[1].flatMap { Int($0) }.flatMap { $0 < codes.count ? codes[$0] : nil } ?? "" }
      t = reSpaces.replace(t) { _ in " " }
      return JSCompat.trim(t)
    }

    // 本文を「文のまとまり」(段落・リスト項目) に分ける。CJK は改行もまとまりの区切り
    var tableRows = 0 // 読み上げから外した表の行数 (最後に警告する)
    let listItem = JSRegex("^(?:(?:[-*+]|[0-9０-９]+[.．)）])[\(ws)]+|[①-⑳][\(ws)]*)")
    // 記号だけで中身の無いリスト項目 ("2." "-")。段落の途中 (前の行の続き) なら本文 ("gas mark\n5.") として読む
    let bareItem = JSRegex("^(?:[-*+]|[0-9０-９]+[.．)）])$")
    // 番号つきの項目の番号 (段落の途中では、CommonMark と同じく 1 から始まる項目だけを新しいリストとみなす)
    let itemNumber = JSRegex("^([0-9０-９]+)[.．)）]")
    // GFM のタスクリストの記号 ([ ] / [x])
    let reTask = JSRegex("^\\[[ xX]\\][\(ws)]+")
    let reTable = JSRegex(#"^\|.*\|$"#)
    let reRule = JSRegex(#"^(?:-{3,}|\*{3,}|_{3,})$"#)
    let reSubHeading = JSRegex("^#{3,6}[\(ws)]+")
    let reQuote = JSRegex("^>[\(ws)]*")
    let reComma = JSRegex("[、，,]$")
    func units(_ bodyLines: [String]) -> [String] {
      var out: [String] = []
      var cur: String? = nil // 段落の途中なら その文
      var inPara = false // 空行の後、まだ同じまとまり (段落・リスト) の中か
      var lastItem = false // すぐ前の行がリストの項目だったか
      var lastItemNumbered = false // その項目が番号つきか (中身の無い同じ種類の記号だけが、空の次の項目)
      var inList = false // リストの中か (項目の後の、字下げした続きの行・遅延継続の行・項目の中の段落もリストの中)
      var sawBlank = false // すぐ前が空行か
      var prevText = "" // すぐ前の行の文 (読点で終わっていれば、次の行は文の続き)
      var lastNumber = 0 // この工程で最後に読んだ番号つきの項目の番号 (その次の番号は、注記を挟んでもリストの続き)
      var fence = Fence() // コードブロック (```) の中は読み上げない
      func flush() {
        if let c = cur, !c.isEmpty { out.append(c) }
        cur = nil
      }
      for raw in bodyLines {
        let line = JSCompat.trim(raw)
        if fence.feed(line) {
          flush()
          inPara = false
          lastItem = false
          inList = false
          continue
        }
        if fence.isOpen { continue }
        // 表は読み上げない (分量・寸法などの一覧は、絵コンテで画面の注釈に回す)
        if reTable.test(line) {
          tableRows += 1
          flush()
          inList = false
          continue
        }
        if line.isEmpty || reRule.test(line) {
          flush()
          inPara = false
          lastItem = false
          if line.isEmpty { sawBlank = true } else { inList = false }
          continue
        }
        // ### 小見出しは記号を外して、独立した 1 文にする
        let isHeading = reSubHeading.test(line)
        var body = reQuote.replace(line) { _ in "" }
        // 段落の途中 (前の行が項目ではない本文) か
        let midPara = inPara && !lastItem
        // 記号だけの行: 段落の途中なら本文 (年・分量など) として読み、それ以外は中身の無い項目なので読まない
        // (項目のすぐ後なら、同じ種類 (番号つき / 「-」など) の記号だけの行を空の項目とみなす。違う種類なら項目の文の続き)
        if bareItem.test(body) {
          let numbered = itemNumber.test(body)
          if !inPara || (lastItem && numbered == lastItemNumbered) { continue }
        }
        var isItem = isHeading || (listItem.test(body) && !bareItem.test(body))
        // 番号の行は、ふつうはリストの項目 (番号は読まない)。段落の途中 (リストの外) で文の途中と分かるときだけ、数字を本文として残す。番号の「.」は外す
        if isItem && !isHeading && midPara && !inList, let m = itemNumber.match(body), let n = m[1] {
          let rest = body.dropFirst(m[0]?.count ?? 0).drop(while: { $0 == " " || $0 == "\u{3000}" })
          let ascii = String(n.unicodeScalars.map { (0xFF10...0xFF19).contains($0.value) ? Character(UnicodeScalar($0.value - 0xFF10 + 0x30)!) : Character($0) })
          let num = Int(ascii) ?? 0
          // 数字を本文として残すのは、日本語・中国語で前の行が読点で終わるときだけ (「砂糖を大さじ、\n2. 加える」)。
          // 1 から始まる番号と、この工程の前のリストの次の番号は、注記を挟んでもリストの続き (英語などは、前の版と同じくいつも項目)
          let looksMidSentence = cjk && reComma.test(prevText) && num != 1 && num != lastNumber + 1
          if looksMidSentence {
            isItem = false
            body = n + (cjk ? "" : " ") + rest
          }
        }
        // 番号つきの項目なら、その番号を覚える (番号を外す前に)
        if isItem && !isHeading, let n = itemNumber.match(body)?[1] {
          let a = String(n.unicodeScalars.map { (0xFF10...0xFF19).contains($0.value) ? Character(UnicodeScalar($0.value - 0xFF10 + 0x30)!) : Character($0) })
          lastNumber = Int(a) ?? lastNumber
        }
        if isHeading { body = reSubHeading.replace(body) { _ in "" } } else if isItem {
          body = listItem.replace(body) { _ in "" }
          body = reTask.replace(body) { _ in "" }
        }
        inPara = !isHeading
        // リストの中かを決める: 項目ならリストの中。見出しや、空行の後の字下げしていない本文ならリストの外
        if isHeading { inList = false }
        else if isItem { inList = true }
        else if sawBlank && !(raw.first?.isWhitespace ?? false) { inList = false }
        sawBlank = false
        if isItem && !isHeading { lastItemNumbered = itemNumber.test(line.replacingOccurrences(of: "^>[\\s]*", with: "", options: .regularExpression)) }
        lastItem = isItem && !isHeading
        let text = plain(body)
        // 文字も数字も無い行 ("**" だけなど) は読み上げない
        if text.isEmpty || !text.contains(where: { $0.isLetter || $0.isNumber }) { continue }
        prevText = text
        // 前の行が読点で終わっていれば続き (CJK)。英語などは段落内の改行を空白でつなぐ
        let continues = cur != nil && !isItem && (cjk ? reComma.test(cur!) : true)
        if continues { cur! += (cjk ? "" : " ") + text } else {
          flush()
          cur = text
        }
        if isHeading || (cjk && !reComma.test(cur!)) { flush() }
      }
      flush()
      return out
    }

    // 英語などで、文末とみなさないピリオド
    //   abbr: 文末に来ない略語 (常に次とつなぐ) / softAbbr: 文末にも来る単位など (次が小文字・数字で始まるときだけつなぐ)
    let abbr = Set("e.g i.e vs approx cf incl ca fig mr mrs ms dr jr sr".split(separator: " ").map(String.init))
    let softAbbr = Set("etc min mins sec secs hr hrs no nos st oz lb lbs tbsp tsp pt qt max avg a.m p.m".split(separator: " ").map(String.init))
    let reEnd = JSRegex(#"[。．！？!?.…」』）)"”]$"#)
    let reCJKSentence = JSRegex("[^。！？!?]+[。！？!?」』）)]*")
    let reSplit = JSRegex("(?<=[.!?][\"'”’)\\]]{0,64})[\(ws)]+")
    let reLastWord = JSRegex("([^\(ws)]+)\\.$")
    let reOneLetter = JSRegex("^[A-Za-z]$")
    let reLowerStart = JSRegex("^[a-z0-9]")
    // 1 文 = 1 行 (ナレーションとアニメーションの同期単位)
    func sentences(_ text: String) -> [String] {
      func withEnd(_ s: String) -> String { reEnd.test(s) ? s : s + (cjk ? "。" : ".") }
      if cjk { return (reCJKSentence.matchAll(text) ?? [text]).map(JSCompat.trim).filter { !$0.isEmpty }.map(withEnd) }
      let pieces = reSplit.split(text)
      var out: [String] = []
      for p in pieces {
        let prev = out.last
        let last = prev.flatMap { reLastWord.match($0)?[1] }?.lowercased()
        var join = false
        if let last, !last.isEmpty {
          join = abbr.contains(last) || reOneLetter.test(last) || (softAbbr.contains(last) && reLowerStart.test(p))
        }
        if join { out[out.count - 1] = "\(prev!) \(p)" } else { out.append(p) }
      }
      return out.map(JSCompat.trim).filter { !$0.isEmpty }.map(withEnd)
    }

    var title = ""
    var steps: [(heading: String, tag: String?, body: [String])] = []
    var fence = Fence() // コードブロックの中の # / ## は見出しにしない (本文のまま units() で読み上げから外す)
    let reStepHeading = JSRegex("^(.*?)[\(ws)]*(?:[\\[［]([^\\]］]*)[\\]］])?$")
    let reTagName = JSRegex("^[A-Za-z][A-Za-z0-9_-]*$")
    for raw in MD2Script.stripComments(md.utf16.split(separator: 10, omittingEmptySubsequences: false).map { JSCompat.utf16String(ArraySlice($0)) }) {
      let line = JSCompat.trim(raw)
      if fence.feed(line) {
        // フェンスの行は本文に入れて、units() が同じ所でコードブロックに入る
      } else if fence.isOpen {
        // コードブロックの中
      } else if line.utf16.starts(with: "# ".utf16) {
        title = plain(JSCompat.utf16String(Array(line.utf16).dropFirst(2)))
        continue
      } else if line.utf16.starts(with: "## ".utf16) {
        // [tag] は visual 名 (ファイル名・関数名) になるので、英字で始まる英数字・-・_ だけを使う。全角の［］も受け付ける
        let m = reStepHeading.match(JSCompat.utf16String(Array(line.utf16).dropFirst(3))) ?? [nil, "", nil]
        var tag: String? = m[2].map(JSCompat.trim).flatMap { $0.isEmpty ? nil : $0 }
        if let t = tag, !reTagName.test(t) {
          warn("WARN: 工程「\(plain(m[1] ?? ""))」の [\(t)] は visual 名に使えないので無視しました (英字で始まる英数字・-・_ だけ)")
          tag = nil
        }
        steps.append((heading: plain(m[1] ?? ""), tag: tag, body: []))
        continue
      }
      if !steps.isEmpty { steps[steps.count - 1].body.append(raw) }
    }
    if steps.isEmpty { throw fail("工程 (## 見出し) が見つかりません") }
    // 閉じていないコードブロックは、そこから後ろの見出し・本文をすべて読み上げから外してしまうので知らせる
    if fence.isOpen { warn("WARN: コードブロック (``` / ~~~) が閉じていません。そこから後ろは読み上げに入りません (閉じる行を足す)") }

    // 読み方の辞書 (defaults.json の readings。台本の言語 "ja-JP"、無ければ "ja" のもの)。長い語から順に置き換える
    let langBase = String(lang.split(separator: "-", omittingEmptySubsequences: false).first ?? "")
    func byLang(_ map: JSON?) -> JSON? {
      guard let map else { return nil }
      return JSCompat.coalesce(map[lang], map[langBase])
    }
    let readingMap = JSCompat.coalesce(byLang(defaults["readings"]), nil)?.object ?? []
    var readingDict: [(word: [UInt16], reading: String)] = []
    for (word, r) in readingMap {
      guard !word.isEmpty, let r = r.string else { continue }
      if let k = readingDict.firstIndex(where: { $0.word == Array(word.utf16) }) { readingDict[k].reading = r; continue }
      readingDict.append((Array(word.utf16), r))
    }
    // 安定な並べ替え (長い語から)
    let readings = readingDict.enumerated().sorted { a, b in
      a.element.word.count != b.element.word.count ? a.element.word.count > b.element.word.count : a.offset < b.offset
    }.map { $0.element }
    // 1 回の走査で置き換える (置き換えた読みの中をもう一度置き換えない)
    func applyReadings(_ s: String) -> String {
      if readings.isEmpty { return s }
      let u = Array(s.utf16)
      var out: [UInt16] = []
      var i = 0
      while i < u.count {
        if let hit = readings.first(where: { r in i + r.word.count <= u.count && u[i ..< i + r.word.count].elementsEqual(r.word) }) {
          out += Array(hit.reading.utf16)
          i += hit.word.count
        } else {
          // コードポイント単位で進める (u フラグ)
          let n = UTF16.isLeadSurrogate(u[i]) && i + 1 < u.count && UTF16.isTrailSurrogate(u[i + 1]) ? 2 : 1
          out += u[i ..< i + n]
          i += n
        }
      }
      return String(utf16CodeUnits: out, count: out.count)
    }
    if !readings.isEmpty { log("library: 読み方の辞書 (readings) を \(readings.count) 語当てます") }

    func pascal(_ s: String) -> String {
      let r = JSRegex("(^|[-_\(ws)]+)([\(w)])").replace(s) { ($0[2] ?? "").uppercased() }
      return JSRegex("[^\(w)]").replace(r) { _ in "" }
    }
    // visual 名は visuals/<名前>.swift になる。macOS のファイル名は大文字小文字を区別しないので小文字で比べ、
    // visuals/ に置く決まったファイル (bind.swift・props.swift・shared.swift) とも重ならないようにする
    var used: Set<String> = ["bind", "props", "shared"]
    var scenes: [Scene] = []
    for (i, st) in steps.enumerated() {
      var visual = st.tag.map(pascal) ?? String(format: "Step%02d", i + 1)
      while used.contains(visual.lowercased()) { visual += "X" }
      used.insert(visual.lowercased())
      let lines: [JSON] = units(st.body).flatMap(sentences).map { s in
        let speak = applyReadings(s)
        return ja || !JSCompat.same(speak, s) ? .object([("text", .string(s)), ("speak", .string(speak))]) : .string(s)
      }
      if lines.isEmpty { warn("WARN: 工程「\(st.heading)」に本文がありません (読み上げの無い 1 秒ほどの工程になります。見出しを消すか本文を書いてください)") }
      if tableRows > 0 {
        warn("WARN: 工程「\(st.heading)」の表 (\(tableRows) 行) は読み上げから外しました。必要な値は本文の文にし、一覧は絵コンテで画面の注釈 (Callout / PartsList) に回してください")
        tableRows = 0
      }
      scenes.append(Scene(heading: st.heading, visual: visual, lines: lines))
    }

    // 多言語版: 大きさは基準の台本 (--base) から引き継ぐので、縦型かどうかも基準の台本で決める (--vertical は無視)
    let vertical: Bool
    if let base {
      vertical = (JSCompat.coalesce(base["height"], nil)?.double ?? 1080) > (JSCompat.coalesce(base["width"], nil)?.double ?? 1920)
    } else {
      vertical = flags.contains("--vertical")
    }
    var guide: JSON = .object([("kicker", opts["--kicker"].map { .string($0) } ?? JSCompat.coalesce(defaults["kicker"], nil) ?? .string(ja ? "HOW-TO GUIDE" : "STEP-BY-STEP GUIDE"))])
    if let p = opts["--presenter"] ?? JSCompat.coalesce(defaults["presenter"], nil)?.string { guide["presenter"] = .string(p) }
    if JSCompat.truthy(defaults["palette"]) { guide["palette"] = defaults["palette"] }
    var tts: JSON
    if engine == "apple" {
      tts = .object([("voice", "auto"), ("rate", .number(ja ? 0.5 : 0.48))])
    } else {
      tts = .object([])
    }
    for (k, v) in ttsDefaults { tts[k] = v }
    tts["engine"] = .string(engine)
    let style: JSON = vertical
      ? .object([("maxCharsPerCaption", .number(wide ? 18 : 40))])
      : wide
      ? .object([("subtitleFontSize", 38), ("maxCharsPerCaption", 40)])
      : .object([("subtitleFontSize", 34), ("maxCharsPerCaption", 80)])
    var script: JSON = .object([
      ("title", .string(title)),
      ("lang", .string(lang)),
      ("layout", .string(layout)),
      ("guide", guide),
      ("fps", 30),
      ("width", .number(vertical ? 1080 : 1920)),
      ("height", .number(vertical ? 1920 : 1080)),
      ("tts", tts),
      ("gap", 0.45),
      ("sceneGap", 0.9),
      ("padStart", 0.6),
      ("padEnd", 1.4),
      ("style", style),
      ("scenes", .array([])),
    ])
    // 声と速さは言語ごとに違うので、defaults.json の voices / rates から台本の言語 ("ja-JP"、無ければ "ja") のものを選ぶ
    // macOS の声の identifier は com.apple. で始まる。別の engine の声は使わない (--tts で engine を変えたとき)
    // クラウドの TTS の声は voices.<engine> に言語ごとに書く (command やほかのクラウドの声と名前の形が似ていて見分けられないため)。
    // voices の直下 (apple / command 用) の "google" などは言語ではないので、apple / command では使わない
    let cloud = CloudTTS.engines.contains(engine)
    let voice = cloud ? byLang(defaults["voices"]?[engine]) : byLang(defaults["voices"])
    if cloud, !JSCompat.truthy(voice), let flat = byLang(defaults["voices"]), JSCompat.truthy(flat) {
      log("  tts: defaults.json の voices の \"\(JSCompat.string(flat))\" は apple / command 用なので \(engine) では使いません (\(engine) の声は voices.\(engine) に書く)")
    }
    if JSCompat.truthy(voice), cloud || JSCompat.string(voice).hasPrefix("com.apple.") == (engine == "apple") {
      tts["voice"] = voice
    } else if JSCompat.truthy(voice) {
      log("  tts: defaults.json の voices の \"\(JSCompat.string(voice))\" は \(engine) の声ではないので使いません")
    }
    // rates は macOS の声の速さ (0.0〜1.0) なので apple のときだけ
    if let rate = byLang(defaults["rates"]), engine == "apple" { tts["rate"] = rate }
    // クラウドの TTS の設定 (pollyEngine / model / instructions) は、jgv tts で止まる前にここで確かめる
    if cloud {
      // 空の instructions は送らないので外す (jgv tts と同じ)
      if tts["instructions"]?.string == "" { tts["instructions"] = nil }
      do { try CloudTTS.validate(engine, tts) } catch let e as ToolError { throw fail("defaults.json か基準の台本の tts: \(e.message)") }
    }
    script["tts"] = tts
    // 字幕バー / 説明文の表示 (defaults.json の既定。--base があれば基準の台本が優先)
    var styleNow = script["style"]!
    if defaults["captions"] == .bool(false) { styleNow["captions"] = false }
    if defaults["notes"] == .bool(false) { styleNow["notes"] = false }

    // 多言語版: 基準の台本から visual 名と、言語に依存しない設定を引き継ぐ
    var baseVisual: [Int: JSON] = [:] // 基準が { "type": …, …props } の形で書いた visual (props ごと引き継ぐ)
    if let base {
      for k in ["layout", "fps", "width", "height", "gap", "sceneGap", "padStart", "padEnd"] {
        if let v = base[k] { script[k] = v }
      }
      var g: JSON = .object(base["guide"]?.object ?? [])
      if let k = opts["--kicker"], !k.isEmpty { g["kicker"] = .string(k) }
      if let p = opts["--presenter"] { g["presenter"] = .string(p) }
      script["guide"] = g
      for k in ["captions", "notes"] {
        if base["style"]?[k] == .bool(false) { styleNow[k] = false } else { styleNow[k] = nil }
      }
      let baseScenes = base["scenes"]?.array ?? []
      // 基準の visual 名はファイル名・Swift の関数名になるので、jgv が作る名前と同じ形 (英大文字で始まる英数字・_) だけ使う。
      // 他人の台本を基準にしても、visuals/・cues/ の外へ書いたり、雛形の Swift に任意の文字を入れたりしないため
      // 基準が同じ visual を何工程かで使い回すのは基準の設計なので、そのまま引き継ぐ (重なりを避けるのは md2script が作る名前だけ)
      let reserved: Set<String> = ["bind", "props", "shared"]
      var fromBase: [Int: String] = [:]
      var rejected: [Int: String] = [:]
      for i in scenes.indices where i < baseScenes.count {
        guard JSCompat.truthy(baseScenes[i]), let bv = baseScenes[i]["visual"] else { continue }
        // "visual": "Name" のほか、{ "type": "Name", …props } の形も、props ごと引き継ぐ
        guard let b = bv.string ?? bv["type"]?.string else { continue }
        if Safety.isVisualName(b) && !reserved.contains(b.lowercased()) {
          fromBase[i] = b
          if bv.string == nil { baseVisual[i] = bv }
        } else { rejected[i] = b }
      }
      var taken = reserved.union(fromBase.values.map { $0.lowercased() })
      for i in scenes.indices {
        if let b = fromBase[i] { scenes[i].visual = b; continue }
        var v = scenes[i].visual
        while taken.contains(v.lowercased()) { v += "X" }
        taken.insert(v.lowercased())
        if let b = rejected[i] { warn("WARN: 基準の工程 \(i) の visual「\(b)」は visual 名に使えない (英大文字で始まる英数字・_ だけ) ので \(v) にしました") }
        scenes[i].visual = v
      }
      if baseScenes.count != scenes.count { warn("WARN: 工程数が基準 (\(baseScenes.count)) と異なります (\(scenes.count))") }
      let strings = base["strings"]?.object ?? []
      script["strings"] = .object(strings)
      if !strings.isEmpty { log("  strings: 基準の文言をコピーしました。翻訳してください") }
    }
    // 画面上の文字を減らす: 字幕バー / 説明文 (コマンドのオプションが最優先)
    if flags.contains("--no-captions") || flags.contains("--no-text") { styleNow["captions"] = false }
    if flags.contains("--no-notes") || flags.contains("--no-text") { styleNow["notes"] = false }
    script["style"] = styleNow
    script["scenes"] = .array(scenes.enumerated().map { i, s in .object([("heading", .string(s.heading)), ("visual", baseVisual[i] ?? .string(s.visual)), ("lines", .array(s.lines))]) })

    let out = opts["-o"] ?? "script.json"
    do {
      // 書き出す先のフォルダが無ければ作る
      try FileManager.default.createDirectory(at: URL(fileURLWithPath: out).deletingLastPathComponent(), withIntermediateDirectories: true)
      // 置き換えて書く (書く先がシンボリックリンクなら、リンクの先を書き換えずにリンクを外してから書く)
      if Safety.isSymlink(URL(fileURLWithPath: out)) { try FileManager.default.removeItem(atPath: out) }
      try (script.stringify() + "\n").write(toFile: out, atomically: true, encoding: .utf8)
    } catch {
      throw ToolError("\(out) に書き出せません: \(error.localizedDescription)")
    }
    print("OK: \(out) (\(lang), \(scenes.count) steps, \(scenes.reduce(0) { $0 + $1.lines.count }) lines)")
    for s in scenes { print("  \(JSCompat.padEnd(s.visual, 12)) \(s.heading)  (\(s.lines.count) lines)") }

    // 日本語: 読みは jgv yomi で確かめる (語ごとの読みの一覧と、ひらがなの読みがつながる所の警告)
    if lang.hasPrefix("ja") { log("  読み: speak を直したら jgv yomi で確かめてください (誤読しそうな語は speak をカタカナに)") }

    // 仮の visual。あとで本実装に置き換える
    //   部屋 (guide): 人物が指し示し、工程名の注釈
    //   それ以外: コンテンツ領域の中央に工程名の注釈
    if let stubDir = opts["--stubs"], !flags.contains("--swift-stubs") {
      try writeCueStubs(stubDir, scenes: scenes, layout: script["layout"]?.string ?? "guide", vertical: (script["height"]?.double ?? 1080) > (script["width"]?.double ?? 1920))
    } else if let stubDir = opts["--stubs"] {
      if Safety.isSymlink(URL(fileURLWithPath: stubDir)) { throw fail("\(stubDir) がシンボリックリンクです (雛形はふつうのフォルダに書きます)") }
      try FileManager.default.createDirectory(atPath: stubDir, withIntermediateDirectories: true)
      let room = script["layout"]?.string == "guide"
      for (i, s) in scenes.enumerated() {
        let file = JSCompat.pathJoin(stubDir, "\(s.visual).swift")
        if FileManager.default.fileExists(atPath: file) || Safety.isSymlink(URL(fileURLWithPath: file)) { log("  既にあるので書き換えません: \(file)"); continue }
        try stub(step: i + 1, heading: s.heading, visual: s.visual, room: room).write(toFile: file, atomically: true, encoding: .utf8)
        log("  stub: \(file)")
      }
    }
  }

  /// キューの雛形: cues/<Visual>.cue・visuals/<Visual>.swift (CueScene を呼ぶ 1 行)・visuals/bind.swift (binding)。
  /// 既にあるファイルは書き換えない
  static func writeCueStubs(_ stubDir: String, scenes: [Scene], layout: String, vertical: Bool) throws {
    let fm = FileManager.default
    let visuals = URL(fileURLWithPath: stubDir)
    let cues = visuals.deletingLastPathComponent().appendingPathComponent("cues")
    // 雛形を書くフォルダがシンボリックリンクだと、リンクの先 (プロジェクトの外) に書いてしまうので止める
    for d in [visuals, cues] where Safety.isSymlink(d) { throw fail("\(d.path) がシンボリックリンクです (雛形はふつうのフォルダに書きます)") }
    try fm.createDirectory(at: visuals, withIntermediateDirectories: true)
    try fm.createDirectory(at: cues, withIntermediateDirectories: true)
    let phraseRe = try NSRegularExpression(pattern: ".+?(?:[。！？、，]+|[.,!?]+(?:\\s+|$)|$)")
    func phrases(_ t: String) -> [String] {
      let m = phraseRe.matches(in: t, range: NSRange(t.startIndex..., in: t)).compactMap { Range($0.range, in: t).map { String(t[$0]).trimmingCharacters(in: .whitespaces) } }
      return (m.isEmpty ? [t] : m).filter { !$0.isEmpty }
    }
    // キューの文字に書けない記号 (# は注釈、; は命令の区切り、| は notes の区切り、@ は時刻、頭の $ は strings のキー) は全角にする
    func cueText(_ t: String) -> String {
      var s = t
      for (a, b) in [("#", "＃"), (";", "；"), ("|", "｜"), ("@", "＠")] { s = s.replacingOccurrences(of: a, with: b) }
      return s.hasPrefix("$") ? "＄" + s.dropFirst() : s
    }
    func write(_ text: String, _ url: URL) throws {
      if fm.fileExists(atPath: url.path) || Safety.isSymlink(url) {
        note("  既にあるので書き換えません: \(url.path.replacingOccurrences(of: fm.currentDirectoryPath + "/", with: ""))")
        return
      }
      try text.write(to: url, atomically: true, encoding: .utf8)
      note("  stub: \(url.path.replacingOccurrences(of: fm.currentDirectoryPath + "/", with: ""))")
    }
    for (i, s) in scenes.enumerated() {
      // visual 名はファイル名と Swift の関数名になる (md2script が作る名前・基準から検証済みの名前だけのはずだが、念のため)
      guard Safety.isVisualName(s.visual) else { throw fail("visual 名「\(s.visual)」は使えません (英大文字で始まる英数字・_ だけ)") }
      // 行と句の番号 (時刻 L.P の L と P)。読点の無い行は句が 1 つ
      var lines = ["# \(i). \(s.heading) (\(s.visual))  行.句 = 読み始め。書き方は reference/cue.md"]
      for (li, l) in s.lines.enumerated() {
        // 読み方を直していない行は文字列のまま入っている (speak が text と同じ)
        let text = l["text"]?.string ?? l.string ?? ""
        lines.append("# " + phrases(text).enumerated().map { "\(li).\($0.offset) \($0.element)" }.joined(separator: " "))
      }
      lines.append(i == 0 ? "init" : "init <\(scenes[i - 1].visual)")
      // 読み上げる行が無い工程には、時刻 (行.句) で書く命令を置けないので init だけにする
      lines.append(s.lines.isEmpty ? "" : layout == "guide-screen" ? "0.0 notes \(cueText(s.heading))@0.0-.2" : layout == "guide" ? "0.0 H>gesture~.4" : "")
      try write(lines.joined(separator: "\n") + "\n", cues.appendingPathComponent("\(s.visual).cue"))
      try write("import JGVKit\nfunc \(s.visual)(_ props: Props) { CueScene(\"\(s.visual)\", BIND) }\n", visuals.appendingPathComponent("\(s.visual).swift"))
    }
    let hand: String
    var points = "[:]"
    var draw = "{ s in\n    // 全景の道具を状態 s どおりに描く (s[\"名前\"] は数、s.s(\"名前\") は文字、s.obj(\"物\") は位置と倍率)\n  }"
    switch layout {
    case "guide-screen":
      hand = ".finger"
      // 縦型 (1080×1920) では、スマホを上の中央に、ポイントメモをその下に置く
      points = "[\n    \"rest\": { _ in PH.pt(Pt(330, 690)) },\n    \"notes\": { _ in Pt(\(vertical ? "130, 1240" : "1000, 270")) },\n  ]"
      draw = "{ s in\n    PhoneFrame(x: PH.x, y: PH.y, h: PH.h) {\n      // 画面 (設計座標 390×844) を s.s(\"page\") などで描き分ける\n    }\n  }"
    case "guide":
      hand = ".presenter"
    case "guide-topdown":
      hand = ".none"
      points = "[\n    // 右手 = H、左手 = C。front で TopHand(from: topArmFrom(手, .R), to: 手, …) を描く (画面の外では描かない)\n    \"rest\": { _ in Pt(\(vertical ? 800 : 1300), topOffscreenY() + 60) },\n    \"c.away\": { _ in Pt(\(vertical ? 280 : 500), topOffscreenY() + 60) },\n  ]"
    default:
      hand = ".none"
      // 縦型では部品リストを下の左に、工具の定位置を右下に置く (横型の値は画面の外になる)
      points = "[\n    // 手は描かない。H の位置に Screwdriver(tip:) などの工具を front で描く\n    \"rest\": { _ in Pt(\(vertical ? "900, 1560" : "1500, 860")) },\n    \"parts\": { _ in Pt(\(vertical ? "130, 1240" : "1340, 250")) },\n  ]"
    }
    let bind = """
      // この動画の道具・画面の描き方と名前 (全工程のキューで共通)。書き方は reference/cue.md の「binding」
      // 配置: \(vertical ? "縦型 LAYOUT_PORTRAIT (天板 y 1120、拡大カード x 50〜1030・y 1235〜1655)。GUIDE は横型の値なので使わない" : layout == "guide" ? "横型 GUIDE (天板 y 780、拡大カード x 640〜1600・y 250〜750)" : "横型 1920×1080 (見出しは左上、字幕バーは下。\(layout) の置き方の目安は reference/visual-kit.md)")
      import JGVKit
      \(layout == "guide-screen" ? (vertical ? "\nlet PH = phoneSpace(x: 350, y: 340, h: 820)\n" : "\nlet PH = phoneSpace(x: 560, y: 226, h: 652)\n") : "")
      let BIND = CueBinding(
        keys: [],
        objects: [],
        points: \(points),
        places: [:],
        hand: \(hand),
        draw: \(draw),
        front: { s in
          // 道具より手前に描くもの (手元俯瞰の TopHand、説明書の手・工具など)。無ければ空のままでよい
        }
      )

      """
    try write(bind, visuals.appendingPathComponent("bind.swift"))
  }

  /// 仮の visual (visuals/<visual>.swift)
  static func stub(step: Int, heading: String, visual: String, room: Bool) -> String {
    let head = """
      // STEP \(step): \(heading) (仮の visual。工程の絵コンテに合わせて書き換える)
      import JGVKit

      func \(visual)(_ props: Props) {
        let n = useNarration()
        let st = useStage()

      """
    if room {
      return head + """
          Stage {
            Presenter(handR: mix(st.pose.restR, st.pose.gestureR, n.ease(0, -0.2)))
            Callout(x: st.presenter.x + 600, y: st.counterY - 200, text: n.heading, at: n.at(0))
          }
        }

        """
    }
    return head + """
        let c = st.content
        Stage {
          Callout(x: c.x + c.w / 2, y: c.y + c.h / 2, text: n.heading, at: n.at(0))
        }
      }

      """
  }
}

/// コードブロック (``` / ~~~) の開始と終了の行を見分ける。
/// 開始は「``` か ~~~ で始まり、``` のときは同じ行にもうバッククォートが無い行」(行頭のインラインコード ```x``` を開始にしない)、
/// 終了は「開始と同じ記号だけの行」
struct Fence {
  private var mark: Character? = nil
  var isOpen: Bool { mark != nil }

  /// line (前後の空白を除いた行) がフェンスの行なら、状態を進めて true を返す
  mutating func feed(_ line: String) -> Bool {
    guard let c = line.first, c == "`" || c == "~" else { return false }
    let run = line.prefix { $0 == c }
    guard run.count >= 3 else { return false }
    let rest = line.dropFirst(run.count)
    if let m = mark {
      guard m == c, rest.allSatisfy({ $0 == " " || $0 == "\t" }) else { return false }
      mark = nil
      return true
    }
    if c == "`" && rest.contains("`") { return false }
    mark = c
    return true
  }
}

extension MD2Script {
  /// 行をまたぐ HTML のコメント (<!-- … -->) を消す (行数は変えない。コードブロックの中はそのまま)。
  /// 1 行の中で閉じるコメントは plain() が消すので、ここでは閉じていないものだけを扱う
  static func stripComments(_ lines: [String]) -> [String] {
    var out: [String] = []
    var fence = Fence()
    var inComment = false
    for raw in lines {
      var line = raw
      if !inComment {
        if fence.feed(JSCompat.trim(raw)) || fence.isOpen { out.append(raw); continue }
      } else {
        guard let end = line.range(of: "-->") else { out.append(""); continue }
        line = String(line[end.upperBound...])
        inComment = false
      }
      // この行で開いて閉じないコメントを探す (閉じるものは読み飛ばす)
      var from = line.startIndex
      while let open = line.range(of: "<!--", range: from ..< line.endIndex) {
        if let close = line.range(of: "-->", range: open.upperBound ..< line.endIndex) { from = close.upperBound; continue }
        line = String(line[..<open.lowerBound])
        inComment = true
        break
      }
      out.append(line)
    }
    return out
  }
}
