// jgv: 手順書から、ナレーションに同期したイラストの手順動画を作る CLI (macOS 専用)
import ArgumentParser
import Foundation
import JGVTools

// 引数とオプションはここで ArgumentParser に定義する (ヘルプに出す・知らないオプションを弾くため)。
// 各処理 (JGVTools・プロジェクトの実行ファイル) には、それぞれが読む形の文字列の配列に組み立て直して渡す

protocol JGVCommand: ParsableCommand {
  func exec() throws
}

extension JGVCommand {
  func run() throws {
    do { try exec() } catch let e as ToolError where e.isSilent {
      throw ExitCode.failure
    } catch let e as ToolError {
      stderr("ERROR: \(e.message)\n" + (e.usage.map { "\($0)\n" } ?? ""))
      throw ExitCode.failure
    } catch {
      stderr("ERROR: \(userMessage(error))\n")
      throw ExitCode.failure
    }
  }
}

func stderr(_ s: String) { FileHandle.standardError.write(s.data(using: .utf8)!) }

/// 値があれば ["--name=値"] (プロジェクトの実行ファイルは = の形だけを読む)
func eq(_ name: String, _ v: CustomStringConvertible?) -> [String] { v.map { ["--\(name)=\($0)"] } ?? [] }
/// 立っていれば ["--name"]
func on(_ name: String, _ b: Bool) -> [String] { b ? ["--\(name)"] : [] }
/// 値があれば [値]
func opt(_ v: String?) -> [String] { v.map { [$0] } ?? [] }

struct JGV: ParsableCommand {
  /// 使い方を書いた文書 (ヘルプの最後に出す)
  static let docsURL = "https://github.com/junara/j-swift-guide-video#readme"
  /// 使い方の例 (jgv だけのときと jgv --help の両方に出す)
  static let examples = """
      jgv new my-guide procedure.md   # プロジェクト・台本・音声をまとめて作る
      cd my-guide && jgv dev          # 直した後の確認
      jgv render                      # out/video.mp4 を書き出す
    """
  static let configuration = CommandConfiguration(
    commandName: "jgv",
    abstract: "手順書 (Markdown) から、ナレーション・字幕付きのイラストの手順動画 (MP4) を作る",
    discussion: """
    例:
    \(examples)

    流れ: new → (visuals/bind.swift と cues/*.cue を書く) → dev → render → overview
    サブコマンドごとの引数とオプションは jgv help <サブコマンド> で。
    文書: \(docsURL)
    """,
    version: Project.versionText,
    subcommands: [Prebuild.self],
    groupedSubcommands: [
      CommandGroup(name: "作る", subcommands: [New.self, Init.self, MD2ScriptCmd.self, TTSCmd.self, Timing.self]),
      CommandGroup(name: "確かめる", subcommands: [Dev.self, Check.self, Snapshots.self, Preview.self, YomiCmd.self, Voices.self, Api.self, Catalog.self]),
      CommandGroup(name: "書き出す", subcommands: [Render.self, Still.self, BuildLangs.self, Brief.self, Overview.self]),
      CommandGroup(name: "管理", subcommands: [Clean.self, Migrate.self, VendorKit.self, Open.self]),
    ]
  )

  /// サブコマンドを付けずに実行したときは、短い使い方だけを出す (全部は jgv --help)
  func run() throws {
    stderr("""
    jgv: 手順書 (Markdown) から、ナレーション・字幕付きのイラストの手順動画 (MP4) を作る

    使い方: jgv <サブコマンド> [オプション]

    例:
    \(JGV.examples)

    サブコマンドの一覧は jgv --help、それぞれの使い方は jgv help <サブコマンド>。
    文書: \(JGV.docsURL)

    """)
    throw ExitCode.validationFailure
  }

  /// サブコマンドの名前と、一覧に出すか。名前は各 configuration の commandName (ArgumentParser の非公開の名前に頼らない)。
  /// commandName を書き忘れたサブコマンドがあれば nil (正しいサブコマンドを弾かないよう、打ち間違いの確かめをしない)
  static var subcommandNames: [(name: String, shown: Bool)]? {
    let all = configuration.groupedSubcommands.flatMap(\.subcommands) + configuration.subcommands
    let names = all.compactMap { c in c.configuration.commandName.map { (name: $0, shown: c.configuration.shouldDisplay) } }
    return names.count == all.count ? names : nil
  }

