// 動画プロジェクトのファイルの置き場所・作成 (jgv init)・前の形式からの移行 (jgv migrate)・kit の固定 (jgv vendor-kit)・多言語版の一括書き出し
// (ビルドと実行は Build.swift)
import Foundation
import JGVCore

public enum Project {
  /// skill のディレクトリ (Package.swift・Sources/ がある所)
  public static var skillDir: URL = {
    if let s = ProcessInfo.processInfo.environment["J_GUIDE_VIDEO_SKILL"], !s.isEmpty { return URL(fileURLWithPath: s) }
    // このファイルは <skill>/Sources/JGVTools/Project.swift
    return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  }()

  static let kitModules = ["JGVCore", "JGVKit", "JGVRender"]

  /// ユーザーのライブラリ ($J_GUIDE_VIDEO_LIBRARY、未設定なら $XDG_CONFIG_HOME/j-guide-video、それも無ければ ~/.config/j-guide-video。空文字で無効)
  public static func libraryDir() -> URL? {
    let env = ProcessInfo.processInfo.environment
    if let l = env["J_GUIDE_VIDEO_LIBRARY"] { return l.isEmpty ? nil : URL(fileURLWithPath: l) }
    let base = env["XDG_CONFIG_HOME"].flatMap { $0.isEmpty ? nil : $0 } ?? (NSHomeDirectory() + "/.config")
    return URL(fileURLWithPath: base).appendingPathComponent("j-guide-video")
  }

  // ---------- プロジェクトのファイル ----------
  // jgv.json             … プロジェクトの印 (形式の版と、作ったときの skill の版)
  // procedure.md・storyboard.md・script*.json … 手順書・絵コンテ・台本
  // visuals/*.swift      … 工程ごとの visual と補助ファイル
  // parts/*.swift        … ユーザーのライブラリの部品 (jgv init がコピー。編集しない)
  // assets/*.svg         … 道具などの静止した見た目 (Svg("名前") で描く)
  // kit/                 … jgv vendor-kit で固定した kit (無ければ skill の kit を使う)
  // out/                 … 動画・字幕・brief.md・snapshots/・preview.png・overview.html
  // .jgv/                … 途中の生成物 (timeline.json・narration/)

  static let formatVersion = 2
  public static let timelineFileName = ".jgv/timeline.json"
  public static func visualsDir(_ root: URL) -> URL { root.appendingPathComponent("visuals") }
  public static func partsDir(_ root: URL) -> URL { root.appendingPathComponent("parts") }
  public static func assetsDir(_ root: URL) -> URL { root.appendingPathComponent("assets") }
  public static func workDir(_ root: URL) -> URL { root.appendingPathComponent(".jgv") }
  public static func timelineFile(_ root: URL) -> URL { root.appendingPathComponent(timelineFileName) }
  public static func narrationDir(_ root: URL) -> URL { root.appendingPathComponent(".jgv/narration") }

  /// 前の形式 (Package.swift と Kit/ をプロジェクトに持つ) のプロジェクトか
  static func isOldProject(_ root: URL) -> Bool {
    let fm = FileManager.default
    // 前の形式は jgv init が Kit/ (kit の写し) を必ず置いた。Package.swift と Sources/Video だけのほかの Swift パッケージと取り違えないよう、Kit/JGVCore も確かめる
    return fm.fileExists(atPath: root.appendingPathComponent("Package.swift").path) && fm.fileExists(atPath: root.appendingPathComponent("Sources/Video").path)
      && fm.fileExists(atPath: root.appendingPathComponent("Kit/JGVCore").path)
  }

  /// jgv init で作ったプロジェクトの中か確かめる
  public static func requireProject(_ root: URL) throws {
    if FileManager.default.fileExists(atPath: root.appendingPathComponent("jgv.json").path) { return }
    if isOldProject(root) { throw ToolError("前の形式のプロジェクトです (Package.swift・Kit/ がある)。jgv migrate で今の形式にしてください") }
    throw ToolError("jgv.json がありません (jgv init で作ったプロジェクトの中で実行してください)")
  }

