// jgv dev: 直した後の確認を 1 回の実行でまとめて行う。
//   1. jgv tts (変わった行だけ読み上げ直し、timeline・字幕・登録表を作り直す)
//   2. ビルド (変更が無ければすぐ終わる)
//   3. check (問題があればここで止まる)
//   4. 前回の jgv dev から変わった工程だけ snapshots (Swift・assets・全体の設定が変わったときはすべての工程)
// 工程が変わったかは、その工程の timeline (工程と行)・キュー (init <前の工程 で引き継ぐキューも) の中身で決める。
// Swift のファイル (visuals/・parts/) と kit はビルドした実行ファイルの中身で、assets/ はファイルの一覧で見る。
// 前回の状態は .jgv/dev-state.json に置く
import CryptoKit
import Foundation
import JGVCore

extension Project {
  public static func dev(_ args: [String]) throws {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: fm.currentDirectoryPath)
    try requireProject(root)
    let all = args.contains("--all")
    if let bad = args.first(where: { $0.hasPrefix("--") && $0 != "--all" && $0 != "--keep-audio" }) {
      throw ToolError("\(bad) は使えません (使えるのは --all・--keep-audio と台本のファイル名)")
    }

    note("=== tts")
    try TTS.run(args.filter { $0 != "--all" })
    note("=== build")
    let exe = try build(root)
    note("=== check")
    let status = try runExe(exe, ["check"], in: root)
    // 128 以上はシグナルで落ちた (runExe が理由を出している)
    if status >= 128 { throw ToolError("check が途中で落ちました (↑ の ERROR を見てください)") }
    if status != 0 {
      throw ToolError("check で問題が見つかりました (↑ の ! の行を直してから、もう一度 jgv dev)")
    }

    let stateURL = workDir(root).appendingPathComponent("dev-state.json")
    let now = try DevState.compute(root, exe: exe)
    let prev = DevState.load(stateURL)
    let sheet = root.appendingPathComponent("out/snapshots/sheet.png")
    let changed = prev.map { p in p.scenes.count == now.scenes.count ? now.scenes.indices.filter { now.scenes[$0] != p.scenes[$0] } : Array(now.scenes.indices) } ?? Array(now.scenes.indices)
    // jgv snapshots --phrases などで一覧を描き直されたら、前回の状態は当てにしない。
    // すべての工程が変わったときは、工程ごとに撮るより 1 回で全体を撮るほうが速く、全体の一覧も新しくなる
    let full = all || prev == nil || prev!.global != now.global || prev!.sheetMTime != DevState.mtime(sheet) || (!changed.isEmpty && changed.count == now.scenes.count)
    var next = now
    if full {
      note("=== snapshots (すべての工程)")
      if try runExe(exe, ["snapshots"], in: root) != 0 { throw ToolError.silent }
      next.sheetMTime = DevState.mtime(sheet)
      next.images = ["out/snapshots/sheet.png"]
      try next.save(stateURL)
      print("確認する画像: out/snapshots/sheet.png")
      return
    }
    next.sheetMTime = prev!.sheetMTime
    if changed.isEmpty {
      next.images = prev!.images
      note("=== snapshots: 前回の jgv dev から変わった工程はありません (前回の画像: \(prev!.images.joined(separator: " "))。撮り直すなら jgv dev --all)")
      try next.save(stateURL)
      return
    }
    for i in changed {
      note("=== snapshots (工程 \(i))")
      if try runExe(exe, ["snapshots", "--scene=\(i)"], in: root) != 0 { throw ToolError.silent }
    }
    next.images = changed.map { "out/snapshots/scene-\($0)/sheet.png" }
    try next.save(stateURL)
    print("確認する画像: " + next.images.joined(separator: " "))
    note("(変わった工程だけを撮り直しました。全体の out/snapshots/sheet.png は前のままです)")
  }
}

struct DevState: Codable, Equatable {
  /// 全工程にかかわるもの (実行ファイル・assets・timeline の工程と行より外) のハッシュ
  var global: String
  /// 工程ごとのハッシュ (timeline の工程と行・キュー)
  var scenes: [String]
  /// 全体の一覧 (out/snapshots/sheet.png) の更新日時
  var sheetMTime: Double?
  /// 前回の jgv dev が確認するよう出した画像
  var images: [String] = []