  /// 最初の引数が知らないサブコマンドなら、近い名前を添えて止める (ArgumentParser は「Unexpected argument」としか出さないため)
  static func rejectUnknownSubcommand(_ argv: [String]) {
    // jgv help <サブコマンド> も同じく確かめる
    let rest = argv.first == "help" ? Array(argv.dropFirst()) : argv
    guard let first = rest.first, !first.hasPrefix("-"), let names = subcommandNames else { return }
    let all = names.map(\.name) + ["help"]
    guard !all.contains(first) else { return }
    var msg = "Error: 知らないサブコマンド「\(first)」です。"
    if let near = Suggest.closest(first, in: names.filter(\.shown).map(\.name)) { msg += "もしかして jgv \(near) ?" }
    stderr(msg + "\n  一覧は jgv --help で。\n")
    Foundation.exit(ExitCode.validationFailure.rawValue)
  }
}

// ---------- プロジェクトを作る ----------

struct Init: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "init", abstract: "手順動画のプロジェクトを雛形から作る")
  @Argument(help: "作るプロジェクトのディレクトリ (無ければ作る)") var dir: String
  func exec() throws { try Project.initProject([dir]) }
}

/// md2script と new が共通に受け付けるオプション
struct MD2ScriptOptions: ParsableArguments {
  @Option(name: [.short, .long], parsing: .unconditional, help: ArgumentHelp("書き出す台本", valueName: "script.json")) var output: String?
  @Option(parsing: .unconditional, help: ArgumentHelp("台本の言語 (省略時は手順書から判定)", valueName: "en-US")) var lang: String?
  @Option(parsing: .unconditional, help: "左上のタイトルの上に出す小見出し") var kicker: String?
  @Option(parsing: .unconditional, help: "人物の見た目: male (男性) / female (女性) / neutral (中性、既定)") var presenter: String?
  @Option(parsing: .unconditional, help: ArgumentHelp("キューの雛形を書き出すディレクトリ", valueName: "visuals")) var stubs: String?
  @Option(parsing: .unconditional, help: ArgumentHelp("基準にする台本 (多言語版で visual と工程をそろえる)", valueName: "script.json")) var base: String?
  @Option(parsing: .unconditional, help: "型: guide / guide-screen / guide-topdown / guide-manual (既定 guide)") var layout: String?
  @Option(parsing: .unconditional, help: "読み上げの engine: apple / command / google / azure / amazon / openai") var tts: String?
  @Flag(help: "1080×1920 の縦型にする") var vertical = false
  @Flag(help: "字幕を出さない") var noCaptions = false
  @Flag(help: "注記を出さない") var noNotes = false
  @Flag(help: "字幕と注記を出さない") var noText = false
  @Flag(help: "ライブラリの defaults.json を使わない") var noLibrary = false
  @Flag(help: "--stubs にキューではなく Swift の雛形を書き出す") var swiftStubs = false

  var args: [String] {
    var a: [String] = []
    for (k, v) in [("-o", output), ("--lang", lang), ("--kicker", kicker), ("--presenter", presenter), ("--stubs", stubs), ("--base", base), ("--layout", layout), ("--tts", tts)] {
      if let v { a += [k, v] }
    }
    for (k, b) in [("--vertical", vertical), ("--no-captions", noCaptions), ("--no-notes", noNotes), ("--no-text", noText), ("--no-library", noLibrary), ("--swift-stubs", swiftStubs)] where b {
      a.append(k)
    }
    return a
  }
}

struct New: JGVCommand {
  static let configuration = CommandConfiguration(
    commandName: "new", abstract: "プロジェクトを作り、台本・キューの雛形・音声を作って、キューの時刻の表を出す",
    discussion: """
    init → md2script --stubs visuals → tts → timing を 1 回で行う。手順書を渡さなければ <dir>/procedure.md を使う。

    例:
      jgv new my-guide procedure.md
      jgv new my-guide procedure.md --layout guide-screen --presenter female
      jgv new my-guide procedure.md --vertical --no-text
    """)
  @Argument(help: "作るプロジェクトのディレクトリ") var dir: String
  @Argument(help: "手順書 (Markdown)") var procedure: String?
  @OptionGroup(title: "md2script のオプション") var md: MD2ScriptOptions
  func exec() throws { try Project.newProject([dir] + opt(procedure) + md.args) }
}

