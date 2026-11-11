// jgv api: kit (と、プロジェクトの parts/・visuals/ の小文字のファイル) の関数・定数・型を、宣言と説明 (///) で引く。
// 道具の引数や持つ所 (〜_PARTS) を、ソースを grep しなくても 1 回で調べられるように。
//   jgv api              … ファイルごとの名前の一覧 (行頭の宣言だけ)
//   jgv api やかん        … 名前・宣言・説明・見出し (// ---------- やかん ----------) に、すべての語を含むもの
import Foundation
import JGVCore

public enum ApiTool {
  struct Decl {
    var name: String
    var decl: String
    var doc: String
    /// ファイルの中の見出し (// ---------- 〜 ----------)
    var section: String
    var file: String
    var line: Int
    /// 行頭の宣言 (型の中のメンバーではない)
    var topLevel: Bool
  }

  public static func run(_ args: [String]) throws {
    let words = args.filter { !$0.hasPrefix("--") }.map { $0.lowercased() }
    let decls = collect()
    if args.contains("--json") {
      // 語が無ければ行頭の宣言をすべて、あれば当たるものをすべて (件数で切らない)
      let hits = words.isEmpty ? decls.filter { $0.topLevel } : decls.filter { matches($0, words) }
      if hits.isEmpty && !words.isEmpty { throw ToolError("\(words.joined(separator: " ")) に当たるものがありません (jgv api だけで名前の一覧)") }
      print(JSON.array(hits.map { d in
        .object([("name", .string(d.name)), ("file", .string(d.file)), ("line", .number(Double(d.line))), ("section", .string(d.section)),
                 ("decl", .string(d.decl)), ("doc", .string(d.doc)), ("topLevel", .bool(d.topLevel))])
      }).description)
      return
    }
    if words.isEmpty {
      var byFile: [(String, [String])] = []
      for d in decls where d.topLevel {
        if byFile.last?.0 == d.file { byFile[byFile.count - 1].1.append(d.name) } else { byFile.append((d.file, [d.name])) }
      }
      for (f, names) in byFile { print("\(f): \(names.joined(separator: " "))") }
      note("(jgv api <語> で宣言と説明を出す。例: jgv api やかん / jgv api Kettle / jgv api 持つ所)")
      return
    }
    let hits = decls.filter { matches($0, words) }
    if hits.isEmpty { throw ToolError("\(words.joined(separator: " ")) に当たるものがありません (jgv api だけで名前の一覧)") }
    let limit = 40
    for d in hits.prefix(limit) {
      print("\(d.file):\(d.line)\(d.section.isEmpty ? "" : "  [\(d.section)]")")
      if !d.doc.isEmpty { print(d.doc.split(separator: "\n").map { "  /// \($0)" }.joined(separator: "\n")) }
      print("  \(d.decl)")
    }
    if hits.count > limit { note("… ほか \(hits.count - limit) 件 (語を足して絞る)") }
  }

  /// 語 (小文字) をすべて、名前・宣言・説明・見出しのどこかに含むか
  static func matches(_ d: Decl, _ words: [String]) -> Bool {
    let hay = [d.name, d.decl, d.doc, d.section].joined(separator: "\n").lowercased()
    return words.allSatisfy { hay.contains($0) }
  }

  /// skill の kit と、カレントがプロジェクトなら parts/・visuals/ の小文字のファイルの宣言
  static func collect() -> [Decl] {
    let fm = FileManager.default
    var files: [(URL, String, Bool)] = []
    let src = Project.skillDir.appendingPathComponent("Sources")
    for m in ["JGVKit", "JGVCore"] {
      let dir = src.appendingPathComponent(m)
      guard let e = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { continue }
      for case let f as URL in e where f.pathExtension == "swift" {
        files.append((f, m + "/" + f.path.dropFirst(dir.path.count + 1), true))
      }
    }
    let root = URL(fileURLWithPath: fm.currentDirectoryPath)
    if fm.fileExists(atPath: root.appendingPathComponent("jgv.json").path) {
      for sub in ["parts", "visuals"] {
        for f in ((try? fm.contentsOfDirectory(atPath: root.appendingPathComponent(sub).path)) ?? []).sorted()
        where f.hasSuffix(".swift") && (sub == "parts" || f.first?.isLowercase == true)
          // シンボリックリンクの先 (プロジェクトの外かもしれない) は読まない
          && Safety.isPlainFile(root.appendingPathComponent("\(sub)/\(f)"), under: root) {
          files.append((root.appendingPathComponent("\(sub)/\(f)"), "\(sub)/\(f)", false))
        }
      }
    }
    files.sort { ($0.2 ? 1 : 0, $0.1) < ($1.2 ? 1 : 0, $1.1) }
    // kit は public の宣言だけ、プロジェクトのファイルは行頭の宣言 (private 以外)
    let kitDecl = try! NSRegularExpression(pattern: "^\\s*public\\s+(?:static\\s+)?(?:final\\s+)?(func|let|var|struct|enum|class|typealias)\\s+([A-Za-z_][A-Za-z0-9_]*)")
    let projDecl = try! NSRegularExpression(pattern: "^(?:public\\s+)?(func|let|var|struct|enum|class|typealias)\\s+([A-Za-z_][A-Za-z0-9_]*)")
    // 型の初期化 (PourOptions(…) など)。名前は「型.init」にする
    let initDecl = try! NSRegularExpression(pattern: "^\\s+(?:public\\s+)?init\\(")
    let extDecl = try! NSRegularExpression(pattern: "^(?:public\\s+)?extension\\s+([A-Za-z_][A-Za-z0-9_]*)")
    var out: [Decl] = []
    for (url, name, isKit) in files {
      guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
      var doc: [String] = []
      var section = ""
      var currentType = ""
      let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
      for (i, raw) in lines.enumerated() {
        let line = String(raw)
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("// ----------") {
          section = t.trimmingCharacters(in: CharacterSet(charactersIn: "/- "))
          doc = []
          continue
        }
        if t.hasPrefix("///") { doc.append(String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces)); continue }
        let re = isKit ? kitDecl : projDecl
        let range = NSRange(line.startIndex..., in: line)
        if let m = extDecl.firstMatch(in: line, range: range), let r = Range(m.range(at: 1), in: line) { currentType = String(line[r]) }
        var found: String?
        if let m = re.firstMatch(in: line, range: range), let r = Range(m.range(at: 2), in: line), let k = Range(m.range(at: 1), in: line) {
          found = String(line[r])
          if !line.hasPrefix(" ") && ["struct", "enum", "class"].contains(String(line[k])) { currentType = found! }
        } else if !currentType.isEmpty, (isKit ? t.hasPrefix("public init(") : true), initDecl.firstMatch(in: line, range: range) != nil {
          found = "\(currentType).init"
        }
        if let found {
          // 宣言は本体の { の手前まで。引数が次の行に続くときは、括弧が閉じるまでつなぐ
          var decl = t
          var k = i
          while decl.filter({ $0 == "(" }).count > decl.filter({ $0 == ")" }).count && k + 1 < lines.count && k < i + 8 {
            k += 1
            decl += " " + lines[k].trimmingCharacters(in: .whitespaces)
          }
          if let brace = decl.range(of: " {", options: .backwards), !decl.hasSuffix("{}") { decl = String(decl[..<brace.lowerBound]) }
          out.append(Decl(name: found, decl: decl, doc: doc.joined(separator: "\n"), section: section, file: name, line: i + 1,
                          topLevel: !line.hasPrefix(" ")))
        }
        if !t.hasPrefix("@") { doc = [] }
      }
    }
    return out
  }
}
