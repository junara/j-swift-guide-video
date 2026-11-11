// jgv new: プロジェクトを作り、手順書を台本とキューの雛形にし、音声と timeline を作って、キューを書くための時刻の表を出す
// (jgv init → jgv md2script --stubs visuals → jgv tts → jgv timing を 1 回で)。
// jgv timing: 時刻の表だけを出す (読み方を直して jgv tts をやり直した後など)
import Foundation
import JGVCore

extension Project {
  public static let newUsage = "usage: jgv new <dir> [procedure.md] [md2script のオプション (--layout guide --kicker … など)]"

  public static func newProject(_ args: [String]) throws {
    // md2script と同じ読み方で、位置引数 (dir と手順書) とオプションを分ける
    var positional: [String] = []
    var options: [String] = []
    // オプションの値は、名前の位置から引く (--kicker -o のように値が別のオプションの名前でも取り違えないように)
    var valueAt: [String: Int] = [:] // 値をとるオプションの名前 → options の中の値の位置 (同じオプションは後のものが勝つ)
    var flags: Set<String> = []
    var i = 0
    while i < args.count {
      let a = args[i]
      if MD2Script.valueOpts.contains(a) {
        guard i + 1 < args.count else { throw ToolError("\(a) に値がありません", usage: newUsage) }
        if a == "--presenter", !MD2Script.presenters.contains(args[i + 1]) {
          throw ToolError("--presenter \"\(args[i + 1])\" は使えません。\(MD2Script.presenters.joined(separator: " / ")) のどれかを指定してください", usage: newUsage)
        }
        valueAt[a] = options.count + 1
        options += [a, args[i + 1]]
        i += 2
        continue
      }
      if a.hasPrefix("-") {
        // プロジェクトを作ってから md2script で止まらないように、先に確かめる
        guard MD2Script.flagOpts.contains(a) else { throw ToolError("不明なオプション: \(a)", usage: newUsage) }
        flags.insert(a)
        options.append(a)
      } else {
        positional.append(a)
      }
      i += 1
    }
    guard let target = positional.first, positional.count <= 2 else { throw ToolError(newUsage) }
    func value(_ name: String) -> String? { valueAt[name].map { options[$0] } }
    let fm = FileManager.default
    let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
    let dir = URL(fileURLWithPath: target, relativeTo: cwd).standardizedFileURL
    let dest = dir.appendingPathComponent("procedure.md")
    let proc = positional.count > 1 ? URL(fileURLWithPath: positional[1], relativeTo: cwd).standardizedFileURL : dest
    // 前の jgv new が Ctrl-C などで途中で止まった (巻き戻せなかった) フォルダなら、続け方とやり直し方を伝える
    let marker = dir.appendingPathComponent(".jgv/new-incomplete")
    if fm.fileExists(atPath: marker.path) || Safety.isSymlink(marker) {
      // 印には、jgv new の前からフォルダがあったかと、前からあった名前を書いてある。前からあったフォルダなら、jgv new が作ったものだけを消すよう伝える。
      // 印はプロジェクトの中のデータ (受け取ったフォルダに入っていることもある) なので、ふつうのファイルだけを読み、
      // 中身は決まった形のものだけを案内に使う (台本の名前にオプションを混ぜて、実行するコマンドの案内を変えられないように)
      let m = Safety.isPlainFile(marker, under: dir) ? try? JSON.read(marker) : nil
      let existed = m?["dirExisted"]?.bool ?? true
      let ours: Set<String> = ["jgv.json", "procedure.md", "script.json", "visuals", "cues", "parts", "assets", "out", ".jgv", ".gitignore"]
      let before = Set((m?["before"]?.array ?? []).compactMap(\.string))
      let made = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { !before.contains($0) && ours.contains($0) }.sorted()
      let redo = existed
        ? "やり直すなら jgv new が作ったもの (\(made.joined(separator: " "))) だけを消してから"
        : "やり直すならフォルダ \(target) を消してから (jgv new が作ったフォルダ)"
      // 台本を -o で別の名前にしていたら、続けるときの jgv tts / timing にもその名前を渡す
      let scName = m?["script"]?.string.flatMap { $0.range(of: "^[A-Za-z0-9_][A-Za-z0-9._/-]*\\.json$", options: .regularExpression) != nil && !$0.contains("..") ? $0 : nil }
      let sc = scName.flatMap { $0 == "script.json" ? nil : " \($0)" } ?? ""
      throw ToolError("\(target) では前の jgv new が途中で止まっています (Ctrl-C など)。続けるなら、台本の tts (engine・command) を確かめてから cd \(target) && jgv tts\(sc) && jgv timing\(sc)、\(redo)同じ jgv new を実行してください")
    }
    guard fm.fileExists(atPath: proc.path) else { throw ToolError("手順書 \(proc.path) がありません", usage: newUsage) }
    // 手順書を渡さず、フォルダの procedure.md を使うときは、ふつうのファイルだけ (リンクでプロジェクトの外の文書を読み込まないように)
    if proc.path == dest.path && !Safety.isPlainFile(dest, under: dir) {
      throw ToolError("\(dest.path) がシンボリックリンクか、ふつうのファイルではありません (使う手順書は jgv new <dir> <手順書> で渡してください)")
    }
    if proc.path != dest.path && fm.fileExists(atPath: dest.path) {
      throw ToolError("\(target) には既に procedure.md があります (それを使うなら手順書を渡さない)")
    }

    // --tts でクラウドの TTS を選んだのにキーが無いときは、何も作る前に止める (作ってから音声で止まって全部巻き戻すより早く気づける)
    if let e = value("--tts"), CloudTTS.engines.contains(e) {
      try CloudTTS.requireCredentials(e)
    }
    // --base は jgv new を実行したフォルダからの相対パス (この後プロジェクトへ移ってから md2script に渡すので、先に絶対パスにする)
    if let bi = valueAt["--base"] {
      let i = bi - 1
      let base = URL(fileURLWithPath: options[i + 1], relativeTo: cwd).standardizedFileURL
      options[i + 1] = base.path
      // 基準の台本の engine を引き継ぐのは、--tts もライブラリの defaults.json の engine も無いとき。
      // それが有料のクラウドの TTS なら、利用者が選んだものではないので、何も作る前に止めて --tts で選んでもらう
      if valueAt["--tts"] == nil {
        let libEngine = flags.contains("--no-library") ? nil
          : Project.libraryDir().flatMap { try? JSON.read($0.appendingPathComponent("defaults.json")) }?["tts"]?["engine"]?.string
        if libEngine == nil, let e = (try? JSON.read(base))?["tts"]?["engine"]?.string, CloudTTS.engines.contains(e) {
          throw ToolError("基準の台本 \(options[i + 1]) は tts.engine が \(e) (\(CloudTTS.name(e))。有料のクラウドの TTS) です。料金がかかってよければ --tts \(e) を付けて、macOS の音声にするなら --tts apple を付けて jgv new をやり直してください")
        }
      }
      // command は、使う engine が command で、コマンドを自分のライブラリの defaults.json に書いていないと、基準の台本のコマンドを
      // そのまま実行することになる。jgv new はすぐ音声を作るので、そのときは何も作る前に止める (--tts command を付けても同じ)
      let lib = flags.contains("--no-library") ? nil : Project.libraryDir().flatMap { try? JSON.read($0.appendingPathComponent("defaults.json")) }
      let ttsOpt = value("--tts")
      let baseTTS = (try? JSON.read(base))?["tts"]
      let engine = ttsOpt ?? lib?["tts"]?["engine"]?.string ?? baseTTS?["engine"]?.string ?? "apple"
      if engine == "command", lib?["tts"]?["command"] == nil, let cmd = baseTTS?["command"] {
        // --no-library のときは defaults.json を読まないので、書いても効かない。案内を分ける
        let own = flags.contains("--no-library")
          ? "自分のコマンドを使うなら --no-library を外して、ライブラリの defaults.json の tts.command を使い"
          : "自分のコマンドを使うならライブラリの defaults.json に tts.command を書いてから"
        throw ToolError("このままでは基準の台本 \(options[i + 1]) の tts.command \(cmd.description) を実行することになります。\(own)、macOS の音声にするなら --tts apple を付けて jgv new をやり直してください")
      }
    }
    // 途中で止まったら、jgv new が作ったものを消して元に戻す (直して同じ jgv new をやり直せるように)
    let dirExisted = fm.fileExists(atPath: dir.path)
    // md2script は台本 (-o。既定 script.json) を上書きするので、前からあれば中身を控えて、止まったときに戻す
    let scriptRel = value("-o") ?? "script.json"
    let scriptURL = URL(fileURLWithPath: scriptRel, relativeTo: dir).standardizedFileURL
    let scriptBefore = Safety.isRegularFile(scriptURL) ? try? Data(contentsOf: scriptURL) : nil
    let consentBefore = Set(((try? fm.contentsOfDirectory(atPath: Project.cacheDir(dir).path)) ?? []).filter { $0.hasPrefix("allow-cloud-") })
    // シンボリックリンクだったときは、リンクとして戻す (md2script はリンクを外して書くので)
    let scriptLinkBefore = Safety.isSymlink(scriptURL) ? try? fm.destinationOfSymbolicLink(atPath: scriptURL.path) : nil
    let before = Set((try? fm.contentsOfDirectory(atPath: dir.path)) ?? [])
    // 無いフォルダを作るときは、jgv init が作るいちばん上のフォルダ (a/b/c で a も無ければ a) を消す
    var topCreated = dir
    while !fm.fileExists(atPath: topCreated.deletingLastPathComponent().path) { topCreated = topCreated.deletingLastPathComponent() }
    var initDone = false // jgv init がこのフォルダをプロジェクトにしたか (止まったときに、中身ごと消してよいのはその後だけ)
    do {
      try initProject([target], quiet: true, prebuild: false)
      initDone = true
      // 終わるまで「途中」の印を置く (Ctrl-C で止まると巻き戻せないので、次の jgv new で案内する)。終わったら消す
      let incomplete = dir.appendingPathComponent(".jgv/new-incomplete")
      // .jgv/ がシンボリックリンクなら、リンクの先に印を書かない (この後の jgv tts も同じ理由で止まる)
      try Safety.requireNoSymlinks(under: dir, incomplete.deletingLastPathComponent())
      try fm.createDirectory(at: incomplete.deletingLastPathComponent(), withIntermediateDirectories: true)
      let mark: JSON = ["dirExisted": .bool(dirExisted), "before": .array(before.sorted().map { .string($0) }), "script": .string(scriptRel)]
      try Data((mark.stringify() as String).utf8).write(to: incomplete, options: .atomic)
      if proc.path != dest.path { try fm.copyItem(at: proc, to: dest) }
      guard fm.changeCurrentDirectoryPath(dir.path) else { throw ToolError("\(dir.path) に移れません") }
      var md = ["procedure.md"] + options
      if valueAt["-o"] == nil { md += ["-o", "script.json"] }
      if valueAt["--stubs"] == nil { md += ["--stubs", "visuals"] }
      try MD2Script.run(md)
      let script = scriptRel
      // jgv new が自分で作った台本なので、クラウドの TTS は利用者が選んだもの (--tts かライブラリの defaults.json)
      // (--base でクラウドの engine を引き継ぐだけのときは、上で止めてある)
      try TTS.run([script, "--allow-cloud"])
    } catch {
      _ = fm.changeCurrentDirectoryPath(cwd.path)
      // 巻き戻すので「途中」の印は要らない (前からあった .jgv/ の中に書いたときも消す)
      if !Safety.isSymlink(dir.appendingPathComponent(".jgv")) { try? fm.removeItem(at: dir.appendingPathComponent(".jgv/new-incomplete")) }
      var removed = false
      // 台本が書き換わっていたときだけ戻す (何も作る前に止まったときは触らない)
      if let scriptBefore, (try? Data(contentsOf: scriptURL)) != scriptBefore, (try? scriptBefore.write(to: scriptURL, options: .atomic)) != nil { removed = true }
      // jgv new が書いたクラウドの TTS の同意の印も消す (前から認めていたものは残す)。同じ場所に後から置いたほかの台本に効かないように
      for f in (try? fm.contentsOfDirectory(atPath: Project.cacheDir(dir).path)) ?? [] where f.hasPrefix("allow-cloud-") && !consentBefore.contains(f) {
        try? fm.removeItem(at: Project.cacheDir(dir).appendingPathComponent(f))
      }
      if let scriptLinkBefore, !Safety.isSymlink(scriptURL) || (try? fm.destinationOfSymbolicLink(atPath: scriptURL.path)) != scriptLinkBefore {
        try? fm.removeItem(at: scriptURL)
        if (try? fm.createSymbolicLink(atPath: scriptURL.path, withDestinationPath: scriptLinkBefore)) != nil { removed = true }
      }
      if dirExisted {
        // jgv new が作る名前のものだけ消す (実行中にほかのアプリがこのフォルダに置いたものは残す)
        let ours: Set<String> = ["jgv.json", "procedure.md", "script.json", "visuals", "cues", "parts", "assets", "out", ".jgv", ".gitignore"]
        // -o と --stubs に渡した先 (sub/script.json なら sub) も jgv new が作ったもの
        let given = ["-o", "--stubs"].compactMap { o in value(o)?.split(separator: "/").first.map(String.init) }
        let created = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { !before.contains($0) && (ours.contains($0) || given.contains($0)) }
        for name in created where (try? fm.removeItem(at: dir.appendingPathComponent(name))) != nil { removed = true }
      } else if fm.fileExists(atPath: topCreated.path) {
        // 消すのは jgv new が作ったプロジェクトのフォルダだけ。jgv init が止まった (同時に動いた別の jgv new が先に作った など) ときは、
        // 中身のあるフォルダを消さない。上のフォルダ (a/b/c の a・b) は、実行中にほかのものが置かれていなければ (空なら) 消す
        if initDone { removed = (try? fm.removeItem(at: dir)) != nil }
        var d = dir
        while d.path.hasPrefix(topCreated.path), d.path.count >= topCreated.path.count {
          if fm.fileExists(atPath: d.path), rmdir(d.path) != 0 { break }
          removed = true
          if d.path == topCreated.path { break }
          d = d.deletingLastPathComponent()
        }
      }
      // 何も作る前に止まった (既に jgv.json がある など) ときは、元に戻したとは言わない
      if removed { note("jgv new が作ったものを消して元に戻しました。原因を直して、同じ jgv new をやり直してください") }
      throw error
    }
    try? fm.removeItem(at: dir.appendingPathComponent(".jgv/new-incomplete"))
    print("OK: \(target) を作成しました")
    print("")
    try timing([])
    // kit が古ければ裏でビルドしておく (キューを書いている間に終わる)。途中で止まったときは消したフォルダを作り直さないよう、ここで始める
    prebuildInBackground(dir)
  }

