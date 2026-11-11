// 動画ごとの概要ページ (out/overview.html) を作る。工程ごとのナレーション・visual のファイル・静止画の一覧と、
// SVG の素材 (レイヤー・持つ所つき) を 1 ページに並べて、ブラウザで見渡せるようにする (表示だけ。ほかのファイルは変えない)。
// 静止画は jgv snapshots (--scene=N) で作ったものがあれば載せる。
//
// usage: jgv overview [<project dir>]   (省略時はカレント) → <project dir>/out/overview.html
import Foundation
import JGVCore

public enum OverviewTool {
  static func esc(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
  }

  static func time(_ t: Double) -> String { String(format: "%d:%04.1f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60)) }

  public static func run(_ args: [String]) throws {
    let fm = FileManager.default
    let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
    let root = URL(fileURLWithPath: args.first { !$0.hasPrefix("--") } ?? ".", relativeTo: cwd).standardizedFileURL
    try Project.requireProject(root)
    let out = root.appendingPathComponent("out")
    // out/ がシンボリックリンクなら書かない (データを読むだけのコマンドで、プロジェクトの外にファイルを作らないように)
    try Safety.requireNoSymlinks(under: root, out)
    try fm.createDirectory(at: out, withIntermediateDirectories: true)
    func exists(_ rel: String) -> Bool { fm.fileExists(atPath: root.appendingPathComponent(rel).path) }
    // シンボリックリンクの先 (プロジェクトの外かもしれない) は読まない
    func read(_ u: URL) -> String { Safety.isPlainFile(u, under: root) ? ((try? String(contentsOf: u, encoding: .utf8)) ?? "") : "" }

    if Project.restoreBuildLangsBackup(root) { note("前の jgv build-langs が途中で止まっていたので、timeline と字幕を基準の台本のものに戻しました") }
    // timeline と台本はプロジェクトのふつうのファイルだけ読む (リンクの先の中身を overview に載せないように)
    let tl = Safety.isPlainFile(Project.timelineFile(root), under: root) ? try? Timeline.load(Project.timelineFile(root)) : nil
    let script = Safety.isPlainFile(root.appendingPathComponent("script.json"), under: root) ? try? JSON.read(root.appendingPathComponent("script.json")) : nil
    let title = tl?.title ?? script?["title"]?.string ?? root.lastPathComponent

    // SVG の素材と、それを使う visual
    let assetsDir = Project.assetsDir(root)
    let svgs = ((try? fm.contentsOfDirectory(atPath: assetsDir.path)) ?? []).filter { $0.hasSuffix(".svg") }.sorted()
    let visualsDir = Project.visualsDir(root)
    let visualFiles = ((try? fm.contentsOfDirectory(atPath: visualsDir.path)) ?? []).filter { $0.hasSuffix(".swift") }.sorted()
    let svgRe = try NSRegularExpression(pattern: "(?:Svg|svgParts|svgDocument)\\(\\s*\"([^\"]+)\"")
    func svgsUsed(in src: String) -> [String] {
      var seen = Set<String>()
      return svgRe.matches(in: src, range: NSRange(src.startIndex..., in: src)).compactMap { Range($0.range(at: 1), in: src).map { String(src[$0]) } }
        .map { $0.hasSuffix(".svg") ? String($0.dropLast(4)) : $0 }.filter { seen.insert($0).inserted }
    }

    var body: [String] = []
    body.append("<header><h1>\(esc(title))</h1>")
    var meta: [String] = []
    if let tl { meta += [tl.layout, "\(Int(tl.width))×\(Int(tl.height))", "\(time(tl.durationInSeconds))", "工程 \(tl.scenes.count)"] }
    meta.append(root.path)
    body.append("<p class=\"meta\">\(meta.map(esc).joined(separator: " · "))</p></header>")
    if tl == nil { body.append("<p class=\"note\">.jgv/timeline.json がありません。jgv tts の後で jgv overview を実行し直すと、工程ごとの時刻と静止画が載ります。</p>") }

    // 動画
    // 基準の台本の video.mp4 を先に (名前の順だと video.en.mp4 が先になる)
    let videos = ((try? fm.contentsOfDirectory(atPath: out.path)) ?? []).filter { $0.hasPrefix("video") && $0.hasSuffix(".mp4") }
      .sorted { ($0 == "video.mp4" ? 0 : 1, $0) < ($1 == "video.mp4" ? 0 : 1, $1) }
    if !videos.isEmpty {
      body.append("<section><h2>動画</h2>")
      body.append("<video controls preload=\"metadata\" src=\"\(esc(videos[0]))\"></video>")
      if videos.count > 1 { body.append("<p>" + videos.map { "<a href=\"\(esc($0))\">\(esc($0))</a>" }.joined(separator: " · ") + "</p>") }
      body.append("</section>")
    }

    // 工程
    body.append("<section><h2>工程</h2>")
    let scenes: [(index: Int, heading: String, visual: String, start: Double?, end: Double?, lines: [(String, Double?)])]
    if let tl {
      scenes = tl.scenes.map { s in (s.index, s.heading, s.visual?.type ?? "", s.start, s.end, tl.lines.filter { $0.sceneIndex == s.index }.map { ($0.text, $0.start) }) }
    } else {
      scenes = (script?["scenes"]?.array ?? []).enumerated().map { i, sc in
        // 分けて取り出す (古い Swift で型を決めるのに時間がかからないように)
        let heading: String = sc["heading"]?.string ?? ""
        let visual: String = sc["visual"]?.string ?? sc["visual"]?["type"]?.string ?? ""
        let lines: [JSON] = sc["lines"]?.array ?? []
        let texts: [(String, Double?)] = lines.map { (l: JSON) -> (String, Double?) in (l.string ?? l["text"]?.string ?? "", nil) }
        return (i, heading, visual, nil, nil, texts)
      }
    }
    for s in scenes {
      body.append("<article class=\"scene\" id=\"scene-\(s.index)\">")
      var head = "<h3><span class=\"badge\">STEP \(String(format: "%02d", s.index + 1))</span> \(esc(s.heading))"
      if let a = s.start, let b = s.end { head += " <span class=\"time\">\(time(a))〜\(time(b))</span>" }
      body.append(head + "</h3>")
      var info: [String] = ["--scene=\(s.index)"]
      if !s.visual.isEmpty {
        let file = "\(s.visual).swift"
        let cue = "cues/\(s.visual).cue"
        if exists(cue) { info.append("<a href=\"../\(esc(cue))\">\(esc(cue))</a>") } else {
          info.append(visualFiles.contains(file) ? "<a href=\"../visuals/\(esc(file))\">visuals/\(esc(file))</a>" : "<span class=\"warn\">visuals/\(esc(file)) がありません</span>")
        }
        let used = svgsUsed(in: read(visualsDir.appendingPathComponent(file)))
        if !used.isEmpty { info.append("SVG: " + used.map { "<a href=\"#asset-\(esc($0))\">\(esc($0))</a>" }.joined(separator: ", ")) }
      }
      body.append("<p class=\"info\">\(info.joined(separator: " · "))</p>")
      body.append("<ol class=\"lines\" start=\"0\">" + s.lines.map { t, at in "<li>\(at.map { "<span class=\"time\">\(time($0))</span> " } ?? "")\(esc(t))</li>" }.joined() + "</ol>")
      let sheet = "out/snapshots/scene-\(s.index)/sheet.png"
      if exists(sheet) { body.append("<a href=\"snapshots/scene-\(s.index)/sheet.png\"><img class=\"sheet\" loading=\"lazy\" src=\"snapshots/scene-\(s.index)/sheet.png\" alt=\"工程 \(s.index) の静止画\"></a>") }
      body.append("</article>")
    }
    if exists("out/snapshots/sheet.png") {
      body.append("<h3>すべての行の静止画（jgv snapshots）</h3><a href=\"snapshots/sheet.png\"><img class=\"sheet\" loading=\"lazy\" src=\"snapshots/sheet.png\" alt=\"静止画の一覧\"></a>")
    }
    body.append("</section>")

    // SVG の素材
    if !svgs.isEmpty {
      body.append("<section><h2>SVG の素材（assets）</h2><p class=\"note\">赤い点 = 原点、橙の点 = 持つ所 (part-…)。</p><div class=\"assets\">")
      for f in svgs {
        let name = String(f.dropLast(4))
        body.append("<figure id=\"asset-\(esc(name))\">")
        if Safety.isPlainFile(assetsDir.appendingPathComponent(f), under: root), let doc = try? SVGDocument.load(assetsDir.appendingPathComponent(f)) {
          let vb = doc.viewBox
          let r = max(vb.width, vb.height) * 0.012
          var marks = "<circle cx=\"\(doc.origin.x)\" cy=\"\(doc.origin.y)\" r=\"\(r)\" fill=\"#d9534f\"/>"
          for (_, p) in doc.parts { marks += "<circle cx=\"\(doc.origin.x + p.x)\" cy=\"\(doc.origin.y + p.y)\" r=\"\(r)\" fill=\"#f0a020\"/>" }
          body.append("<div class=\"art\"><img src=\"../assets/\(esc(f))\" alt=\"\(esc(name))\"><svg viewBox=\"\(vb.minX) \(vb.minY) \(vb.width) \(vb.height)\">\(marks)</svg></div>")
          var cap = ["<b><a href=\"../assets/\(esc(f))\">\(esc(name))</a></b> \(String(format: "%.0f", vb.width))×\(String(format: "%.0f", vb.height))"]
          if !doc.layerNames.isEmpty { cap.append("layers: " + doc.layerNames.map(esc).joined(separator: ", ")) }
          if !doc.parts.isEmpty { cap.append("parts: " + doc.parts.map { esc($0.0) }.joined(separator: ", ")) }
          if !doc.colorNames.isEmpty { cap.append("配色の色: " + doc.colorNames.map { "--" + esc($0) }.joined(separator: ", ")) }
          if !doc.warnings.isEmpty { cap.append("<span class=\"warn\">描けないもの: \(doc.warnings.map(esc).joined(separator: " / "))</span>") }
          let users = visualFiles.filter { svgsUsed(in: read(visualsDir.appendingPathComponent($0))).contains(name) }
          if !users.isEmpty { cap.append("使う visual: " + users.map { "<a href=\"../visuals/\(esc($0))\">\(esc($0))</a>" }.joined(separator: ", ")) }
          body.append("<figcaption>\(cap.joined(separator: "<br>"))</figcaption>")
        } else {
          body.append("<figcaption><b>\(esc(name))</b><br><span class=\"warn\">SVG として読めません</span></figcaption>")
        }
        body.append("</figure>")
      }
      body.append("</div></section>")
    }

    // Swift の補助ファイルと部品
    let helpers = visualFiles.filter { $0.first?.isLowercase == true }
    let partFiles = ((try? fm.contentsOfDirectory(atPath: Project.partsDir(root).path)) ?? []).filter { $0.hasSuffix(".swift") }.sorted()
    if !helpers.isEmpty || !partFiles.isEmpty || exists("out/preview.png") {
      body.append("<section><h2>Swift の部品</h2><ul>")
      for f in helpers { body.append("<li><a href=\"../visuals/\(esc(f))\">visuals/\(esc(f))</a>（この動画の補助ファイル）</li>") }
      for f in partFiles { body.append("<li><a href=\"../parts/\(esc(f))\">parts/\(esc(f))</a>（ライブラリの部品）</li>") }
      body.append("</ul>")
      if exists("out/preview.png") { body.append("<a href=\"preview.png\"><img class=\"sheet\" loading=\"lazy\" src=\"preview.png\" alt=\"jgv preview\"></a>") }
      body.append("</section>")
    }

    let html = """
      <!doctype html>
      <html lang="ja">
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\(esc(title))</title>
      <style>
      :root { --bg: #fbf8f1; --fg: #2b2622; --muted: #6f655b; --line: #e3d9c8; --card: #ffffff; --accent: #c8553d; --warn: #b3261e; }
      @media (prefers-color-scheme: dark) { :root { --bg: #1d1b19; --fg: #ece6dc; --muted: #a89f93; --line: #3a3530; --card: #262320; --accent: #e58a6f; --warn: #ff8a80; } }
      * { box-sizing: border-box; }
      body { margin: 0; padding: 24px 16px 64px; background: var(--bg); color: var(--fg); font: 15px/1.6 -apple-system, "Hiragino Sans", sans-serif; }
      main { max-width: 1100px; margin: 0 auto; }
      h1 { margin: 0 0 4px; font-size: 26px; } h2 { margin: 40px 0 12px; font-size: 20px; border-bottom: 1px solid var(--line); padding-bottom: 6px; }
      h3 { margin: 0 0 6px; font-size: 17px; } a { color: var(--accent); }
      .meta, .note, .info { color: var(--muted); margin: 4px 0; } .warn { color: var(--warn); }
      .badge { display: inline-block; background: var(--accent); color: #fff; border-radius: 4px; padding: 0 6px; font-size: 13px; margin-right: 4px; }
      .time { color: var(--muted); font-variant-numeric: tabular-nums; font-size: 13px; }
      .scene { background: var(--card); border: 1px solid var(--line); border-radius: 8px; padding: 16px; margin: 12px 0; }
      .lines { margin: 8px 0; padding-left: 28px; } .lines li::marker { color: var(--muted); }
      video, .sheet { width: 100%; height: auto; border-radius: 6px; border: 1px solid var(--line); display: block; margin-top: 8px; }
      .assets { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 16px; }
      figure { margin: 0; background: var(--card); border: 1px solid var(--line); border-radius: 8px; padding: 12px; }
      .art { position: relative; background: #fbf8f1; border-radius: 4px; max-width: 280px; margin: 0 auto; } .art img, .art svg { display: block; width: 100%; height: auto; }
      .art svg { position: absolute; inset: 0; height: 100%; } figcaption { font-size: 13px; margin-top: 8px; overflow-wrap: anywhere; }
      </style>
      </head>
      <body><main>
      \(body.joined(separator: "\n"))
      </main></body>
      </html>

      """
    let file = out.appendingPathComponent("overview.html")
    try html.write(to: file, atomically: true, encoding: .utf8)
    // standardizedFileURL は /private/tmp を /tmp にするので、比べる前に両方のリンクをたどってそろえる
    let fileReal = file.resolvingSymlinksInPath().path, cwdReal = cwd.resolvingSymlinksInPath().path
    let rel = fileReal.hasPrefix(cwdReal + "/") ? String(fileReal.dropFirst(cwdReal.count + 1)) : file.path
    print("OK: \(rel) (ブラウザで開く: open \(rel))")
  }
}
