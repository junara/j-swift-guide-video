// 動画プロジェクトの実行ファイルの入口。jgv render / snapshots / preview / catalog がキャッシュのパッケージをビルドして、プロジェクトのフォルダで呼ぶ。
//   Video render [--out=out/video.mp4] [--timeline=.jgv/timeline.json]
//   Video snapshots [--scene=N] [--phrases | --seams | --at=秒,秒] [--video=out/video.mp4]
//   Video still --frame=N [--scale=1] [--out=out/still.png]
//   Video preview [名前 …]        … PREVIEW の見本の一覧 (out/preview.png)
//   Video catalog                 … kit の道具の一覧 (out/props-catalog.png)
//   Video check [--json]          … キューの工程の手の時刻表・状態・問題と、文字・注釈・枠の重なりとはみ出し、工程の境目の違いを文字で出す
// ここの引数は jgv が組み立てて渡す内部の形 (= を付けた --out= など)。利用者が打つ jgv render -o / --output とは別で、名前を合わせなくてよい
import CoreGraphics
import Foundation
import JGVCore
import JGVKit

public enum VideoMain {
  public static func run(visuals: [String: VisualFn], previews: [(file: String, items: [PreviewItem])] = []) {
    let args = Array(CommandLine.arguments.dropFirst())
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    func arg(_ name: String) -> String? {
      args.first { $0.hasPrefix("--\(name)=") }.map { String($0.dropFirst(name.count + 3)) }
    }
    // 相対パスはプロジェクトから、絶対パスはそのまま
    func resolve(_ p: String) -> URL { p.hasPrefix("/") ? URL(fileURLWithPath: p) : root.appendingPathComponent(p) }
    do {
      guard let cmd = args.first else { throw AudioMix.err("usage: Video render | snapshots | still | preview | catalog") }
      let timelineURL = resolve(arg("timeline") ?? ".jgv/timeline.json")
      // --scene=N のときはその工程だけを描くので、ほかの工程の visual は登録されていなくてよい
      let onlyScene = cmd == "snapshots" ? arg("scene").flatMap { Int($0) } : nil
      func loadRenderer() throws -> FrameRenderer {
        guard FileManager.default.fileExists(atPath: timelineURL.path) else { throw AudioMix.err("\(timelineURL.path) がありません (先に jgv tts を実行してください)") }
        let tl = try Timeline.load(timelineURL)
        // 台本を直した後に jgv tts をしていなければ、古い台本の動画になる。render は止め、ほかは知らせる
        // 台本はプロジェクトの中のファイルだけ (絶対パスや ../ のものは確かめない)
        if let src = tl.sourceScript, let hash = tl.sourceHash, !src.hasPrefix("/"), !src.split(separator: "/").contains("..") {
          let url = root.appendingPathComponent(src)
          if let now = sha256Hex(of: url), now != hash {
            let m = "\(src) が timeline を作った後に変わっています (jgv tts \(src) で作り直してください)"
            if cmd == "render" { throw AudioMix.err(m) }
            FileHandle.standardError.write(Data("WARN: \(m)\n".utf8))
          }
        }
        for s in tl.scenes where onlyScene == nil || s.index == onlyScene { if let v = s.visual, visuals[v.type] == nil { throw AudioMix.err("visual \"\(v.type)\" が登録されていません (visuals/\(v.type).swift を用意して jgv tts を実行)") } }
        return FrameRenderer(timeline: tl, visuals: visuals)
      }
      switch cmd {
      case "render":
        let r = try loadRenderer()
        let tl = r.timeline
        // timeline が言語版の台本 (script.<言語>.json) のものなのに、既定の出力先 (基準の動画 out/video.mp4) に書こうとしたら止める
        // (jgv check / timing / dev に言語版の台本を渡した後、そのまま jgv render すると、基準の動画が黙って言語版になるのを防ぐ)
        if arg("out") == nil, let src = tl.sourceScript, src != "script.json", src.hasPrefix("script."), src.hasSuffix(".json") {
          let lang = String(src.dropFirst(7).dropLast(5))
          throw AudioMix.err("timeline は \(src) のものです。基準の動画にするなら先に jgv tts、言語版を書き出すなら jgv render -o out/video.\(lang).mp4 (まとめてなら jgv build-langs)")
        }
        let out = resolve(arg("out") ?? "out/video.mp4")
        let audio = try AudioMix.mix(tl, publicDir: root.appendingPathComponent(".jgv"))
        let frames = tl.durationInFrames
        let w = Int(tl.width), h = Int(tl.height)
        let started = Date()
        var lastPrint = Date.distantPast
        // 端末なら同じ行を書き換え、端末でない (ログ・パイプ) なら 10 秒ごとに 1 行ずつ出す (\r でログが 1 行につながらないように)
        let tty = isatty(STDERR_FILENO) != 0
        try VideoWriter.write(to: out, width: w, height: h, fps: tl.fps, frames: frames, audio: audio, progress: { k in
          if Date().timeIntervalSince(lastPrint) > (tty ? 2 : 10) || k == frames {
            lastPrint = Date()
            let text = "render: \(k)/\(frames) フレーム"
            FileHandle.standardError.write(Data((tty ? "\r" + text : text + "\n").utf8))
          }
        }) { cg, k in
          r.draw(into: cg, pixelHeight: h, scale: 1, frame: k)
        }
        if tty { FileHandle.standardError.write(Data("\n".utf8)) }
        print("OK: \(out.path.replacingOccurrences(of: root.path + "/", with: "")) (\(frames) フレーム・\(String(format: "%.1f", tl.durationInSeconds)) 秒の動画。書き出しに \(String(format: "%.1f", Date().timeIntervalSince(started))) 秒)")
      case "snapshots":
        var o = SnapshotOptions()
        o.scene = arg("scene").flatMap { Int($0) }
        if arg("scene") != nil && o.scene == nil { throw AudioMix.err("--scene は数で渡す (例: --scene=2)") }
        o.phrases = args.contains("--phrases")
        o.seams = args.contains("--seams")
        if args.contains("--at") { throw AudioMix.err("--at は = を付けて渡す (例: --scene=3 --at=1.5,2.3)") }
        o.at = arg("at").map { $0.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) ?? .nan } }
        if let v = arg("video") {
          let url = resolve(v)
          guard FileManager.default.fileExists(atPath: url.path) else { throw AudioMix.err("\(v) がありません") }
          o.video = url
        }
        try Snapshots.run(renderer: try loadRenderer(), root: root, options: o)
      case "still":
        let r = try loadRenderer()
        guard let f = arg("frame").flatMap({ Int($0) }) else { throw AudioMix.err("--frame=N を渡す") }
        guard f >= 0, f < r.timeline.durationInFrames else { throw AudioMix.err("--frame=\(f) はありません (フレームは 0〜\(r.timeline.durationInFrames - 1))") }
        let scale = arg("scale").flatMap { Double($0) } ?? 1
        guard scale.isFinite, scale > 0, scale <= 8 else { throw AudioMix.err("--scale は 0 より大きく 8 以下にしてください (\(scale))") }
        let img = r.image(frame: f, scale: scale)
        let out = resolve(arg("out") ?? "out/still.png")
        try Bitmap.writePNG(img, to: out)
        print("OK: \(out.path)")
      case "preview":
        let only = args.dropFirst().filter { !$0.hasPrefix("--") }
        let groups = previews.filter { p in only.isEmpty || only.contains { p.file == $0 || p.file.hasSuffix("/" + $0) } }
        if groups.isEmpty {
          throw AudioMix.err(only.isEmpty
            ? "PREVIEW を定義しているファイルがありません (visuals/props.swift などに `let PROPS_PREVIEW: [PreviewItem] = [...]` を足す)"
            : "\(only.joined(separator: ", ")) に PREVIEW がありません (渡せるのは \(previews.map { $0.file }.joined(separator: ", ")))")
        }
        let tl = FileManager.default.fileExists(atPath: timelineURL.path) ? try? Timeline.load(timelineURL) : nil
        let out = root.appendingPathComponent("out/preview.png")
        try writeCatalog(groups.map { CatalogGroup(title: "\($0.file).swift", items: $0.items) }, to: out, timeline: tl)
        print("OK: out/preview.png (\(groups.map { $0.file }.joined(separator: ", ")))。赤い点 = 原点、橙の点 = parts")
      case "check":
        // キューの工程を、工程の最初のフレームで 1 回ずつ実行し、手の時刻表・計算した状態・問題を文字で出す (--json は JSON で)
        let r = try loadRenderer()
        let json = args.contains("--json")
        CueCheck.active = true
        // timeline が言語版の台本 (script.<言語>.json) から作ったものなら、句の数の違いを注意にとどめる
        let src = r.timeline.sourceScript ?? "script.json"
        CueCheck.languageVariant = src != "script.json" && src.hasPrefix("script.") && src.hasSuffix(".json")
        var problems = 0
        var notes = 0
        var text: [String] = []
        var scenesJSON: [JSON] = []
        func dict(_ d: [String: String]?) -> JSON { .object((d ?? [:]).sorted { $0.key < $1.key }.map { ($0.key, .string($0.value)) }) }
        for s in r.timeline.scenes {
          _ = r.image(frame: Int((s.start * r.timeline.fps).rounded(.up)), scale: 0.05)
          let layout = layoutProblems(r, s)
          let isCue = CueCheck.report[s.index] != nil
          text.append("S\(s.index) \(s.visual?.type ?? "-")" + (isCue ? "" : " (swift)"))
          var ps: [JSON] = [], ns: [JSON] = [], table: [JSON] = []
          for l in layout.map({ "  ! \($0)" }) + (CueCheck.report[s.index] ?? []) {
            text.append(l)
            if l.hasPrefix("  ! ") { problems += 1; ps.append(.string(String(l.dropFirst(4)))) }
            else if l.hasPrefix("  ? ") { notes += 1; ns.append(.string(String(l.dropFirst(4)))) }
            else if !l.hasPrefix("  start: ") && !l.hasPrefix("  end:   ") { table.append(.string(String(l.dropFirst(2)))) }
          }
          scenesJSON.append(.object([("index", .number(Double(s.index))), ("visual", s.visual.map { .string($0.type) } ?? .null), ("kind", isCue ? "cue" : "swift"),
                                     ("problems", .array(ps)), ("notes", .array(ns)), ("table", .array(table)),
                                     ("start", dict(CueCheck.start[s.index])), ("end", dict(CueCheck.end[s.index]))]))
        }
        // 工程の境目: 前の工程の終わりと次の工程の始まりで、値が違うもの
        var seamsJSON: [JSON] = []
        for (a, b) in zip(r.timeline.scenes, r.timeline.scenes.dropFirst()) {
          guard let e = CueCheck.end[a.index], let st = CueCheck.start[b.index] else { continue }
          let diff = Set(e.keys).intersection(st.keys).sorted().filter { e[$0] != st[$0] }
          let only = Set(e.keys).symmetricDifference(st.keys).sorted()
          text.append("S\(a.index)→S\(b.index) " + (diff.isEmpty && only.isEmpty ? "ok" : (diff.map { "\($0) \(e[$0]!)→\(st[$0]!)" } + only.map { "\($0) は片方だけ" }).joined(separator: " / ")))
          var ps: [JSON] = []
          let out = CueCheck.cardOut[a.index] ?? false, inn = CueCheck.cardIn[b.index] ?? false
          if out != inn {
            problems += 1
            let m = "拡大カードのつなぎが合わない: " + (out ? "S\(a.index) は card.exit=0 だが S\(b.index) に card と card.enter=0 が無い" : "S\(b.index) は card.enter=0 だが S\(a.index) に card.exit=0 が無い (shrink もしない)")
            text.append("  ! " + m)
            ps.append(.string(m))
          }
          seamsJSON.append(.object([("from", .number(Double(a.index))), ("to", .number(Double(b.index))),
                                    ("diffs", .array(diff.map { .object([("key", .string($0)), ("end", .string(e[$0]!)), ("start", .string(st[$0]!))]) })),
                                    ("onlyOne", .array(only.map { .string($0) })), ("problems", .array(ps))]))
        }
        if json {
          print(JSON.object([("ok", .bool(problems == 0)), ("problems", .number(Double(problems))), ("notes", .number(Double(notes))),
                             ("scenes", .array(scenesJSON)), ("seams", .array(seamsJSON))]).description)
        } else {
          for l in text { print(l) }
          let noteText = notes > 0 ? " (注意 \(notes) 件: ? の行。見せ方を確かめる)" : ""
          print((problems == 0 ? "OK: 問題なし" : "問題 \(problems) 件 (! の行)") + noteText)
        }
        if problems > 0 { exit(1) }
      case "catalog":
        let out = resolve(arg("out") ?? "out/props-catalog.png")
        try writeCatalog([CatalogGroup(items: KIT_CATALOG)], to: out, timeline: nil)
        print("OK: \(out.path.replacingOccurrences(of: root.path + "/", with: ""))")
      default:
        throw AudioMix.err("未対応のコマンド: \(cmd)")
      }
    } catch {
      FileHandle.standardError.write("ERROR: \(describe(error))\n".data(using: .utf8)!)
      exit(1)
    }
  }

  /// エラーの文 (Swift の struct のエラー (JSON.ParseError など) は localizedDescription が "JGVCore.JSON.ParseError error 1" になるので、message を出す)
  static func describe(_ error: Error) -> String {
    if let e = error as? JSON.ParseError { return e.message }
    if type(of: error) is NSError.Type || error is LocalizedError { return error.localizedDescription }
    return "\(error)"
  }

  /// 工程を 0.25 秒おきに描いて、文字・注釈・枠 (字幕バー・見出しなど) の重なり、注釈が拡大カードに隠れること、
  /// 注釈・枠が画面からはみ出すことを集める。同じ問題は時刻の範囲 (工程の始まりからの秒) にまとめる
  static func layoutProblems(_ r: FrameRenderer, _ s: Scene) -> [String] {
    let tl = r.timeline
    let a = Int((s.start * tl.fps).rounded(.up))
    let b = max(a, Int((s.end * tl.fps).rounded(.down)) - 1)
    var found: [String: (t0: Double, t1: Double, text: String)] = [:]
    var order: [String] = []
    LayoutProbe.active = true
    defer { LayoutProbe.active = false }
    for f in stride(from: a, through: b, by: max(1, Int(tl.fps / 4))) {
      LayoutProbe.items = []
      LayoutProbe.alpha = 1
      _ = r.image(frame: f, scale: 0.1)
      let t = Double(f) / tl.fps - s.start
      for p in LayoutProbe.problems(width: tl.width, height: tl.height) {
        if found[p.key] != nil { found[p.key]!.t1 = t } else { found[p.key] = (t, t, p.text); order.append(p.key) }
      }
    }
    func sec(_ x: Double) -> String { String(format: "%.2f", x) }
    return order.map { k in
      let x = found[k]!
      return "\(sec(x.t0))\(x.t1 > x.t0 ? "-\(sec(x.t1))" : "")s: \(x.text)"
    }
  }

  /// 道具の一覧を 1 枚の画像にする (30 フレーム目の状態)
  public static func writeCatalog(_ groups: [CatalogGroup], to url: URL, timeline: Timeline?) throws {
    let size = catalogSizeOf(groups)
    var info = GuideInfo()
    if let tl = timeline {
      info.palette = DEFAULT_PALETTE.merged(tl.palette)
      info.font = tl.style.fontFamily ?? fontForLang(tl.lang ?? "ja-JP")
      info.lang = tl.lang ?? "ja-JP"
    }
    let img = renderStill(width: size.width, height: size.height, frame: 30, background: "#fbf8f1") {
      provide(info) { CatalogGrid(groups: groups) }
    }
    try Bitmap.writePNG(img, to: url)
  }
}