  /// jgv.json の中身 (skill の版は git のコミット。わからなければ書かない)
  static func manifestText() -> String {
    var items = ["  \"format\": \(formatVersion)"]
    if let rev = skillRevision() { items.append("  \"skill\": \"\(rev)\"") }
    return "{\n\(items.joined(separator: ",\n"))\n}\n"
  }

  /// skill の版 (skill のフォルダを最後に変えた git のコミット。git のリポジトリでなければ plugin.json の version)。どちらも無ければ nil
  public static func skillRevision() -> String? {
    // git が無い・リポジトリでないときは Shell.run が失敗するので、plugin.json に進む
    // GIT_OPTIONAL_LOCKS=0: git status が skill のリポジトリの index を書き換えない (jgv は skill のフォルダに書かない)
    var gitEnv = ProcessInfo.processInfo.environment
    gitEnv["GIT_OPTIONAL_LOCKS"] = "0"
    if let rev = (try? Shell.run("git", ["-C", skillDir.path, "log", "-1", "--format=%h", "--", "."], env: gitEnv))?.stdout.trimmingCharacters(in: .whitespacesAndNewlines), !rev.isEmpty {
      // 手元で skill を変えていて、まだコミットしていなければ + を付ける (不具合の報告で版を取り違えないように)
      let dirty = !((try? Shell.run("git", ["-C", skillDir.path, "status", "--porcelain", "--", "."], env: gitEnv))?.stdout.isEmpty ?? true)
      return dirty ? rev + "+" : rev
    }
    // plugin として入れたとき (キャッシュは git のリポジトリではない) は、plugin.json の version を使う
    let manifest = skillDir.appendingPathComponent("../../../.claude-plugin/plugin.json").standardizedFileURL
    if let j = try? JSON.read(manifest), let v = j["version"]?.string, !v.isEmpty { return "v\(v)" }
    return nil
  }

  /// jgv --version に出す文字列
  public static var versionText: String {
    "jgv (skill \(skillRevision() ?? "unknown"), project format \(formatVersion))\nskill: \(skillDir.path)"
  }

  static let gitignore = ".jgv/\nout/\n"

  // ---------- jgv init ----------

  /// 手順動画のプロジェクトを作る。ライブラリの parts/ にある自作の部品 (*.swift) を parts/ にコピーする
  /// quiet: jgv new から呼ぶとき (次にすることの案内を出さない)。prebuild: kit が古ければ裏でビルドを始める
  /// (jgv new は途中で止まったら作ったものを消すので、消した後に裏のビルドがプロジェクトのフォルダを作り直さないよう、成功してから始める)
  public static func initProject(_ args: [String], quiet: Bool = false, prebuild: Bool = true) throws {
    guard let target = args.first(where: { !$0.hasPrefix("--") }) else { throw ToolError("usage: jgv init <target-dir>") }
    let fm = FileManager.default
    let dir = URL(fileURLWithPath: target, relativeTo: URL(fileURLWithPath: fm.currentDirectoryPath)).standardizedFileURL
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    if fm.fileExists(atPath: dir.appendingPathComponent("jgv.json").path) {
      throw ToolError("\(target) には既に jgv.json があります。別のディレクトリを指定してください")
    }
    if isOldProject(dir) { throw ToolError("\(target) は前の形式のプロジェクトです。jgv migrate で今の形式にしてください") }
    try fm.createDirectory(at: visualsDir(dir), withIntermediateDirectories: true)
    try manifestText().write(to: dir.appendingPathComponent("jgv.json"), atomically: true, encoding: .utf8)
    let ignore = dir.appendingPathComponent(".gitignore")
    if !fm.fileExists(atPath: ignore.path) { try gitignore.write(to: ignore, atomically: true, encoding: .utf8) }
    try copyLibraryParts(into: dir)
    if !quiet {
      // 空白などを含むフォルダ名でも、そのまま貼って動く cd にする
      let safe = target.allSatisfy { $0.isLetter || $0.isNumber || "-_./~".contains($0) }
      let cdTarget = safe ? target : "'" + target.replacingOccurrences(of: "'", with: "'\\''") + "'"
      print("OK: \(target) を作成しました。procedure.md を置いて、cd \(cdTarget) してから jgv md2script procedure.md -o script.json --stubs visuals → jgv tts → jgv timing を実行してください（ふだんは jgv new でまとめて行えます。手順は j-guide-video の SKILL.md）。")
    }
    if prebuild { prebuildInBackground(dir) }
  }

