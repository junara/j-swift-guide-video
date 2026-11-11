// 動画プロジェクトのビルドと実行 (render / snapshots / preview / catalog)。
// プロジェクトには題材ごとのファイル (visuals/・parts/・assets/・台本) だけを置き、ビルド用の Swift パッケージは
// キャッシュに jgv が作る。skill の kit を使うプロジェクトはすべて 1 つのパッケージ
// (~/Library/Caches/j-guide-video/shared-<kit のパスのハッシュ>/pkg) を共有し、ビルドのたびにリンクをそのプロジェクトへ向け直す。
// kit のビルドは全プロジェクトで 1 回で済み、できた実行ファイルはプロジェクトのキャッシュ (projects/<ハッシュ>/bin) に写して実行する。
// kit/ を持つプロジェクト (jgv vendor-kit) だけは、自分のパッケージ (projects/<ハッシュ>/pkg) を使う。
// パッケージの中身はシンボリックリンク:
//   Kit/JGVCore など            → skill の Sources/JGVCore など (プロジェクトに kit/ があればそちら。jgv vendor-kit)
//   Sources/Video/visuals       → プロジェクトの visuals/ (parts も同じ)
//   Sources/Scene<N>/visuals/*  → 工程 N の visual と補助ファイルだけ (jgv snapshots --scene=N 用)
// 工程ごとのターゲットも同じパッケージ・同じビルドフォルダにあるので、kit のビルドは 1 回で済む。
// パッケージをそろえてからビルドし終えるまでロックを取るので、並列の工程担当や別のプロジェクトの jgv は順番に進む
import CryptoKit
import Foundation
import JGVCore

extension Project {
  /// キャッシュの置き場 ($J_GUIDE_VIDEO_CACHE。jgv の CLI のビルドと同じ)
  static func cacheBase() -> URL {
    let env = ProcessInfo.processInfo.environment["J_GUIDE_VIDEO_CACHE"].flatMap { $0.isEmpty ? nil : $0 }
    return env.map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches/j-guide-video")
  }

  static func hashKey(_ path: String) -> String {
    String(SHA256.hash(data: Data(path.utf8)).hex.prefix(12))
  }

  /// プロジェクトごとのキャッシュのフォルダ (projects/<ハッシュ>。実行ファイルの写しと、kit/ を持つプロジェクトのパッケージ)
  public static func cacheDir(_ root: URL) -> URL {
    cacheBase().appendingPathComponent("projects/\(hashKey(root.standardizedFileURL.path))")
  }

  /// skill の kit を使うか (プロジェクトに kit/ が無い)。使うならビルドのパッケージを全プロジェクトで共有する
  static func usesSharedPackage(_ root: URL) -> Bool {
    kitDir(root).standardizedFileURL == skillDir.appendingPathComponent("Sources").standardizedFileURL
  }

  /// 全プロジェクトで共有するビルドのフォルダ (skill の置き場ごとに 1 つ)
  static func sharedDir() -> URL {
    cacheBase().appendingPathComponent("shared-\(hashKey(skillDir.appendingPathComponent("Sources").standardizedFileURL.path))")
  }

  /// パッケージ (pkg)・ビルド (build)・ロックを置くフォルダ
  static func buildDir(_ root: URL) -> URL { usesSharedPackage(root) ? sharedDir() : cacheDir(root) }

  /// 描画の kit のソース (プロジェクトの kit/ があればそちら、無ければ skill の Sources/)
  public static func kitDir(_ root: URL) -> URL {
    let vendored = root.appendingPathComponent("kit")
    return FileManager.default.fileExists(atPath: vendored.appendingPathComponent("JGVCore").path) ? vendored : skillDir.appendingPathComponent("Sources")
  }

  static let mainSwift = """
    // jgv が作る動画プロジェクトの実行ファイルの入口 (編集しない)
    import JGVKit
    import JGVRender

    VideoMain.run(visuals: customVisuals, previews: previews)

    """

  // ---------- ファイルの書き出し (変わったときだけ。ビルドをやり直さないように) ----------

  /// 生成する Swift の 1 行のコメントに入れる文字列 (フォルダ名の改行などの制御文字でコメントの外に出ないように ? にする)
  static func commentSafe(_ s: String) -> String {
    String(String.UnicodeScalarView(s.unicodeScalars.map { $0.properties.generalCategory == .control || $0 == "\u{2028}" || $0 == "\u{2029}" ? "?" : $0 }))
  }

