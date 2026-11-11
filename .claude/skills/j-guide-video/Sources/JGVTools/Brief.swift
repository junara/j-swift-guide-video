// 工程担当のサブエージェントが最初に読む「この動画に必要なことだけ」の資料 (out/brief.md) を作る。
// reference/implementation.md と reference/visual-kit.md から型 (layout) に合う節だけを抜き出し、
// プロジェクトの visuals/shared.swift・props.swift と、ユーザーのライブラリの部品 (parts/) は
// 宣言の名前とシグネチャだけにまとめる (parts はこの動画で使うファイルだけ。ほかは名前の一覧)。assets/*.svg はレイヤーと持つ所の一覧にする。
// 各担当が全文を読むより文脈が小さくなり、その後のすべてのターンが軽くなる。
//
// usage: jgv brief [<project dir>]   (省略時はカレント) → <project dir>/out/brief.md
import Foundation
import JGVCore

public enum BriefTool {
  struct Section {
    var level: Int
    var title: String
    var body: String
  }

  /// Markdown を見出しで節に分ける (body は見出し行を含む)
  static func sectionsOf(_ md: String) -> [Section] {
    var out: [(Int, String, [String])] = []
    var fence = false
    for line in md.components(separatedBy: "\n") {
      if line.range(of: "^\\s*(```|~~~)", options: .regularExpression) != nil { fence.toggle() }
      if !fence, let r = line.range(of: "^#{1,6}\\s+", options: .regularExpression) {
        let level = line.prefix { $0 == "#" }.count
        out.append((level, String(line[r.upperBound...]), [line]))
      } else if !out.isEmpty {
        out[out.count - 1].2.append(line)
      }
    }
    return out.map { Section(level: $0.0, title: $0.1, body: $0.2.joined(separator: "\n").replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)) }
  }

  /// title が prefix で始まる節を返す。withChildren なら下位の見出しの節も含める
  static func pick(_ secs: [Section], _ prefix: String, _ withChildren: Bool = true) throws -> String {
    guard let i = secs.firstIndex(where: { $0.title.hasPrefix(prefix) }) else {
      throw ToolError("節「\(prefix)」が見つかりません (implementation.md / visual-kit.md の見出しを変えたら Sources/JGVTools/Brief.swift も直す)")
    }
    var parts = [secs[i].body]
    if withChildren {
      var j = i + 1
      while j < secs.count && secs[j].level > secs[i].level { parts.append(secs[j].body); j += 1 }
    }
    return parts.joined(separator: "\n\n")
  }

  /// Swift のファイルの、トップレベルの宣言 (private 以外) ごとに直前のコメントとシグネチャ (関数は本体を省く。短い定数・struct・enum はそのまま)
  /// root を渡すと、そのプロジェクトのふつうのファイルだけを読む (シンボリックリンクの先は読まない)。kit のファイルは root なしで呼ぶ
  static func apiOf(_ url: URL, root: URL? = nil) -> String {
    guard root.map({ Safety.isPlainFile(url, under: $0) }) ?? true, let src = try? String(contentsOf: url, encoding: .utf8) else { return "" }
    let lines = src.components(separatedBy: "\n")
    var out: [String] = []
    let declRe = "^(public |internal )?(func|let|var|struct|enum|typealias|final class|class)\\s"
    var i = 0
    while i < lines.count {
      let line = lines[i]
      guard line.range(of: declRe, options: .regularExpression) != nil else { i += 1; continue }
      // 道具の見本 (jgv preview 用) は visual から使わないので載せない
      if line.range(of: "^(public )?let [A-Z0-9_]+_PREVIEW\\b", options: .regularExpression) != nil { i += 1; continue }
      var doc: [String] = []
      var j = i - 1
      while j >= 0, lines[j].range(of: "^\\s*(//|/\\*|\\*)", options: .regularExpression) != nil { doc.insert(lines[j], at: 0); j -= 1 }
      var sig = line
      var next = i + 1
      if line.range(of: "^(public |internal )?(struct|enum|final class|class)\\s", options: .regularExpression) != nil {
        // 型は引数を知るのに要るので、40 行までなら全文 (メソッドの本体は省かない)
        if let end = (i + 1 ..< lines.count).first(where: { lines[$0].hasPrefix("}") }), end - i <= 40 {
          sig = lines[i ... end].joined(separator: "\n")
          next = end + 1
        } else {
          sig = line.replacingOccurrences(of: "\\{\\s*$", with: "{ … }", options: .regularExpression)
        }
      } else if line.range(of: "^(public |internal )?func\\s", options: .regularExpression) != nil {
        // 引数が複数行に折り返されていれば、本体の始まりの行 ({ で終わる行) まで読む (最大 20 行)
        var end = i
        while end < lines.count - 1 && !lines[end].hasSuffix("{") && end - i < 20 { end += 1 }
        sig = lines[i ... end].joined(separator: "\n").replacingOccurrences(of: "\\{\\s*$", with: "{ … }", options: .regularExpression)
        // 1 行に本体まで書いた短い関数 ({ … } が同じ行で閉じる) はそのまま
        if line.hasSuffix("}") { sig = line }
        next = end + 1
      } else if line.hasSuffix("(") || line.hasSuffix("[") || line.hasSuffix("([") || line.hasSuffix("{") {
        // 複数行の定数 (パーツ座標など) は 12 行までならそのまま
        if let end = (i + 1 ..< lines.count).first(where: { lines[$0].range(of: "^[\\]\\)\\}]", options: .regularExpression) != nil }), end - i <= 12 {
          sig = lines[i ... end].joined(separator: "\n")
          next = end + 1
        } else {
          sig = line + " …"
        }
      } else if sig.count > 400 {
        sig = String(sig.prefix(400)) + " …"
      }
      out.append((doc + [sig]).joined(separator: "\n"))
      i = next
    }
    return out.joined(separator: "\n\n")
  }

  /// ファイルで宣言している名前 (private 以外のトップレベルの func / let / var / struct / enum)
  static func declaredNames(_ url: URL, root: URL? = nil) -> [String] {
    guard root.map({ Safety.isPlainFile(url, under: $0) }) ?? true, let src = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    let re = try! NSRegularExpression(pattern: "(?m)^(?:public |internal )?(?:func|let|var|struct|enum|typealias|final class|class)\\s+([A-Za-z_][A-Za-z0-9_]*)")
    return re.matches(in: src, range: NSRange(src.startIndex..., in: src)).compactMap { m in
      Range(m.range(at: 1), in: src).map { String(src[$0]) }
    }.filter { !$0.hasSuffix("_PREVIEW") }
  }

  static func mentions(_ text: String, _ name: String) -> Bool {
    text.range(of: "(?<![A-Za-z0-9_])\(NSRegularExpression.escapedPattern(for: name))(?![A-Za-z0-9_])", options: .regularExpression) != nil
  }

  public static func run(_ args: [String]) throws {
    let fm = FileManager.default
    let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
    let project = URL(fileURLWithPath: args.first { !$0.hasPrefix("--") } ?? ".", relativeTo: cwd).standardizedFileURL
    try Project.requireProject(project)
    // 台本はプロジェクトのふつうのファイルだけ読む (リンクの先の文書の中身を brief に載せないように)
    guard Safety.isPlainFile(project.appendingPathComponent("script.json"), under: project) else {
      throw ToolError("script.json がシンボリックリンクか、ふつうのファイルではありません")
    }
    let script = try JSON.read(project.appendingPathComponent("script.json"))
    let kitSrc = Project.kitDir(project)
    let layout = script["layout"]?.string ?? "guide"
    let vertical = (script["height"]?.double ?? 1080) > (script["width"]?.double ?? 1920)
    let ref = Project.skillDir.appendingPathComponent("reference")
    let kit = sectionsOf(try String(contentsOf: ref.appendingPathComponent("visual-kit.md"), encoding: .utf8))
    let rules = sectionsOf(try String(contentsOf: ref.appendingPathComponent("implementation.md"), encoding: .utf8))

    // implementation.md「型ごとの要点」から、この型 (と縦型・説明文・終わりの状態へ向かう動き・多言語) の項目だけ
    let POINT = ["guide": "部屋", "guide-screen": "画面操作", "guide-topdown": "手元俯瞰", "guide-manual": "組み立て説明書"]
    let points = try pick(rules, "型ごとの要点", false).components(separatedBy: "\n").filter { l in
      guard let r = l.range(of: "^- \\*\\*(.+?)\\*\\*", options: .regularExpression) else { return false }
      let m = String(l[r]).dropFirst(4).dropLast(2)
      return m == (POINT[layout] ?? "") || (vertical && m == "縦型") || m == "説明文" || m.hasPrefix("終わりの状態へ向かう動き") || m.hasPrefix("多言語")
    }

    var parts = [
      "# この動画の visual を書くための資料（\(POINT[layout] ?? layout)\(vertical ? "・縦型" : "")）",
      "implementation.md と visual-kit.md から、この型に必要な節だけを抜き出したもの。ここに無い API が要るときだけ kit のソース (\(kitSrc.appendingPathComponent("JGVKit").path)) を読む。",
      "## この型の要点（implementation.md）",
      points.joined(separator: "\n"),
    ]
    if layout == "guide" { parts.append(try pick(rules, "共通の必須ルール")) }
    if layout == "guide" || layout == "guide-topdown" { parts.append(try pick(rules, "道具が足りないとき")) }
    for t in ["カスタム visual の雛形", "useNarration()", "部品", "動きのパターン集", "よくあるシーンの型"] { parts.append(try pick(kit, t)) }
    parts.append(layout == "guide" ? try pick(kit, "ガイドレイアウト") : try pick(kit, "配置 (`GUIDE`)"))
    let TYPE_SECTION = ["guide-screen": "画面操作型", "guide-topdown": "手元俯瞰型", "guide-manual": "組み立て説明書型"]
    parts.append(try pick(kit, "ガイドの型（layout）と縦型", false))
    if let t = TYPE_SECTION[layout] { parts.append(try pick(kit, t)) }
    parts.append(try pick(kit, "画面上の文言の多言語化"))

    // プロジェクトの共通部品
    let visualsDir = Project.visualsDir(project)
    let shared = ["shared.swift", "props.swift"].filter { fm.fileExists(atPath: visualsDir.appendingPathComponent($0).path) }
    if !shared.isEmpty {
      parts.append("## この動画の共通部品（visuals）")
      parts.append("名前とシグネチャだけ。中身が要るときだけファイルを読む。同じモジュールなので import せずに呼ぶ。")
      for f in shared { parts.append("### \(f)\n\n```swift\n\(apiOf(visualsDir.appendingPathComponent(f), root: project))\n```") }
    }

    // ユーザーのライブラリから jgv init がコピーした自作の部品 (parts/)。描き直さずに使ってもらう。
    // この動画で使うファイル (名前が絵コンテか visual に出てくるファイルと、それらが使うファイル) だけシグネチャを載せる
    let userDir = Project.partsDir(project)
    let userParts = ((try? fm.contentsOfDirectory(atPath: userDir.path)) ?? []).filter { $0.hasSuffix(".swift") }.sorted()
    if !userParts.isEmpty {
      let read = { (u: URL) in Safety.isPlainFile(u, under: project) ? ((try? String(contentsOf: u, encoding: .utf8)) ?? "") : "" }
      let visualFiles = ((try? fm.contentsOfDirectory(atPath: visualsDir.path)) ?? []).filter { $0.hasSuffix(".swift") }
      let visualsText = visualFiles.map { read(visualsDir.appendingPathComponent($0)) }.joined(separator: "\n")
      let storyboard = read(project.appendingPathComponent("storyboard.md"))
      let names = Dictionary(uniqueKeysWithValues: userParts.map { ($0, declaredNames(userDir.appendingPathComponent($0), root: project)) })
      var full = Set(userParts.filter { f in names[f]!.contains { mentions(storyboard, $0) || mentions(visualsText, $0) } })
      var queue = Array(full)
      while let f = queue.popLast() {
        let src = read(userDir.appendingPathComponent(f))
        for dep in userParts where !full.contains(dep) && names[dep]!.contains(where: { mentions(src, $0) }) {
          full.insert(dep)
          queue.append(dep)
        }
      }
      parts.append("## ユーザーのライブラリの部品（parts）")
      parts.append("これまでの動画で作って保存した道具・動き。同じものを描き直さず、そのまま呼ぶ（同じモジュールなので import は要らない。parts/ は編集しない）。")
      for f in userParts where full.contains(f) { parts.append("### \(f)\n\n```swift\n\(apiOf(userDir.appendingPathComponent(f), root: project))\n```") }
      let rest = userParts.filter { !full.contains($0) }
      if !rest.isEmpty {
        parts.append("### \(full.isEmpty ? "ファイル" : "ほかのファイル")（名前だけ）")
        parts.append("この動画の絵コンテ (storyboard.md) と visual に名前が出てこないファイル。使えそうな名前があるときだけ、そのファイルを読んでシグネチャを確かめる。")
        parts.append(rest.map { "- \($0): \(names[$0]!.joined(separator: ", "))" }.joined(separator: "\n"))
      }
    }

    // この動画の SVG の素材 (assets/*.svg): visual から Svg("名前") で描く。レイヤーと持つ所だけを載せる
    let assetsDir = Project.assetsDir(project)
    let svgs = ((try? fm.contentsOfDirectory(atPath: assetsDir.path)) ?? []).filter { $0.hasSuffix(".svg") }.sorted()
    if !svgs.isEmpty {
      parts.append(try pick(kit, "SVG の素材（assets）"))
      parts.append("## この動画の SVG の素材（assets）")
      parts.append("Svg(\"名前\", x:, y:, scale:, layers: [...]) で描く。見た目を確かめるときは SVG を Read せずに jgv overview の out/overview.html か snapshots を見る。")
      for f in svgs {
        guard Safety.isPlainFile(assetsDir.appendingPathComponent(f), under: project), let doc = try? SVGDocument.load(assetsDir.appendingPathComponent(f)) else { parts.append("### \(f)\n\n\(Safety.isPlainFile(assetsDir.appendingPathComponent(f), under: project) ? "読めない（SVG として壊れている）" : "読まない（シンボリックリンクか、ふつうのファイルではない）")"); continue }
        var lines = ["### \(f.dropLast(4))", "", String(format: "- 大きさ: %.0f × %.0f（原点 = %@）", doc.viewBox.width, doc.viewBox.height, doc.origin == Pt(doc.viewBox.midX, doc.viewBox.maxY) ? "底の中心" : "part-origin")]
        if !doc.layerNames.isEmpty { lines.append("- layers に渡せる名前: \(doc.layerNames.joined(separator: ", "))") }
        if !doc.colorNames.isEmpty { lines.append("- 配色の色で塗る所: \(doc.colorNames.map { "var(--\($0))" }.joined(separator: ", "))（Svg の colors で上書きできる）") }
        if !doc.parts.isEmpty { lines.append("- 持つ所 (svgParts): " + doc.parts.map { String(format: "%@ (%.0f, %.0f)", $0.0, $0.1.x, $0.1.y) }.joined(separator: ", ")) }
        if !doc.warnings.isEmpty { lines.append("- 描けないもの: \(doc.warnings.joined(separator: " / "))") }
        parts.append(lines.joined(separator: "\n"))
      }
    }

    // 工程ごとの行と句の番号。n.atPhrase(行, 句) の番号を数え違えないように (読点の無い行は句が 1 つだけ)。区切り方は jgv tts と同じ
    let phraseRe = try NSRegularExpression(pattern: ".+?(?:[。！？、，]+|[.,!?]+(?:\\s+|$)|$)")
    func phrasesOf(_ text: String) -> [String] {
      let m = phraseRe.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
      return (m.isEmpty ? [text] : m).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    // 句ごとの時刻 (工程の始まりからの秒) も timeline.json から載せる。台本を変えた後で jgv tts をしていない (文が違う) ときは載せない
    if Project.restoreBuildLangsBackup(project) { note("前の jgv build-langs が途中で止まっていたので、timeline と字幕を基準の台本のものに戻しました") }
    let tl = Safety.isPlainFile(Project.timelineFile(project), under: project) ? try? Timeline.load(Project.timelineFile(project)) : nil
    var withTimes = false
    var table: [String] = []
    for (si, sc) in (script["scenes"]?.array ?? []).enumerated() {
      let visual = sc["visual"]?.string ?? sc["visual"]?["type"]?.string ?? ""
      let heading = sc["heading"]?.string ?? ""
      let texts = (sc["lines"]?.array ?? []).map { $0.string ?? $0["text"]?.string ?? "" }
      let tLines = tl?.lines.filter { $0.sceneIndex == si } ?? []
      let fresh = tl != nil && si < tl!.scenes.count && tl!.scenes[si].heading == heading && tLines.count == texts.count && zip(tLines, texts).allSatisfy { $0.text == $1 }
      let tScene = fresh ? tl!.scenes[si] : nil
      if fresh { withTimes = true }
      var rows: [String] = []
      for (li, text) in texts.enumerated() {
        let ph = tScene != nil ? tLines[li].phrases : nil
        let items = phrasesOf(text).enumerated().map { k, p -> String in
          var sec = ""
          if let ph, k < ph.count, let ts = tScene { sec = String(format: " (%.1f〜%.1fs)", ph[k].start - ts.start, ph[k].end - ts.start) }
          return "[\(k)] \(p.trimmingCharacters(in: .whitespaces))\(sec)"
        }
        rows.append("- \(li): \(items.joined(separator: " "))")
      }
      let len = tScene.map { String(format: "（長さ %.1fs。終わりの状態には %.1fs までにそろえる）", $0.end - $0.start, $0.end - $0.start - 0.5) } ?? ""
      table.append((["### 工程 \(si) \(visual)「\(heading)」\(len)"] + rows).joined(separator: "\n"))
    }
    parts.append("## 各工程の行と句の番号（n.at(行) / n.atPhrase(行, 句)）")
    parts.append("句は読点・句点で区切った単位。\(withTimes ? "() は工程の始まりからの秒（その句を読んでいる時刻）。" : "（jgv tts の後で jgv brief を実行し直すと、句ごとの秒も載る）")**読点の無い行は句が 1 つ（[0] だけ）**で、atPhrase(行, 1) は使えない（行の途中の推定時刻になる）。その行の中で動きを分けるときは n.at(行, 秒) や n.endOf(行) からの時間で指定する。")
    parts += table

    // kit の動きの計算は引数の細部を確かめにソースを読みに行かれやすいので、シグネチャを載せておく
    let motion = kitSrc.appendingPathComponent("JGVKit/Motion.swift")
    if fm.fileExists(atPath: motion.path) {
      // プロジェクトに固定した kit (jgv vendor-kit の kit/) なら、プロジェクトのふつうのファイルとして読む (kit/ がリンクならその先は読まない)
      let api = Project.usesSharedPackage(project) ? apiOf(motion) : apiOf(motion, root: project)
      parts.append("## kit の動きの計算（JGVKit/Motion.swift のシグネチャ）\n\n```swift\n\(api)\n```")
    }

    // 絵コンテの「始まり」「終わり」に前後の工程を参照する書き方があれば警告する (担当には自分の工程の節しか渡らず、書き漏れた物は伝わらない)
    if Safety.isPlainFile(project.appendingPathComponent("storyboard.md"), under: project), let sb = try? String(contentsOf: project.appendingPathComponent("storyboard.md"), encoding: .utf8) {
      var heading = ""
      var refs: [String] = []
      for line in sb.components(separatedBy: "\n") {
        if line.hasPrefix("## ") { heading = String(line.dropFirst(3)); continue }
        let body = line.replacingOccurrences(of: "この工程の(始まり|終わり)", with: "", options: .regularExpression)
        if line.range(of: "(始まり|終わり)\\s*\\**\\s*[:：]", options: .regularExpression) != nil,
           body.range(of: "((の終わり|の始まり|前の工程|次の工程)(と同じ|のまま)|(?<![手以])前と同じ)", options: .regularExpression) != nil {
          refs.append("  \(heading): \(String(line.trimmingCharacters(in: .whitespaces).prefix(60)))…")
        }
      }
      if !refs.isEmpty {
        note("WARN: storyboard.md の「始まり」「終わり」が前後の工程を参照しています。担当には自分の工程の節しか渡らないので、状態をすべて書き下してください:\n\(refs.joined(separator: "\n"))")
      }
    }

    let md = parts.joined(separator: "\n\n") + "\n"
    let outDir = project.appendingPathComponent("out")
    // out/ がシンボリックリンクなら書かない (データを読むだけのコマンドで、プロジェクトの外にファイルを作らないように)
    try Safety.requireNoSymlinks(under: project, outDir)
    try fm.createDirectory(at: outDir, withIntermediateDirectories: true)
    let outFile = outDir.appendingPathComponent("brief.md")
    try md.write(to: outFile, atomically: true, encoding: .utf8)
    let rel = outFile.path.hasPrefix(cwd.path + "/") ? String(outFile.path.dropFirst(cwd.path.count + 1)) : outFile.path
    print("OK: \(rel) (\(md.count) 文字)")
  }
}