  /// ユーザーのライブラリの parts/*.swift をプロジェクトの parts/ にコピーする
  /// (コピーなので、あとでライブラリを変えても作った動画のプロジェクトは変わらない)
  static func copyLibraryParts(into dir: URL) throws {
    guard let lib = libraryDir() else { return }
    let fm = FileManager.default
    let parts = lib.appendingPathComponent("parts")
    let files = ((try? fm.contentsOfDirectory(atPath: parts.path)) ?? []).sorted()
    let swiftFiles = files.filter { $0.hasSuffix(".swift") }
    if !swiftFiles.isEmpty {
      let dst = partsDir(dir)
      // parts/ がシンボリックリンクだと、リンクの先のファイルを上書きしてしまうので止める
      try Safety.requireNoSymlinks(under: dir, dst)
      try fm.createDirectory(at: dst, withIntermediateDirectories: true)
      var copied = 0
      for f in swiftFiles {
        let to = dst.appendingPathComponent(f)
        // 既にあるもの (自分で直した部品や、ほかから持ってきたもの) は上書きしない
        if fm.fileExists(atPath: to.path) || Safety.isSymlink(to) {
          if (try? Data(contentsOf: to)) != (try? Data(contentsOf: parts.appendingPathComponent(f))) {
            note("library: parts/\(f) は既にあるので、ライブラリの部品で上書きしません")
          }
          continue
        }
        try fm.copyItem(at: parts.appendingPathComponent(f), to: to)
        copied += 1
      }
      if copied > 0 { note("library: \(parts.path) の部品 \(copied) ファイルを parts/ にコピーしました") }
    }
  }

  // ---------- jgv migrate ----------

  /// 前の形式のプロジェクト (Package.swift・Kit/・Sources/Video/ を持つ) を今の形式にする。
  /// visual・部品・音声・timeline を移し、kit の写しとビルドの生成物を消す (台本・out/ はそのまま)
  public static func migrate(_ args: [String]) throws {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: fm.currentDirectoryPath)
    guard isOldProject(root) else {
      if fm.fileExists(atPath: root.appendingPathComponent("jgv.json").path) { print("OK: もう今の形式です"); return }
      throw ToolError("Package.swift・Kit/・Sources/Video/ がありません (前の形式のプロジェクトの中で実行してください)")
    }
    let video = root.appendingPathComponent("Sources/Video")
    // 移す元・移す先のフォルダがシンボリックリンクだと、プロジェクトの外のファイルを動かしてしまうので止める
    for rel in ["Sources", "Sources/Video", "Sources/Video/visuals", "Sources/Video/user", "generated", "public", "public/narration",
                "visuals", "parts", ".jgv", ".jgv/narration"] {
      try Safety.requireNoSymlinks(under: root, root.appendingPathComponent(rel))
    }
    // 最後に Sources/ ごと消すので、jgv が作ったもの (Video) 以外があれば止める (自分で足したターゲットを消さないように)
    let otherSources = ((try? fm.contentsOfDirectory(atPath: root.appendingPathComponent("Sources").path)) ?? []).filter { $0 != "Video" && !$0.hasPrefix(".") }
    if !otherSources.isEmpty {
      throw ToolError("Sources/ に jgv が作っていないもの (\(otherSources.sorted().joined(separator: ", "))) があるので移しません。別の場所へ移してから jgv migrate をやり直してください")
    }
    // 動かす前に、行き先に同じ名前のファイルが無いか確かめる
    let known: Set<String> = ["main.swift", "generated", "visuals", "user"]
    let extra = ((try? fm.contentsOfDirectory(atPath: video.path)) ?? []).filter { !known.contains($0) && !$0.hasPrefix(".") }
    var moves: [(URL, URL)] = []
    for (sub, to) in [("visuals", visualsDir(root)), ("user", partsDir(root))] {
      for f in (try? fm.contentsOfDirectory(atPath: video.appendingPathComponent(sub).path)) ?? [] where !f.hasPrefix(".") {
        moves.append((video.appendingPathComponent("\(sub)/\(f)"), to.appendingPathComponent(f)))
      }
    }
    // Sources/Video の直下に置いた自分のファイルも同じモジュールだったので、visuals/ に移す
    for f in extra { moves.append((video.appendingPathComponent(f), visualsDir(root).appendingPathComponent(f))) }
    let oldTimeline = root.appendingPathComponent("generated/timeline.json")
    if fm.fileExists(atPath: oldTimeline.path) { moves.append((oldTimeline, timelineFile(root))) }
    let oldNarration = root.appendingPathComponent("public/narration")
    if fm.fileExists(atPath: oldNarration.path) { moves.append((oldNarration, narrationDir(root))) }
    // 移すもの自体がシンボリックリンクなら止める (リンクは移さない。リンクの先は jgv が作ったものではない)
    if let link = moves.first(where: { Safety.isSymlink($0.0) }) { throw ToolError("\(link.0.path) がシンボリックリンクなので移しません (ふつうのファイルにしてから jgv migrate)") }
    let clash = moves.filter { fm.fileExists(atPath: $0.1.path) }
    if !clash.isEmpty { throw ToolError("移す先に既にファイルがあります: \(clash.map { $0.1.path.replacingOccurrences(of: root.path + "/", with: "") }.joined(separator: ", "))") }