  static func writeIfChanged(_ text: String, _ url: URL) throws {
    if (try? String(contentsOf: url, encoding: .utf8)) == text { return }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: url, atomically: true, encoding: .utf8)
  }

  /// at を to へのシンボリックリンクにする (to が nil なら消す)。at は jgv のパッケージの中のリンクなので、
  /// リンクでない実体 (ファイル・フォルダ) は、jgv のキャッシュの中のものだけ消す (キャッシュの外を指す名前で利用者のファイルを消さないように)
  static func link(_ at: URL, to: URL?) throws {
    let fm = FileManager.default
    let current = try? fm.destinationOfSymbolicLink(atPath: at.path)
    if current == to?.path { return }
    if current != nil { try? fm.removeItem(at: at) }
    else if fm.fileExists(atPath: at.path) {
      // jgv のキャッシュの中の古い実体 (前の版のパッケージなど) だけは消して作り直す
      let base = cacheBase().standardizedFileURL.resolvingSymlinksInPath().path + "/"
      if at.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath().appendingPathComponent(at.lastPathComponent).path.hasPrefix(base) {
        try fm.removeItem(at: at)
      } else {
        throw ToolError("\(at.path) がシンボリックリンクではありません (jgv のビルドのフォルダの中のはず。jgv clean で作り直してください)")
      }
    }
    guard let to else { return }
    try fm.createDirectory(at: at.deletingLastPathComponent(), withIntermediateDirectories: true)
    try fm.createSymbolicLink(at: at, withDestinationURL: to)
  }

  /// dir の中を、名前 → リンク先 の通りにそろえる (余分なものは消す)
  static func syncLinks(_ dir: URL, _ wanted: [String: URL]) throws {
    let fm = FileManager.default
    // dir がリンクだと、下の「余分なものを消す」がリンクの先 (skill やプロジェクトのフォルダ) のファイルを消してしまうので、リンクを外して作り直す
    if Safety.isSymlink(dir) { try fm.removeItem(at: dir) }
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    for f in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] where wanted[f] == nil { try? fm.removeItem(at: dir.appendingPathComponent(f)) }
    for (name, to) in wanted {
      // 名前は dir の直下のファイル名だけ (/ や .. で dir の外を指させない)
      guard !name.contains("/"), name != "..", name != "." else { throw ToolError("リンクの名前「\(name)」は使えません") }
      try link(dir.appendingPathComponent(name), to: to)
    }
  }

  /// 並列に動く jgv がパッケージを同時に書き換えないように、dir のロックを取って body を実行する
  static func withLock<T>(_ dir: URL, _ body: () throws -> T) throws -> T {
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let fd = open(dir.appendingPathComponent("lock").path, O_CREAT | O_RDWR, 0o644)
    guard fd >= 0 else { return try body() }
    defer { close(fd) }
    flock(fd, LOCK_EX)
    defer { flock(fd, LOCK_UN) }
    return try body()
  }

  // ---------- パッケージ ----------

  /// キャッシュのパッケージをプロジェクトの今の状態にそろえ、そのフォルダを返す。
  /// 工程ごとのターゲット (Scene<N>) は timeline の工程の数だけ作る
  @discardableResult
  public static func syncPackage(_ root: URL) throws -> URL {
    try requireProject(root)
    return try withLock(buildDir(root)) { try syncPackageLocked(root) }
  }

  /// syncPackage の中身 (buildDir のロックを取ってから呼ぶ)
  static func syncPackageLocked(_ root: URL) throws -> URL {
    let fm = FileManager.default
    let cache = cacheDir(root)
    let pkg = buildDir(root).appendingPathComponent("pkg")
    try writeIfChanged(root.standardizedFileURL.path + "\n", cache.appendingPathComponent("project-path"))
    let kit = kitDir(root)
    try syncLinks(pkg.appendingPathComponent("Kit"), Dictionary(uniqueKeysWithValues: kitModules.map { ($0, kit.appendingPathComponent($0)) }))

    let visuals = visualsDir(root)
    try fm.createDirectory(at: visuals, withIntermediateDirectories: true)
    let parts = partsDir(root)
    let hasParts = fm.fileExists(atPath: parts.path)

    // すべての工程を描くターゲット
    let video = pkg.appendingPathComponent("Sources/Video")
    try writeIfChanged(mainSwift, video.appendingPathComponent("main.swift"))
    // 共有のパッケージは別のプロジェクトとビルドを取り違えないように、登録表にプロジェクトのパスを入れる (切り替えると必ずコンパイルし直す)
    let stamp = "// project: \(commentSafe(root.standardizedFileURL.path))\n"
    try writeIfChanged(stamp + Registry.text(root), video.appendingPathComponent("generated/Visuals.swift"))
    try link(video.appendingPathComponent("visuals"), to: visuals)
    try link(video.appendingPathComponent("parts"), to: hasParts ? parts : nil)

    // 工程ごとのターゲット: その工程の visual と補助ファイル (小文字で始まるファイル)・parts だけ
    // timeline がまだ無ければ工程のターゲットは作らない。あるのに読めない・値が正しくないときは、黙って工程を消さずに理由を出す
    var scenes: [Scene] = []
    if fm.fileExists(atPath: timelineFile(root).path) {
      do { scenes = try Timeline.load(timelineFile(root)).scenes } catch { throw ToolError("\(timelineFileName) を読めません: \(userMessage(error))") }
    }
    let swiftFiles = { (d: URL) in ((try? fm.contentsOfDirectory(atPath: d.path)) ?? []).filter { $0.hasSuffix(".swift") } }
    let helpers = swiftFiles(visuals).filter { $0.first?.isLowercase == true }
    let partFiles = hasParts ? swiftFiles(parts) : []
    for s in scenes {
      let dir = pkg.appendingPathComponent("Sources/Scene\(s.index)")
      // visual 名は Timeline.load で確かめてある (念のためここでも形を確かめてからパスにする)
      let name = s.visual.map(\.type).flatMap { Safety.isVisualName($0) ? $0 : nil }
      var vs = Dictionary(uniqueKeysWithValues: helpers.map { ($0, visuals.appendingPathComponent($0)) })
      if let name, fm.fileExists(atPath: visuals.appendingPathComponent("\(name).swift").path) { vs["\(name).swift"] = visuals.appendingPathComponent("\(name).swift") }
      try writeIfChanged(mainSwift, dir.appendingPathComponent("main.swift"))
      try writeIfChanged(stamp + Registry.sceneText(root, scene: s.index, visual: name), dir.appendingPathComponent("generated/Visuals.swift"))
      try syncLinks(dir.appendingPathComponent("visuals"), vs)
      try syncLinks(dir.appendingPathComponent("parts"), Dictionary(uniqueKeysWithValues: partFiles.map { ($0, parts.appendingPathComponent($0)) }))
    }
    // 工程が減ったときの古いターゲット
    for d in (try? fm.contentsOfDirectory(atPath: pkg.appendingPathComponent("Sources").path)) ?? [] where d.hasPrefix("Scene") {
      if let i = Int(d.dropFirst(5)), i >= scenes.count { try? fm.removeItem(at: pkg.appendingPathComponent("Sources/\(d)")) }
    }

    let deps = "[\"JGVCore\", \"JGVKit\", \"JGVRender\"]"
    var targets = [
      "    .target(name: \"JGVCore\", path: \"Kit/JGVCore\"),",
      "    .target(name: \"JGVKit\", dependencies: [\"JGVCore\"], path: \"Kit/JGVKit\"),",
      "    .target(name: \"JGVRender\", dependencies: [\"JGVCore\", \"JGVKit\"], path: \"Kit/JGVRender\"),",
      "    .executableTarget(name: \"Video\", dependencies: \(deps), path: \"Sources/Video\"),",
    ]
    targets += scenes.map { "    .executableTarget(name: \"Scene\($0.index)\", dependencies: \(deps), path: \"Sources/Scene\($0.index)\")," }
    let manifest = """
      // swift-tools-version: 6.0
      // jgv が \(commentSafe(root.standardizedFileURL.path)) のために作るパッケージ (編集しない。jgv を実行するたびに作り直す)
      import PackageDescription

      let package = Package(
        name: "Video",
        platforms: [.macOS(.v14)],
        targets: [
      \(targets.joined(separator: "\n"))
        ],
        swiftLanguageModes: [.v5]
      )

      """
    try writeIfChanged(manifest, pkg.appendingPathComponent("Package.swift"))
    return pkg
  }

  // ---------- ビルドと実行 ----------

  /// プロジェクトをビルドして実行ファイルのパスを返す (変更が無ければすぐ終わる)。
  /// scene を渡すと、その工程の visual と補助ファイルだけのターゲットをビルドする
  /// (工程ごとの担当が並列に作業しても、ほかの工程の書きかけのファイルで止まらないように)
  public static func build(_ root: URL, scene: Int? = nil) throws -> String {
    try requireProject(root)
    let product: String
    if let scene {
      guard FileManager.default.fileExists(atPath: timelineFile(root).path) else { throw ToolError("\(timelineFileName) がありません (先に jgv tts を実行してください)") }
      // 読めない・値が正しくない timeline は、その理由を出す (「ありません」と誤って伝えない)
      let n: Int
      do { n = try Timeline.load(timelineFile(root)).scenes.count } catch { throw ToolError("\(timelineFileName) を読めません: \(userMessage(error))") }
      guard scene >= 0, scene < n else { throw ToolError("--scene=\(scene) はありません (工程は 0〜\(max(0, n - 1)))") }
      product = "Scene\(scene)"
    } else {
      product = "Video"
    }
    let dir = buildDir(root)
    let shared = usesSharedPackage(root)
    return try withLock(dir) {
      let pkg = try syncPackageLocked(root)
      let scratch = dir.appendingPathComponent("build")
      let kit = shared ? kitFingerprint() : ""
      let (status, data) = try swiftBuild(pkg: pkg, scratch: scratch, ["--product", product])
      if status != 0 {
        // エラーの行 (ファイル:行:列: error: …) だけを、プロジェクトからのパス (visuals/Open.swift など) にして出す
        let text = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
        let errs = text.split(separator: "\n").filter { $0.hasPrefix("/") && $0.contains(": error:") }.map { line -> String in
          var s = String(line)
          for prefix in [pkg.path, pkg.resolvingSymlinksInPath().path] {
            s = s.replacingOccurrences(of: prefix + "/Sources/Video/", with: "")
            s = s.replacingOccurrences(of: "^" + NSRegularExpression.escapedPattern(for: prefix) + "/Sources/Scene[0-9]+/", with: "", options: .regularExpression)
          }
          return s.replacingOccurrences(of: root.path + "/", with: "")
        }
        var seen = Set<String>()
        let uniq = errs.filter { seen.insert($0).inserted }
        FileHandle.standardError.write((uniq.isEmpty ? text : uniq.joined(separator: "\n") + "\n").data(using: .utf8)!)
        throw ToolError("ビルドに失敗しました (↑ のエラーの visual を直してから、もう一度実行してください)")
      }
      let built = scratch.appendingPathComponent("release/\(product)")
      guard shared else { return built.path }
      markKitBuilt(kit)
      // 共有のパッケージは次のビルドで別のプロジェクトに向くので、実行ファイルはプロジェクトのキャッシュに写して使う
      // (写してから名前を変えるので、同じプロジェクトで実行中の前の実行ファイルは影響を受けない)
      let fm = FileManager.default
      let bin = cacheDir(root).appendingPathComponent("bin/\(product)")
      // 写した元 (どの共有のビルドの、いつの実行ファイルか) を控えて、同じなら写し直さない。
      // 日時の前後だけで比べると、別の skill (clone した版と plugin の版など) でビルドした実行ファイルをそのまま使ってしまう
      let a = try? fm.attributesOfItem(atPath: built.path)
      let from = "\(built.path) \((a?[.size] as? NSNumber)?.int64Value ?? 0) \((a?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)\n"
      let fromFile = bin.deletingLastPathComponent().appendingPathComponent(".\(product).from")
      if fm.fileExists(atPath: bin.path), (try? String(contentsOf: fromFile, encoding: .utf8)) == from { return bin.path }
      removeOldProjectBuild(root)
      let tmp = bin.deletingLastPathComponent().appendingPathComponent(".\(product).\(getpid())")
      try fm.createDirectory(at: bin.deletingLastPathComponent(), withIntermediateDirectories: true)
      try? fm.removeItem(at: tmp)
      try fm.copyItem(at: built, to: tmp)
      if rename(tmp.path, bin.path) != 0 { throw ToolError("\(bin.path) を作れません") }
      try? from.write(to: fromFile, atomically: true, encoding: .utf8)
      return bin.path
    }
  }

  /// swift build を実行して、終了コードと出力 (標準出力と標準エラー) を返す
  static func swiftBuild(pkg: URL, scratch: URL, _ args: [String]) throws -> (Int32, Data) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = ["swift", "build", "-c", "release"] + args + ["--package-path", pkg.path, "--scratch-path", scratch.path]
    p.currentDirectoryURL = pkg
    p.standardInput = FileHandle.nullDevice
    let out = Pipe()
    p.standardOutput = out
    p.standardError = out
    try Children.run(p)
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    Children.finished(p)
    return (p.terminationStatus, data)
  }

  /// プロジェクトの実行ファイルを、出力をそのまま流して実行する (snapshots --scene=N はその工程だけでビルドする)
  public static func runVideo(_ args: [String], fromBuildLangs: Bool = false) throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    // build-langs が Ctrl-C で止まると、timeline が言語版のまま残る。そのまま描くと別の言語の動画になるので、先に戻す
    if !fromBuildLangs && restoreBuildLangsBackup(root, allowLinkedOut: true) {
      note("前の jgv build-langs が途中で止まっていたので、timeline と字幕を基準の台本のものに戻しました")
    }
    let scene = args.first == "snapshots" ? args.first { $0.hasPrefix("--scene=") }.flatMap { Int($0.dropFirst(8)) } : nil
    let exe = try build(root, scene: scene)
    if try runExe(exe, args, in: root) != 0 { throw ToolError.silent }
  }

  /// 実行ファイルを root で、出力をそのまま流して実行し、終了コードを返す
  static func runExe(_ exe: String, _ args: [String], in root: URL) throws -> Int32 {
    fflush(stdout) // ここまでに print したものを、子プロセスの出力より先に出す
    let p = Process()
    p.executableURL = URL(fileURLWithPath: exe)
    p.arguments = args
    p.currentDirectoryURL = root
    // 子は端末の前面のグループではないので、標準入力を読むと止まったままになる。読ませない
    p.standardInput = FileHandle.nullDevice
    try Children.run(p)
    p.waitUntilExit()
    Children.finished(p)
    // 落ちた (シグナルで終わった) ときは、何も出さずに終わらないよう理由を出す
    if p.terminationReason == .uncaughtSignal {
      note("ERROR: \(URL(fileURLWithPath: exe).lastPathComponent) \(args.first ?? "") が異常終了しました (シグナル \(p.terminationStatus))。台本・timeline に極端な値が無いか確かめてください")
      return 128 + p.terminationStatus
    }
    return p.terminationStatus
  }

  // ---------- kit の先回りのビルド ----------
  // skill を入れた直後や更新した直後は、最初のビルドで kit のコンパイルに数十秒かかる。
  // jgv init・jgv tts のときに kit が古ければ、裏で kit だけをビルドしておく (Claude がキューを書いている間に終わる)

  /// kit をビルドした印 (1 行目に skill のパス、2 行目にビルドしたときの kit の指紋)
  static func kitStamp() -> URL { sharedDir().appendingPathComponent("kit-built") }

  /// skill の kit のソースの指紋 (ファイルの名前・大きさ・更新日時。消したファイルも、古い日時で写したファイルも変化として拾う)
  static func kitFingerprint() -> String {
    let fm = FileManager.default
    let src = skillDir.appendingPathComponent("Sources")
    var lines: [String] = []
    for m in kitModules {
      guard let e = fm.enumerator(at: src.appendingPathComponent(m), includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { continue }
      for case let f as URL in e {
        let v = try? f.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        lines.append("\(f.path) \(v?.fileSize ?? 0) \(v?.contentModificationDate?.timeIntervalSince1970 ?? 0)")
      }
    }
    return hashKey(lines.sorted().joined(separator: "\n"))
  }

  /// fingerprint はビルドを始める前に取った指紋 (ビルドの途中で kit を直したら、次も古いとみなす)
  static func markKitBuilt(_ fingerprint: String) {
    try? writeIfChanged(skillDir.path + "\n" + fingerprint + "\n", kitStamp())
  }

  /// 共有のビルドの kit が、skill の kit のソースと違うか
  static func kitIsStale() -> Bool {
    let stamp = (try? String(contentsOf: kitStamp(), encoding: .utf8))?.split(separator: "\n")
    return stamp?.count != 2 || String(stamp![1]) != kitFingerprint()
  }

  /// kit が古ければ、jgv prebuild を裏で起動する (待たずに戻る。終わる前にほかの jgv がビルドしても、ロックで順番に進む)
  public static func prebuildInBackground(_ root: URL) {
    guard usesSharedPackage(root), kitIsStale(), let exe = Bundle.main.executablePath else { return }
    try? FileManager.default.createDirectory(at: sharedDir(), withIntermediateDirectories: true)
    // 共有のビルドのロックを誰かが持っていれば、kit はそのビルドで作られるので起動しない (prebuild を重ねて起動しない)
    let fd = open(sharedDir().appendingPathComponent("lock").path, O_CREAT | O_RDWR, 0o644)
    if fd >= 0 {
      defer { close(fd) }
      if flock(fd, LOCK_EX | LOCK_NB) != 0 { return }
      flock(fd, LOCK_UN)
    }
    let log = sharedDir().appendingPathComponent("prebuild.log")
    var attr = posix_spawnattr_t(nil as OpaquePointer?)
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    // 新しいセッションで起動して、呼んだ側 (シェル) が終わっても止まらないようにする
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSID))
    var actions = posix_spawn_file_actions_t(nil as OpaquePointer?)
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
    posix_spawn_file_actions_addopen(&actions, 1, log.path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
    posix_spawn_file_actions_adddup2(&actions, 1, 2)
    let argv = [exe, "prebuild", root.standardizedFileURL.path]
    let cargs = argv.map { strdup($0) } + [nil]
    defer { cargs.forEach { free($0) } }
    var pid: pid_t = 0
    if posix_spawn(&pid, exe, &actions, &attr, cargs, environ) == 0 {
      note("kit を裏でビルドしています (ログ: \(log.path))")
    }
  }

  /// jgv prebuild <project>: 共有のパッケージで kit (JGVCore・JGVKit・JGVRender) だけをビルドする
  public static func prebuild(_ args: [String]) throws {
    let root = URL(fileURLWithPath: args.first { !$0.hasPrefix("--") } ?? FileManager.default.currentDirectoryPath).standardizedFileURL
    try requireProject(root)
    guard usesSharedPackage(root) else { return }
    try withLock(sharedDir()) {
      guard kitIsStale() else { print("kit は最新です"); return }
      let pkg = try syncPackageLocked(root)
      let started = Date()
      let kit = kitFingerprint()
      let (status, data) = try swiftBuild(pkg: pkg, scratch: sharedDir().appendingPathComponent("build"), ["--target", "JGVRender"])
      FileHandle.standardOutput.write(data)
      if status != 0 { throw ToolError("kit のビルドに失敗しました") }
      markKitBuilt(kit)
      print("OK: kit をビルドしました (\(String(format: "%.1f", Date().timeIntervalSince(started))) 秒)")
    }
  }

  /// 共有のパッケージを使う前に作った、プロジェクトごとのパッケージとビルド (1 つ 150 MB ほど) を消す
  static func removeOldProjectBuild(_ root: URL) {
    for d in ["pkg", "build"] { try? FileManager.default.removeItem(at: cacheDir(root).appendingPathComponent(d)) }
  }

  /// jgv open: キャッシュのパッケージを Xcode で開く (visuals/ などはリンクなので、Xcode で直すとプロジェクトのファイルが変わる)。
  /// 共有のパッケージは、別のプロジェクトで jgv を実行するとそちらに向き直る
  public static func openPackage(_ args: [String]) throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let pkg = try syncPackage(root)
    print("パッケージ: \(pkg.path)")
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = ["-a", "Xcode", pkg.path]
    try Children.run(p)
    p.waitUntilExit()
    Children.finished(p)
    if p.terminationStatus != 0 { throw ToolError("Xcode で開けませんでした (Xcode が無いときは、上のパッケージをほかのエディタで開く)") }
  }

  /// 今動いている jgv の CLI のビルドのフォルダ名 (build-<ハッシュ>)。
  /// bin/jgv が渡す J_GUIDE_VIDEO_SKILL の生の文字列のハッシュ (URL を通すと日本語などのパスが NFD になり、bash の shasum と合わない) と、
  /// 実行ファイルのパスにある build-* の両方を見る (どちらかが合わなくても、自分のビルドを消さないように)
  static func currentCLIBuilds() -> Set<String> {
    var names = Set<String>()
    if let s = ProcessInfo.processInfo.environment["J_GUIDE_VIDEO_SKILL"], !s.isEmpty {
      names.insert("build-" + Insecure.SHA1.hash(data: Data(s.utf8)).hex.prefix(12))
    }
    // 実行ファイルは <キャッシュ>/build-<ハッシュ>/release/jgv (release は SwiftPM のビルドの成果物へのリンクで、指す先は版によって違う)。
    // build-<ハッシュ> より下に build- で始まるフォルダは無いので、最後の build-* が自分のビルド
    if let exe = Bundle.main.executablePath {
      let url = URL(fileURLWithPath: exe)
      for parts in [url.pathComponents, url.resolvingSymlinksInPath().pathComponents] {
        if let i = parts.lastIndex(where: { $0.hasPrefix("build-") }) { names.insert(parts[i]) }
      }
    }
    return names
  }

  /// jgv clean: このプロジェクトのビルドのキャッシュを消す。--stale は、プロジェクトのフォルダが無くなったキャッシュ、
  /// 共有のパッケージを使う前のプロジェクトごとのビルド、置き場の無くなった skill の共有のビルドと CLI のビルドをすべて消す
  public static func clean(_ args: [String]) throws {
    let fm = FileManager.default
    let dryRun = args.contains("--dry-run")
    let verb = dryRun ? "消す予定" : "削除"
    var removed = 0
    /// 消す (--dry-run のときは消さずに、消すものを出すだけ)
    func remove(_ label: String, _ body: () throws -> Void) rethrows {
      if !dryRun { try body() }
      removed += 1
      print("\(verb): \(label)")
    }
    if args.contains("--stale") {
      // jgv が作った印のあるものだけを消す ($J_GUIDE_VIDEO_CACHE を専用でないフォルダに向けていても、ほかの物は消さない)
      func isHash(_ s: Substring) -> Bool { s.count == 12 && s.allSatisfy { $0.isHexDigit && !$0.isUppercase } }
      // 印の無いもの (jgv が作ったのではないかもしれない) は消さない。一覧は --dry-run のときだけ出し、ふだんは件数だけ
      var kept = 0
      func keep(_ dir: URL, _ why: String) { kept += 1; if dryRun { print("残す: \(dir.path) (\(why))") } }
      let base = cacheDir(URL(fileURLWithPath: "/")).deletingLastPathComponent()
      for d in (try? fm.contentsOfDirectory(atPath: base.path)) ?? [] where !d.hasPrefix(".") {
        let dir = base.appendingPathComponent(d)
        let path = (try? String(contentsOf: dir.appendingPathComponent("project-path"), encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isHash(Substring(d)), let path, !path.isEmpty else { keep(dir, "jgv のキャッシュの印 project-path が無い"); continue }
        if fm.fileExists(atPath: URL(fileURLWithPath: path).appendingPathComponent("jgv.json").path) {
          let root = URL(fileURLWithPath: path)
          if usesSharedPackage(root) && fm.fileExists(atPath: dir.appendingPathComponent("build").path) {
            remove("\(dir.path)/pkg・build (\(path)。今は共有のビルドを使う)") { removeOldProjectBuild(root) }
          }
          continue
        }
        try remove("\(dir.path) (\(path))") { try fm.removeItem(at: dir) }
      }
      for d in (try? fm.contentsOfDirectory(atPath: cacheBase().path)) ?? [] where d.hasPrefix("shared-") && isHash(d.dropFirst(7)) {
        let dir = cacheBase().appendingPathComponent(d)
        // 印がまだ無い (最初のビルドの途中かもしれない) ものと、skill がまだある ものは残す
        guard let skill = (try? String(contentsOf: dir.appendingPathComponent("kit-built"), encoding: .utf8))?.split(separator: "\n").first.map(String.init),
              !fm.fileExists(atPath: URL(fileURLWithPath: skill).appendingPathComponent("Sources/JGVKit").path) else { continue }
        try remove("\(dir.path) (\(skill))") { try fm.removeItem(at: dir) }
      }
      // CLI (jgv) のビルド (build-<skill のパスの SHA-1 の先頭 12 桁>。bin/jgv が作る)。今の skill の分と、
      // 置き場がまだある skill の分は残す。印 (skill-path) が無いものは前の版の bin/jgv が作ったもので、
      // 使っていても次の起動でビルドし直すだけなので消す (ビルドに失敗して実行ファイルが無いものも)。ただし前の版の bin/jgv が
      // ビルドのたびに書き直す <キャッシュ>/build.log が 30 分以内に更新されていれば、ビルドの途中かもしれないので残す
      // (swift build の出力があるたびに更新されるので、30 分も出力の無いビルドは途中とみなさない)
      // (今の bin/jgv はログを build-*/build.log に書くので、今の jgv のビルドの直後でも消せる)
      let cache = cacheBase()
      let current = currentCLIBuilds()
      let logDate = (try? fm.attributesOfItem(atPath: cache.appendingPathComponent("build.log").path))?[.modificationDate] as? Date
      let recentBuild = logDate.map { Date().timeIntervalSince($0) < 1800 } ?? false
      for d in (try? fm.contentsOfDirectory(atPath: cache.path)) ?? [] where d.hasPrefix("build-") && isHash(d.dropFirst(6)) && !current.contains(d) {
        let dir = cache.appendingPathComponent(d)
        let skill = (try? String(contentsOf: dir.appendingPathComponent("skill-path"), encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let skill, fm.fileExists(atPath: URL(fileURLWithPath: skill).appendingPathComponent("Sources/JGVKit").path) { continue }
        // 印 (skill-path) が無いものは、SwiftPM のビルドのフォルダ (CACHEDIR.TAG / workspace-state.json がある) のときだけ消す
        if skill == nil && !["CACHEDIR.TAG", "workspace-state.json"].contains(where: { fm.fileExists(atPath: dir.appendingPathComponent($0).path) }) {
          keep(dir, "jgv のビルドの印が無い")
          continue
        }
        if skill == nil && recentBuild {
          print("残す: \(dir.path) (jgv のビルド。前の版の jgv がビルドしている途中かもしれないので、30 分ほどしてからもう一度)")
          continue
        }
        try remove("\(dir.path) (jgv のビルド。\(skill ?? "どの skill のものか不明"))") { try fm.removeItem(at: dir) }
      }
      // 前の版の bin/jgv のログ (今の bin/jgv は書かない)。ビルドの途中かもしれない間は残す
      if logDate != nil && !recentBuild {
        try remove("\(cache.path)/build.log (前の版の jgv のビルドのログ)") { try fm.removeItem(at: cache.appendingPathComponent("build.log")) }
      }
      if kept > 0 && !dryRun { note("jgv の印が無いもの \(kept) 件は残しました (一覧は --dry-run)") }
      note(dryRun ? "OK: \(removed) 件のキャッシュを消します (--dry-run なので消していません)" : "OK: \(removed) 件のキャッシュを消しました")
      return
    }
    let root = URL(fileURLWithPath: fm.currentDirectoryPath)
    try requireProject(root)
    let dir = cacheDir(root)
    // ビルドの物だけ消す。クラウドの TTS を使うと認めた印 (allow-cloud-*) と project-path は残す (消すと次の jgv tts でまた聞かれる)。
    // ロックのファイルも残し、ロックを取ってから消す (同時に動いているビルドの途中で消さないように)
    let keep: (String) -> Bool = { $0.hasPrefix("allow-cloud-") || $0 == "project-path" || $0 == "lock" }
    func removeBuild(in d: URL, _ names: [String]) throws {
      guard fm.fileExists(atPath: d.path) else { return }
      try withLock(d) {
        for f in names { try remove(d.appendingPathComponent(f).path) { try fm.removeItem(at: d.appendingPathComponent(f)) } }
      }
    }
    try removeBuild(in: dir, ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { !keep($0) }.sorted())
    // skill の kit を使うプロジェクトは、パッケージとビルドが全プロジェクトで共有のフォルダにある。そこも消さないと、壊れたビルドを作り直せない
    // (kit のコンパイルからやり直すので、次のビルドは数十秒〜数分かかる)
    if usesSharedPackage(root) {
      let shared = sharedDir()
      let names = ["pkg", "build", "kit-built", "prebuild.log"].filter { fm.fileExists(atPath: shared.appendingPathComponent($0).path) || Safety.isSymlink(shared.appendingPathComponent($0)) }
      try removeBuild(in: shared, names)
    }
    note(dryRun ? "OK: --dry-run なので消していません" : "OK: 次のビルドで作り直します\(usesSharedPackage(root) ? " (全プロジェクトで共有の kit のビルドも消したので、次のビルドは数十秒〜数分かかります)" : "")")
  }
}