struct MD2ScriptCmd: JGVCommand {
  static let configuration = CommandConfiguration(
    commandName: "md2script", abstract: "手順書 (procedure.md) を台本 (script.json) にする",
    discussion: """
    例:
      jgv md2script procedure.md -o script.json --stubs visuals
      jgv md2script procedure.en.md -o script.en.json --base script.json
    """)
  @Argument(help: "手順書 (Markdown)") var input: String
  @OptionGroup var md: MD2ScriptOptions
  func exec() throws { try MD2Script.run([input] + md.args) }
}

/// プロジェクトの実行ファイル (render・snapshots など) が共通に受け付けるオプション
struct VideoOptions: ParsableArguments {
  @Option(parsing: .unconditional, help: ArgumentHelp("timeline の場所", valueName: ".jgv/timeline.json")) var timeline: String?
  var args: [String] { eq("timeline", timeline) }
}

// ---------- 音声と確認 ----------

struct TTSCmd: JGVCommand {
  static let configuration = CommandConfiguration(
    commandName: "tts", abstract: "読み上げ音声・timeline・字幕を作る",
    discussion: """
    例:
      jgv tts
      jgv tts script.en.json --keep-audio
      jgv tts --allow-cloud               # script.json の tts.engine がクラウドのとき (一度でよい)
    """)
  @Argument(help: "台本 (既定 script.json)") var script: String?
  @Flag(help: "この台本で使わなくなった音声を消さない (多言語版で、ほかの台本の音声を残す)") var keepAudio = false
  @Flag(help: "このプロジェクトで有料のクラウドの TTS (script.json の tts.engine) を使うことを認める (一度でよい)") var allowCloud = false
  func exec() throws {
    // 台本の名前に - で始まるもの (-- の後のオプションなど) は受け付けない (jgv の中だけで使うオプションを渡せないように)
    if let script, script.hasPrefix("-") { throw ToolError("台本の名前「\(script)」は使えません (- で始まらないファイル名を渡してください)") }
    try TTS.run(opt(script) + on("keep-audio", keepAudio) + on("allow-cloud", allowCloud))
    Project.prebuildInBackground(URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
  }
}

struct Timing: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "timing", abstract: "キューを書くための時刻の表 (工程ごとの 行.句 と、工程の始まりからの秒) を出す")
  @Argument(help: "台本 (渡すと先にその台本で jgv tts をする。言語版の表を見るとき)") var script: String?
  @Flag(help: "JSON で出す") var json = false
  func exec() throws { try Project.timing(opt(script) + on("json", json)) }
}

struct Dev: JGVCommand {
  static let configuration = CommandConfiguration(
    commandName: "dev", abstract: "直した後の確認をまとめて行う",
    discussion: """
    音声・timeline を作り直し (変わった行だけ) → ビルド → check → 変わった工程だけ snapshots

    例:
      jgv dev
      jgv dev --all
    """)
  @Argument(help: "台本 (既定 script.json)") var script: String?
  @Flag(help: "すべての工程の snapshots を撮り直す") var all = false
  @Flag(help: "この台本で使わなくなった音声を消さない (多言語版で、ほかの台本の音声を残す)") var keepAudio = false
  func exec() throws { try Project.dev(opt(script) + on("all", all) + on("keep-audio", keepAudio)) }
}

struct Check: JGVCommand {
  static let configuration = CommandConfiguration(
    commandName: "check", abstract: "キュー (cues/*.cue) の手の時刻表・始まりと終わりの状態・問題と、工程の境目の違いを文字で出す",
    discussion: """
    問題 (! の行) があれば終了コード 1。

    例:
      jgv check
      jgv check script.en.json
      jgv check --json
    """)
  @Argument(help: "台本 (渡すと先にその台本で jgv tts をする。言語版を確かめるとき)") var script: String?
  @Flag(help: "JSON で出す") var json = false
  @OptionGroup var vopts: VideoOptions
  func exec() throws {
    if let script {
      if script.hasPrefix("-") { throw ToolError("台本の名前「\(script)」は使えません (- で始まらないファイル名を渡してください)") }
      try TTS.run([script, "--keep-audio"])
    }
    try Project.runVideo(["check"] + vopts.args + on("json", json))
  }
}

struct YomiCmd: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "yomi", abstract: "日本語の台本の読み方を確かめる")
  @Argument(help: "台本 (既定 script.json)") var script: String?
  @Flag(help: "問題があっても失敗にしない (警告だけ出す)") var warnOnly = false
  func exec() throws { try Yomi.run(opt(script) + on("warn-only", warnOnly)) }
}