  /// キューを書くための時刻の表: 工程ごとに、行.句 (cues/<工程>.cue の時刻の番号) と、工程の始まりからの秒
  /// 台本を渡すと (jgv timing script.en.json)、先にその台本で jgv tts をしてから出す (言語版の時刻の表を見るため)
  public static func timing(_ args: [String]) throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    try requireProject(root)
    if let script = args.first(where: { !$0.hasPrefix("--") }) { try TTS.run([script, "--keep-audio"]) }
    let url = timelineFile(root)
    // build-langs が中断で残した言語版の timeline のままなら、先に基準の台本のものへ戻す
    if restoreBuildLangsBackup(root) { note("前の jgv build-langs が途中で止まっていたので、timeline と字幕を基準の台本のものに戻しました") }
    else if FileManager.default.fileExists(atPath: workDir(root).appendingPathComponent("build-langs-backup").path) {
      note("WARN: jgv build-langs の控えが残っています (動いている途中か、out/ がリンクで戻せない)。この表は言語版の timeline のものかもしれません。基準の表は jgv tts の後に")
    }
    guard FileManager.default.fileExists(atPath: url.path) else { throw ToolError("\(timelineFileName) がありません (先に jgv tts を実行してください)") }
    // timeline はプロジェクトのふつうのファイルだけ読む (リンクの先の中身を表に出さないように)
    guard Safety.isPlainFile(url, under: root) else { throw ToolError("\(timelineFileName) がシンボリックリンクか、ふつうのファイルではありません (jgv tts で作り直してください)") }
    let tl = try Timeline.load(url)
    func sec(_ x: Double) -> String { String(format: "%.2f", x) }
    /// 工程の動きを書くファイル (キューの工程なら cues/<V>.cue、Swift で描く工程なら visuals/<V>.swift)
    func fileOf(_ v: String) -> String {
      FileManager.default.fileExists(atPath: root.appendingPathComponent("cues/\(v).cue").path) ? "cues/\(v).cue" : "visuals/\(v).swift"
    }
    func phrasesOf(_ l: Line) -> [Caption] { l.phrases.isEmpty ? [Caption(text: l.text, start: l.start, end: l.start + l.duration)] : l.phrases }
    if args.contains("--json") {
      // 秒は工程の始まりから (小数 2 桁に丸める)
      func r2(_ x: Double) -> JSON { .number((x * 100).rounded() / 100) }
      let scenes: [JSON] = tl.scenes.map { s in
        var phrases: [JSON] = []
        for (li, l) in tl.lines.filter({ $0.sceneIndex == s.index }).enumerated() {
          for (pi, p) in phrasesOf(l).enumerated() {
            phrases.append(.object([("id", .string("\(li).\(pi)")), ("line", .number(Double(li))), ("phrase", .number(Double(pi))),
                                    ("start", r2(p.start - s.start)), ("end", r2(p.end - s.start)), ("text", .string(p.text))]))
          }
        }
        return .object([("index", .number(Double(s.index))), ("visual", s.visual.map { .string($0.type) } ?? .null), ("heading", .string(s.heading)),
                        ("duration", r2(s.end - s.start)), ("cue", s.visual.map { .string(fileOf($0.type)) } ?? .null), ("phrases", .array(phrases))])
      }
      print(JSON.object([("scenes", .array(scenes))]).description)
      return
    }
    print("キューの時刻 (行.句 と、工程の始まりからの秒):")
    for s in tl.scenes {
      print("S\(s.index) \(s.visual?.type ?? "-") 「\(s.heading)」 長さ \(sec(s.end - s.start))s → \(s.visual.map { fileOf($0.type) } ?? "-")")
      for (li, l) in tl.lines.filter({ $0.sceneIndex == s.index }).enumerated() {
        for (pi, p) in phrasesOf(l).enumerated() {
          print("  \(li).\(pi) \(sec(p.start - s.start))s \(p.text)")
        }
      }
    }
  }
}