    for (from, to) in moves {
      try fm.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
      try fm.moveItem(at: from, to: to)
    }
    // kit の写し・ビルドの生成物・空になったフォルダを消す
    for item in ["Kit", "Package.swift", "Package.resolved", "Sources", ".build", ".scene"] { try? fm.removeItem(at: root.appendingPathComponent(item)) }
    for item in ["generated", "public"] {
      let u = root.appendingPathComponent(item)
      if ((try? fm.contentsOfDirectory(atPath: u.path)) ?? []).filter({ $0 != ".DS_Store" }).isEmpty { try? fm.removeItem(at: u) }
    }
    try fm.createDirectory(at: visualsDir(root), withIntermediateDirectories: true)
    try manifestText().write(to: root.appendingPathComponent("jgv.json"), atomically: true, encoding: .utf8)
    // jgv init が作った .gitignore なら今の形式のものにする (書き足してあれば .jgv/ だけ足す)
    let ignore = root.appendingPathComponent(".gitignore")
    // .gitignore がシンボリックリンクなら、リンクの先 (プロジェクトの外かもしれない) を読まずにリンクを外して作り直す
    if Safety.isSymlink(ignore) { try fm.removeItem(at: ignore) }
    let cur = (try? String(contentsOf: ignore, encoding: .utf8)) ?? ""
    if cur.isEmpty || cur == ".build\n.scene\nout\npublic/narration\n" {
      try gitignore.write(to: ignore, atomically: true, encoding: .utf8)
    } else if !cur.components(separatedBy: "\n").contains(where: { $0 == ".jgv" || $0 == ".jgv/" }) {
      try (cur + (cur.hasSuffix("\n") ? "" : "\n") + ".jgv/\n").write(to: ignore, atomically: true, encoding: .utf8)
    }
    print("OK: 今の形式にしました (visuals/ \(moves.count) 件を移し、Kit/・Package.swift・Sources/・.build を消しました)")
    if !extra.isEmpty { print("  Sources/Video の直下にあった \(extra.joined(separator: ", ")) は visuals/ に移しました") }
  }

  // ---------- jgv vendor-kit ----------

  /// skill の kit をプロジェクトの kit/ に写して固定する (skill を新しくしても、この動画の見た目が変わらないように)。
  /// kit/ を消すと、また skill の kit を使う
  public static func vendorKit(_ args: [String]) throws {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: fm.currentDirectoryPath)
    try requireProject(root)
    let kit = root.appendingPathComponent("kit")
    // kit/ がシンボリックリンクだと、リンクの先の中身を消して写してしまうので止める
    try Safety.requireNoSymlinks(under: root, kit)
    try fm.createDirectory(at: kit, withIntermediateDirectories: true)
    for m in kitModules {
      let dst = kit.appendingPathComponent(m)
      try? fm.removeItem(at: dst)
      try fm.copyItem(at: skillDir.appendingPathComponent("Sources/\(m)"), to: dst)
    }
    print("OK: kit を kit/ に写しました。このプロジェクトは kit/ でビルドします (kit/ を消すと skill の kit に戻る)")
  }

  // ---------- jgv build-langs ----------

  /// build-langs の控え (.jgv/build-langs-backup) があれば、timeline と字幕をそれに戻して控えを消す。戻したら true。
  /// 控えに無いもの = 基準の台本ではまだ作っていなかったもの。言語版のものを残さないように消す。
  /// build-langs の終わり (エラーで止まったときも) と、Ctrl-C で止まった後の次の build-langs / render / check などで使う
  @discardableResult
  /// allowLinkedOut: out/ がシンボリックリンク (別のディスクなど) でも、その中の字幕を戻すか。
  /// 動画を書き出すコマンド (render / build-langs など。もともと out/ のリンクの先に書く) だけ true にし、
  /// データを読むだけのコマンド (brief / overview / timing) では false (データでプロジェクトの外を書き換えないように)
  public static func restoreBuildLangsBackup(_ root: URL, allowLinkedOut: Bool = false) -> Bool {
    restoreBuildLangsBackupImpl(root, allowLinkedOut: allowLinkedOut)
  }

  /// プロセスの印 ("番号 開始時刻")。番号が別のプロセスに使い回されても、開始時刻で見分ける
  static func processMark(_ pid: Int32 = getpid()) -> String? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0, info.kp_proc.p_pid == pid else { return nil }
    let t = info.kp_proc.p_un.__p_starttime
    return "\(pid) \(t.tv_sec).\(t.tv_usec)"
  }

  /// 印 (processMark) のプロセスが、今も動いている同じプロセスか (自分なら false)
  static func markIsAlive(_ mark: String) -> Bool {
    let parts = mark.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ", maxSplits: 1).map(String.init)
    guard let pid = parts.first.flatMap({ Int32($0) }), pid != getpid() else { return false }
    // 形の違う印 (番号だけなど) は、動いているとは扱わない (使い回された番号で、ずっと止まらないように)
    guard parts.count == 2 else { return false }
    return processMark(pid) == mark.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func restoreBuildLangsBackupImpl(_ root: URL, allowLinkedOut: Bool) -> Bool {
    let fm = FileManager.default
    let backup = workDir(root).appendingPathComponent("build-langs-backup")
    guard fm.fileExists(atPath: backup.path), !Safety.isSymlink(backup) else { return false }
    // .jgv/ がシンボリックリンクなら何もしない (控えも戻す先もプロジェクトの外かもしれない)
    guard (try? Safety.requireNoSymlinks(under: root, backup)) != nil else {
      note("WARN: .jgv/ がシンボリックリンクなので、build-langs の控えを戻しません")
      return false
    }
    // 控えを作った build-langs がまだ動いていれば (同時に別の jgv を実行したとき)、戻さない。印はふつうの小さなファイルだけ読む
    let owner = backup.appendingPathComponent("owner")
    if Safety.isRegularFile(owner), ((try? fm.attributesOfItem(atPath: owner.path)[.size] as? Int) ?? 0) < 256,
       let s = try? String(contentsOf: owner, encoding: .utf8), markIsAlive(s) {
      return false
    }
    let targets = [timelineFile(root), root.appendingPathComponent("out/subtitles.srt")]
    // out/ がシンボリックリンクで、そこへ戻せないコマンド (データを読むだけのもの) なら、何も戻さず控えも残す
    // (後で render / build-langs が戻す。timeline だけ戻して字幕が言語版のまま残らないように)
    if !allowLinkedOut, targets.contains(where: { (try? Safety.requireNoSymlinks(under: root, $0)) == nil }) { return false }
    for u in targets {
      let saved = backup.appendingPathComponent(u.lastPathComponent)
      // 戻す先のファイル自体がシンボリックリンクなら、リンクの先を消したり置き換えたりしない
      if Safety.isSymlink(u) { continue }
      // 消すのはふつうのファイルだけ
      if Safety.isRegularFile(u) { try? fm.removeItem(at: u) }
      if fm.fileExists(atPath: saved.path), Safety.isRegularFile(saved), !fm.fileExists(atPath: u.path) { try? fm.moveItem(at: saved, to: u) }
    }
    try? fm.removeItem(at: backup)
    return true
  }

  /// script.json と script.<言語>.json をすべて書き出す (同じ visual で多言語版を作る)
  ///   script.json     → out/video.mp4,      out/subtitles.srt
  ///   script.en.json  → out/video.en.mp4,   out/subtitles.en.srt
  /// usage: jgv build-langs [en zh ...]   (省略時はすべて。script.json だけなら default)
  public static func buildLangs(_ args: [String]) throws {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: fm.currentDirectoryPath)
    try requireProject(root)
    let only = args.filter { !$0.hasPrefix("--") }
    let re = try NSRegularExpression(pattern: "^script(?:\\.([\\w-]+))?\\.json$")
    let files = try fm.contentsOfDirectory(atPath: root.path).filter { re.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }.sorted()
    // 言語版の tts で上書きされる timeline と字幕を、終わったら (途中で止まっても) 基準の台本のものに戻す
    // (jgv check・snapshots・dev が基準の台本のまま使えるように)。基準の台本も書き出したら、そのときのものに差し替える
    let backup = workDir(root).appendingPathComponent("build-langs-backup")
    let restorable = [timelineFile(root), root.appendingPathComponent("out/subtitles.srt")]
    // 控えと戻しは置き換えで行うので、.jgv/ や戻す先がシンボリックリンクだと分かりにくいエラーになる。先に止める
    try Safety.requireNoSymlinks(under: root, backup)
    for u in restorable where Safety.isSymlink(u) { throw ToolError("\(u.path) がシンボリックリンクです (ふつうのファイルにしてから jgv build-langs)") }
    // 前の build-langs が中断 (Ctrl-C) で止まって控えが残っていれば、先に基準の台本のものへ戻す
    if restoreBuildLangsBackup(root, allowLinkedOut: true) { note("前の jgv build-langs が途中で止まっていたので、timeline と字幕を基準の台本のものに戻しました") }
    // 控えが残っているなら、ほかの jgv build-langs が動いている (同時には書き出さない)
    if fm.fileExists(atPath: backup.path) {
      throw ToolError("ほかの jgv build-langs がこのプロジェクトで動いています (終わってからもう一度。動いていないのに出るなら .jgv/build-langs-backup を消す)")
    }
    // 控えは別の名前のフォルダに写し終えてから名前を変える (写している途中で中断しても、半端な控えで戻さないように)
    let backupTmp = workDir(root).appendingPathComponent("build-langs-backup.tmp")
    // 前の残り (シンボリックリンクならリンク自体) を消してから作る (リンクのまま使うと、リンクの先に書いてしまう)
    try? fm.removeItem(at: backupTmp)
    try fm.createDirectory(at: backupTmp, withIntermediateDirectories: true)
    for u in restorable where fm.fileExists(atPath: u.path) {
      try fm.copyItem(at: u, to: backupTmp.appendingPathComponent(u.lastPathComponent))
    }
    // 控えを作ったプロセスの印 (動いている間は、ほかの jgv が控えを戻さない)
    try ((processMark() ?? "\(getpid())") + "\n").write(to: backupTmp.appendingPathComponent("owner"), atomically: true, encoding: .utf8)
    try fm.moveItem(at: backupTmp, to: backup)
    defer { _ = restoreBuildLangsBackup(root, allowLinkedOut: true) }
    var done: [String] = [] // 書き出した言語 (基準の台本は default)
    for f in files {
      let m = re.firstMatch(in: f, range: NSRange(f.startIndex..., in: f))!
      let lang = Range(m.range(at: 1), in: f).map { String(f[$0]) } ?? ""
      if !only.isEmpty && !only.contains(lang.isEmpty ? "default" : lang) { continue }
      // ファイル名の言語 (zh) と台本の lang (zh-CN) の先頭が同じなら言語版とみなす (script.bak.json などは書き出さない)
      if !lang.isEmpty {
        guard let j = try? JSON.read(root.appendingPathComponent(f)) else { FileHandle.standardError.write("SKIP: \(f) (JSON として読めない)\n".data(using: .utf8)!); continue }
        let scriptLang = j["lang"]?.string ?? ""
        if scriptLang.lowercased().split(separator: "-").first.map(String.init) != lang.lowercased().split(separator: "-").first.map(String.init) {
          FileHandle.standardError.write("SKIP: \(f) (lang が \"\(scriptLang)\" で、ファイル名の言語 \(lang) と合わない)\n".data(using: .utf8)!)
          continue
        }
      }
      let suffix = lang.isEmpty ? "" : ".\(lang)"
      note("=== \(f) ===")
      try TTS.run([f, "--keep-audio", "--from-build-langs"])
      // 言語版は読み上げの長さが違うので、キューの時刻が合わなくなることがある。! があれば書き出さずに止める
      if !args.contains("--no-check") {
        let exe = try build(root)
        if try runExe(exe, ["check"], in: root) != 0 {
          throw ToolError("\(f) の jgv check で問題が見つかりました (↑ の ! の行を、どの言語でも通るように直す。キューの終わりの片付けは end-秒 で書き、手の移動の間に余裕を持たせる。確かめずに書き出すなら --no-check)")
        }
      }
      if suffix.isEmpty {
        // 基準の台本の音声を作り直した: 戻す先を、いま作った (script.json と合う) timeline と字幕にする
        // (この後の render で止まっても、古いものに戻さない)
        for u in restorable where fm.fileExists(atPath: u.path) {
          let saved = backup.appendingPathComponent(u.lastPathComponent)
          let tmp = backup.appendingPathComponent(u.lastPathComponent + ".new")
          try? fm.removeItem(at: tmp)
          try fm.copyItem(at: u, to: tmp)
          if fm.fileExists(atPath: saved.path) { _ = try fm.replaceItemAt(saved, withItemAt: tmp) } else { try fm.moveItem(at: tmp, to: saved) }
        }
      }
      try runVideo(["render", "--out=out/video\(suffix).mp4"], fromBuildLangs: true)
      if !suffix.isEmpty {
        let srt = root.appendingPathComponent("out/subtitles\(suffix).srt")
        try? fm.removeItem(at: srt)
        try fm.copyItem(at: root.appendingPathComponent("out/subtitles.srt"), to: srt)
      }
      print("-> out/video\(suffix).mp4")
      done.append(lang.isEmpty ? "default" : lang)
    }
    // 何も書き出さなかった・頼まれた言語を書き出せなかったのに、成功 (終了コード 0) で終わらない
    let missing = only.filter { !done.contains($0) }
    if !missing.isEmpty {
      throw ToolError("書き出せなかった言語があります: \(missing.joined(separator: " ")) (script.<言語>.json があるか、台本の lang がファイル名の言語と合うかを確かめてください。基準の台本は default)")
    }
    if done.isEmpty { throw ToolError("書き出す台本がありません (script.json か script.<言語>.json を用意してください)") }
  }

  // ---------- jgv voices ----------

  /// macOS で使える音声を品質の高い順に一覧表示する (tts.engine: "apple" 用、既定は日本語)
  /// --google / --azure / --amazon なら、そのクラウドの TTS の声の名前 (tts.voice に書く。キーの環境変数が要る)
  public static func voices(_ args: [String]) throws {
    if let e = CloudTTS.engines.first(where: { args.contains("--\($0)") }) {
      let lang = args.first { !$0.hasPrefix("--") } ?? "ja-JP"
      let polly = args.first { $0.hasPrefix("--polly-engine=") }.map { String($0.dropFirst("--polly-engine=".count)) }
      if polly != nil && e != "amazon" { throw ToolError("--polly-engine は --amazon のときだけ使えます") }
      let list = try CloudTTS.voices(e, lang: lang, pollyEngine: polly)
      if list.isEmpty { FileHandle.standardError.write("\(CloudTTS.name(e)) に \(lang) の声がありません\n".data(using: .utf8)!) }
      for v in list { print("\(v.name)\t\(v.info)") }
      return
    }
    let lang = args.first { !$0.hasPrefix("--") } ?? "ja"
    let list = try JSON.parse(AVTTS.run(["--list", lang]))
    let label = ["1": "標準", "2": "拡張(Enhanced)", "3": "プレミアム"]
    for v in list.array ?? [] {
      let q = v["quality"]?.string ?? ""
      print("\(label[q] ?? q)\t\(v["name"]?.string ?? "")\t\(v["identifier"]?.string ?? "")")
    }
  }
}