struct Voices: JGVCommand {
  enum Engine: String, EnumerableFlag {
    case google, azure, amazon, openai
    static func help(for value: Engine) -> ArgumentHelp? { "\(value.rawValue) の声を出す (クラウドの TTS)" }
  }
  static let configuration = CommandConfiguration(
    commandName: "voices", abstract: "使える声を一覧表示する (既定は macOS の音声を品質の高い順に)",
    discussion: """
    例:
      jgv voices
      jgv voices en-US
      jgv voices ja-JP --google
    """)
  @Argument(help: "言語 (既定 ja。クラウドの TTS では ja-JP)") var lang: String?
  @Flag var engine: Engine?
  @Option(parsing: .unconditional, help: ArgumentHelp("Amazon Polly の engine (--amazon のとき)", valueName: "neural")) var pollyEngine: String?
  func validate() throws {
    if pollyEngine != nil && engine != .amazon { throw ValidationError("--polly-engine は --amazon のときだけ使えます") }
  }
  func exec() throws { try Project.voices(on(engine?.rawValue ?? "", engine != nil) + opt(lang) + eq("polly-engine", pollyEngine)) }
}

struct Snapshots: JGVCommand {
  static let configuration = CommandConfiguration(
    commandName: "snapshots", abstract: "各行・各句・工程の境目の静止画の一覧を書き出す (out/snapshots/sheet.png)",
    discussion: """
    --at は --scene と一緒に使う。--seams は --scene・--phrases と同時に使えない。

    例:
      jgv snapshots --scene 0 --phrases
      jgv snapshots --seams
      jgv snapshots --scene 3 --at 1.5,2.3
    """)
  @Option(help: ArgumentHelp("この工程だけを撮る (0 始まり。STEP 01 は 0。その工程だけでビルドする)", valueName: "N")) var scene: Int?
  @Flag(help: "句ごとに撮る") var phrases = false
  @Flag(help: "工程の境目を撮る") var seams = false
  @Option(parsing: .unconditional, help: ArgumentHelp("工程の始まりからの秒をカンマ区切りで", valueName: "秒,秒")) var at: String?
  @Option(parsing: .unconditional, help: ArgumentHelp("書き出した動画からコマを取る", valueName: "out/video.mp4")) var video: String?
  @OptionGroup var vopts: VideoOptions
  func exec() throws {
    var a: [String] = ["snapshots"] + vopts.args
    a += eq("scene", scene) + on("phrases", phrases)
    a += on("seams", seams) + eq("at", at)
    a += eq("video", video)
    try Project.runVideo(a)
  }
}

struct Preview: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "preview", abstract: "この動画で描いた道具の見本 (〜_PREVIEW) を out/preview.png に並べる")
  @Argument(help: "見本を出すファイル名 (visuals/props など。省略時はすべて)") var files: [String] = []
  @OptionGroup var vopts: VideoOptions
  func exec() throws { try Project.runVideo(["preview"] + vopts.args + files) }
}

struct Catalog: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "catalog", abstract: "kit の道具の一覧を書き出す (out/props-catalog.png)")
  @Option(name: [.short, .customLong("output")], parsing: .unconditional, help: ArgumentHelp("書き出す先", valueName: "out/props-catalog.png")) var out: String?
  func exec() throws { try Project.runVideo(["catalog"] + eq("out", out)) }
}

struct Api: JGVCommand {
  static let configuration = CommandConfiguration(
    commandName: "api", abstract: "kit とプロジェクトの parts/ の関数・定数・型を、宣言と説明で引く",
    discussion: "例: jgv api やかん / jgv api Kettle / jgv api 持つ所。語を渡さなければファイルごとの名前の一覧。")
  @Argument(help: "探す語 (すべてを含むものを出す)") var words: [String] = []
  @Flag(help: "JSON で出す (当たるものをすべて。語が無ければ行頭の宣言をすべて)") var json = false
  func exec() throws { try ApiTool.run(words + on("json", json)) }
}

// ---------- 書き出す ----------

struct Render: JGVCommand {
  static let configuration = CommandConfiguration(
    commandName: "render", abstract: "動画を書き出す (out/video.mp4)",
    discussion: """
    例:
      jgv render
      jgv render -o out/video.en.mp4      # 言語版 (先に jgv tts script.en.json)
    """)
  @Option(name: [.short, .customLong("output")], parsing: .unconditional, help: ArgumentHelp("書き出す先", valueName: "out/video.mp4")) var out: String?
  @OptionGroup var vopts: VideoOptions
  func exec() throws { try Project.runVideo(["render"] + vopts.args + eq("out", out)) }
}