  static func load(_ url: URL) -> DevState? {
    (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(DevState.self, from: $0) }
  }

  func save(_ url: URL) throws {
    try JSONEncoder().encode(self).write(to: url, options: .atomic)
  }

  static func mtime(_ url: URL) -> Double? {
    ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date)?.timeIntervalSince1970
  }

  static func hash(_ parts: [Data]) -> String {
    var h = SHA256()
    for p in parts { h.update(data: withUnsafeBytes(of: p.count) { Data($0) }); h.update(data: p) }
    return h.finalize().hex
  }

  static func json(_ v: Any) -> Data {
    (try? JSONSerialization.data(withJSONObject: v, options: [.sortedKeys, .fragmentsAllowed])) ?? Data()
  }

  static func compute(_ root: URL, exe: String) throws -> DevState {
    let fm = FileManager.default
    guard let tl = try JSONSerialization.jsonObject(with: Data(contentsOf: Project.timelineFile(root))) as? [String: Any] else {
      throw ToolError("\(Project.timelineFileName) を読めません")
    }
    let scenes = tl["scenes"] as? [[String: Any]] ?? []
    let lines = tl["lines"] as? [[String: Any]] ?? []
    var rest = tl
    rest["scenes"] = nil
    rest["lines"] = nil
    // 台本のファイルのハッシュは、どの工程を直しても変わる。全体の指紋に入れると毎回すべての工程を撮り直すので外す
    // (工程ごとの中身は scenes / lines の側で比べる)
    rest["source"] = nil
    let assets = Project.assetsDir(root)
    let assetList = ((try? fm.contentsOfDirectory(atPath: assets.path)) ?? []).sorted().map { f -> String in
      let a = try? fm.attributesOfItem(atPath: assets.appendingPathComponent(f).path)
      return "\(f) \(a?[.size] ?? 0) \((a?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)"
    }
    let global = hash([try Data(contentsOf: URL(fileURLWithPath: exe)), json(rest), Data(assetList.joined(separator: "\n").utf8)])

    // 工程の visual が CueScene("名前", …) に渡すキューの名前 (雛形では visual と同じ名前。Swift の visual なら無い)
    func cueName(_ visual: String) -> String? {
      guard let src = try? String(contentsOf: Project.visualsDir(root).appendingPathComponent("\(visual).swift"), encoding: .utf8),
            let r = src.range(of: "CueScene\\(\\s*\"[^\"]+\"", options: .regularExpression) else { return nil }
      return src[r].split(separator: "\"")[1].description
    }
    func cueText(_ name: String) -> String {
      (try? String(contentsOf: root.appendingPathComponent("cues/\(name).cue"), encoding: .utf8)) ?? ""
    }
    // init <前の工程 で引き継ぐキューをたどる (前の工程のキューを直すと、引き継いだ工程の始まりも変わる)
    func cueChain(_ name: String) -> [Data] {
      var out: [Data] = []
      var seen = Set<String>()
      var cur: String? = name
      while let n = cur, seen.insert(n).inserted {
        let text = cueText(n)
        out.append(Data(text.utf8))
        cur = text.split(separator: "\n").lazy.compactMap { line -> String? in
          let t = line.trimmingCharacters(in: .whitespaces)
          guard t.hasPrefix("init "), let r = t.range(of: "<[A-Za-z0-9_]+", options: .regularExpression) else { return nil }
          return String(t[r].dropFirst())
        }.first
      }
      return out
    }
    let sceneHashes = scenes.enumerated().map { i, s -> String in
      let mine = lines.filter { ($0["sceneIndex"] as? Int) == i }
      let visual = (s["visual"] as? [String: Any])?["type"] as? String
      return hash([json(s), json(mine)] + (visual.flatMap(cueName).map(cueChain) ?? []))
    }
    return DevState(global: global, scenes: sceneHashes)
  }
}
