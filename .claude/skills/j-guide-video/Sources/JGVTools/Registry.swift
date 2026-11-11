// プロジェクトの visuals/*.swift を集めて、visual の登録表 (ビルド用のパッケージの generated/Visuals.swift) の中身を作る。
// 大文字で始まり、ファイル名と同じ名前の func <名前>(_ props: Props) があるファイルだけを visual として登録する
// (props.swift・shared.swift などの補助ファイルは対象外)。
// <名前>_PREVIEW: [PreviewItem] (例: PROPS_PREVIEW) を定義したファイルは、jgv preview の見本として登録する
import Foundation
import JGVCore

public enum Registry {
  /// visual の名前 (並べ替え済み)
  public static func visualNames(_ root: URL) throws -> [String] {
    let dir = Project.visualsDir(root)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
    return files.compactMap { f -> String? in
      guard f.hasSuffix(".swift"), let first = f.first, first.isUppercase else { return nil }
      let name = String(f.dropLast(6))
      guard Safety.isVisualName(name),
            let src = try? String(contentsOf: dir.appendingPathComponent(f), encoding: .utf8) else { return nil }
      let decl = "(?m)^\\s*(public\\s+)?func\\s+\(name)\\s*\\(\\s*_\\s+\\w+\\s*:\\s*Props\\s*\\)"
      return src.range(of: decl, options: .regularExpression) != nil ? name : nil
    }
  }

  /// PREVIEW を定義しているファイル: (表示名 "visuals/props", 変数名 "PROPS_PREVIEW")
  public static func previewDecls(_ root: URL) -> [(file: String, name: String)] {
    var out: [(String, String)] = []
    for sub in ["visuals", "parts"] {
      let dir = root.appendingPathComponent(sub)
      guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { continue }
      for f in files.sorted() where f.hasSuffix(".swift") {
        guard let src = try? String(contentsOf: dir.appendingPathComponent(f), encoding: .utf8) else { continue }
        let re = try! NSRegularExpression(pattern: "(?m)^\\s*(?:public\\s+)?let\\s+([A-Z][A-Z0-9_]*_PREVIEW)\\s*:\\s*\\[PreviewItem\\]")
        for m in re.matches(in: src, range: NSRange(src.startIndex..., in: src)) {
          if let r = Range(m.range(at: 1), in: src) { out.append(("\(sub)/\(f.dropLast(6))", String(src[r]))) }
        }
      }
    }
    return out
  }

  static func source(_ header: String, _ names: [String], _ previews: [(file: String, name: String)]) -> String {
    // ファイル名は Swift の文字列リテラルに入れるので \ と " と改行をエスケープする
    func lit(_ s: String) -> String {
      "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r") + "\""
    }
    return [
      header,
      "import JGVKit",
      "",
      "let customVisuals: [String: VisualFn] = [\(names.isEmpty ? ":" : names.map { "\"\($0)\": \($0)" }.joined(separator: ", "))]",
      "",
      "let previews: [(file: String, items: [PreviewItem])] = [\(previews.map { "(\(lit($0.file)), \($0.name))" }.joined(separator: ", "))]",
      "",
    ].joined(separator: "\n")
  }

  /// すべての visual の登録表
  public static func text(_ root: URL) throws -> String {
    source("// jgv がプロジェクトの visuals/*.swift から作る登録表 (編集しない)", try visualNames(root), previewDecls(root))
  }

  /// 工程 scene だけの登録表 (その工程の visual と、補助ファイル・parts の PREVIEW)
  static func sceneText(_ root: URL, scene: Int, visual: String?) throws -> String {
    let names = try visualNames(root).filter { $0 == visual }
    let previews = previewDecls(root).filter { !$0.file.hasPrefix("visuals/") || $0.file.split(separator: "/").last?.first?.isLowercase == true }
    return source("// jgv snapshots --scene=\(scene) 用の、この工程だけの登録表 (編集しない)", names, previews)
  }
}
