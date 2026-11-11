// 打ち間違えた名前 (サブコマンドなど) に、近い名前を探す
import Foundation

public enum Suggest {
  /// 近い名前: 編集距離が 2 以下 (2 文字以下の語は 1 以下) で最も近いもの。無ければ、2 文字以上の語で前に一致するもの
  public static func closest(_ word: String, in names: [String]) -> String? {
    let w = word.lowercased()
    let scored = names.map { ($0, distance(Array(w), Array($0.lowercased()))) }
    if let best = scored.min(by: { $0.1 < $1.1 }), best.1 <= (w.count <= 2 ? 1 : 2) { return best.0 }
    guard w.count >= 2 else { return nil }
    return names.first { $0.lowercased().hasPrefix(w) }
  }

  /// 編集距離 (挿入・削除・置き換えを 1 回と数える)
  static func distance(_ a: [Character], _ b: [Character]) -> Int {
    var prev = Array(0 ... b.count)
    for (i, ca) in a.enumerated() {
      var cur = [i + 1]
      for (j, cb) in b.enumerated() { cur.append(min(prev[j + 1] + 1, cur[j] + 1, prev[j] + (ca == cb ? 0 : 1))) }
      prev = cur
    }
    return prev[b.count]
  }
}