struct Still: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "still", abstract: "1 コマだけを書き出す (out/still.png)")
  @Option(help: ArgumentHelp("書き出すフレームの番号", valueName: "N")) var frame: Int
  @Option(help: ArgumentHelp("大きさの倍率 (既定 1)", valueName: "倍率")) var scale: Double?
  @Option(name: [.short, .customLong("output")], parsing: .unconditional, help: ArgumentHelp("書き出す先", valueName: "out/still.png")) var out: String?
  @OptionGroup var vopts: VideoOptions
  func exec() throws { try Project.runVideo(["still"] + vopts.args + eq("frame", frame) + eq("scale", scale) + eq("out", out)) }
}

struct BuildLangs: JGVCommand {
  static let configuration = CommandConfiguration(
    commandName: "build-langs", abstract: "script.json と script.<言語>.json をすべて書き出す",
    discussion: """
    script.json → out/video.mp4、script.en.json → out/video.en.mp4。script.json は default で指定する。

    例:
      jgv build-langs
      jgv build-langs default en
    """)
  @Argument(help: "書き出す言語 (en zh … 省略時はすべて)") var langs: [String] = []
  @Flag(help: "書き出す前に台本ごとの jgv check をしない") var noCheck = false
  func exec() throws { try Project.buildLangs(langs + (noCheck ? ["--no-check"] : [])) }
}

struct Brief: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "brief", abstract: "工程担当のサブエージェント向けの資料 (brief.md) を作る")
  @Argument(help: "プロジェクトのディレクトリ (既定 .)") var dir: String?
  func exec() throws { try BriefTool.run(opt(dir)) }
}

struct Overview: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "overview", abstract: "工程ごとのナレーション・visual・静止画と SVG の素材を 1 ページにまとめる (out/overview.html)")
  @Argument(help: "プロジェクトのディレクトリ (既定 .)") var dir: String?
  func exec() throws { try OverviewTool.run(opt(dir)) }
}

// ---------- 管理 ----------

struct Migrate: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "migrate", abstract: "前の形式のプロジェクト (Package.swift・Kit/ がある) を今の形式にする")
  func exec() throws { try Project.migrate([]) }
}

struct VendorKit: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "vendor-kit", abstract: "skill の kit をプロジェクトの kit/ に写して固定する (kit/ を消すと skill の kit に戻る)")
  func exec() throws { try Project.vendorKit([]) }
}

struct Open: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "open", abstract: "ビルド用のパッケージを Xcode で開く (補完を使って visual を書くとき)")
  func exec() throws { try Project.openPackage([]) }
}

struct Clean: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "clean", abstract: "このプロジェクトのビルドのキャッシュを消す (skill の kit を使うプロジェクトでは、全プロジェクトで共有の kit のビルドも作り直す)")
  @Flag(help: "フォルダが無くなったプロジェクトの分・共有のビルドにする前の分・置き場の無くなった skill の分 (古い版の jgv のビルドを含む) などを、すべて消す") var stale = false
  @Flag(name: [.customShort("n"), .long], help: "消さずに、消すものを出すだけ") var dryRun = false
  func exec() throws { try Project.clean(on("stale", stale) + on("dry-run", dryRun)) }
}

struct Prebuild: JGVCommand {
  static let configuration = CommandConfiguration(commandName: "prebuild", abstract: "共有のパッケージで kit だけをビルドする (jgv init・jgv tts が裏で使う)", shouldDisplay: false)
  @Argument(help: "プロジェクトのディレクトリ (既定 .)") var dir: String?
  func exec() throws { try Project.prebuild(opt(dir)) }
}

// Swift 6 (Xcode 16) が macOS 14.5 以降なので、ビルドできた時点で 14.5 以降のはず。念のため確かめる
let os = ProcessInfo.processInfo.operatingSystemVersion
guard os.majorVersion > 14 || (os.majorVersion == 14 && os.minorVersion >= 5) else {
  stderr("ERROR: macOS 14.5 以降が必要です\n")
  exit(1)
}
JGV.rejectUnknownSubcommand(Array(CommandLine.arguments.dropFirst()))
JGV.main()
