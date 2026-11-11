// Node 版のスクリプトを移植するための小道具: JS の正規表現・文字列・JSON の値の扱いを同じにする
import Foundation
import JGVCore

enum JSCompat {
  /// JS の \s と同じ文字 (文字クラスの中身)。ICU の \s とは少し違うので明示する
  static let ws = "\\t\\n\\x{0B}\\f\\r \\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{2028}\\x{2029}\\x{202F}\\x{205F}\\x{3000}\\x{FEFF}"
  /// JS の \w (ASCII だけ)
  static let word = "A-Za-z0-9_"

  static func isSpace(_ u: UInt16) -> Bool {
    switch u {
    case 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0xA0, 0x1680, 0x2000 ... 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF: return true
    default: return false
    }
  }

  /// String.prototype.trim
  static func trim(_ s: String) -> String {
    let u = Array(s.utf16)
    var a = 0, b = u.count
    while a < b, isSpace(u[a]) { a += 1 }
    while b > a, isSpace(u[b - 1]) { b -= 1 }
    if a == 0 && b == u.count { return s }
    return String(utf16CodeUnits: Array(u[a ..< b]), count: b - a)
  }

  /// String.prototype.padEnd (UTF-16 の長さ)
  static func padEnd(_ s: String, _ n: Int) -> String {
    let len = s.utf16.count
    return len >= n ? s : s + String(repeating: " ", count: n - len)
  }

  /// UTF-16 の並びとして等しいか (JS の ===)
  static func same(_ a: String, _ b: String) -> Bool { a.utf16.elementsEqual(b.utf16) }

  /// String.prototype.indexOf(w, from) (UTF-16 の位置)
  static func indexOf(_ s: [UInt16], _ w: [UInt16], _ from: Int) -> Int {
    let start = max(0, min(from, s.count))
    if w.isEmpty { return start }
    if w.count > s.count { return -1 }
    var i = start
    while i + w.count <= s.count {
      if s[i] == w[0] {
        var k = 1
        while k < w.count && s[i + k] == w[k] { k += 1 }
        if k == w.count { return i }
      }
      i += 1
    }
    return -1
  }

  static func utf16String(_ u: ArraySlice<UInt16>) -> String { String(utf16CodeUnits: Array(u), count: u.count) }

  /// テンプレート文字列に埋め込んだときの JS の文字列化 (String(x))
  static func string(_ v: JSON?) -> String {
    guard let v else { return "undefined" }
    switch v {
    case .null: return "null"
    case let .bool(b): return b ? "true" : "false"
    case let .number(n): return JSON.jsNumber(n)
    case let .string(s): return s
    case let .array(a): return a.map { $0.isNull ? "" : string($0) }.joined(separator: ",")
    case .object: return "[object Object]"
    }
  }

  /// JS の真偽値としての評価
  static func truthy(_ v: JSON?) -> Bool {
    guard let v else { return false }
    switch v {
    case .null: return false
    case let .bool(b): return b
    case let .number(n): return n != 0 && !n.isNaN
    case let .string(s): return !s.isEmpty
    case .array, .object: return true
    }
  }

  /// a ?? b (null と undefined のときだけ b)
  static func coalesce(_ a: JSON?, _ b: @autoclosure () -> JSON?) -> JSON? {
    if let a, !a.isNull { return a }
    return b()
  }

  static func isPlainObject(_ v: JSON?) -> Bool {
    if case .object = v { return true }
    return false
  }

  /// path.join (POSIX。区切りの重複・"."・".." を整える)
  static func pathJoin(_ parts: String...) -> String {
    let joined = parts.filter { !$0.isEmpty }.joined(separator: "/")
    if joined.isEmpty { return "." }
    let absolute = joined.hasPrefix("/")
    let trailing = joined.hasSuffix("/")
    var out: [String] = []
    for seg in joined.split(separator: "/", omittingEmptySubsequences: true) {
      if seg == "." { continue }
      if seg == ".." {
        if let last = out.last, last != ".." { out.removeLast() } else if !absolute { out.append("..") }
        continue
      }
      out.append(String(seg))
    }
    var p = (absolute ? "/" : "") + out.joined(separator: "/")
    if p.isEmpty { p = absolute ? "/" : "." }
    if trailing && p != "/" { p += "/" }
    return p
  }

  static func log(_ s: String) {
    print(s)
  }

  static func warn(_ s: String) {
    note(s)
  }
}

/// JS の正規表現の代わり (NSRegularExpression。UTF-16 で走査するので JS の u なしの正規表現と同じ位置になる)
struct JSRegex {
  let re: NSRegularExpression
  init(_ pattern: String) {
    // 移植した固定のパターンだけを使うので、書き誤りはプログラムの誤り
    re = try! NSRegularExpression(pattern: pattern, options: [])
  }

  private static func range(_ s: String) -> NSRange { NSRange(location: 0, length: (s as NSString).length) }

  func test(_ s: String) -> Bool { re.firstMatch(in: s, options: [], range: JSRegex.range(s)) != nil }

  /// s.match(re) (g なし): 全体とグループ。参加しなかったグループは nil
  func match(_ s: String) -> [String?]? {
    guard let m = re.firstMatch(in: s, options: [], range: JSRegex.range(s)) else { return nil }
    return JSRegex.groups(m, s as NSString)
  }

  /// s.match(re) (g つき): 一致した文字列の一覧。無ければ nil
  func matchAll(_ s: String) -> [String]? {
    let ns = s as NSString
    let ms = re.matches(in: s, options: [], range: JSRegex.range(s))
    return ms.isEmpty ? nil : ms.map { ns.substring(with: $0.range) }
  }

  /// s.replace(re (g つき), (m, ...groups) => …)
  func replace(_ s: String, _ f: ([String?]) -> String) -> String {
    let ns = s as NSString
    let ms = re.matches(in: s, options: [], range: JSRegex.range(s))
    if ms.isEmpty { return s }
    var out = ""
    var last = 0
    for m in ms {
      out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
      out += f(JSRegex.groups(m, ns))
      last = m.range.location + m.range.length
    }
    out += ns.substring(from: last)
    return out
  }

  /// s.split(re) (グループの無いパターン)
  func split(_ s: String) -> [String] {
    let ns = s as NSString
    let ms = re.matches(in: s, options: [], range: JSRegex.range(s))
    var out: [String] = []
    var last = 0
    for m in ms {
      if m.range.length == 0 && (m.range.location == 0 || m.range.location == ns.length) { continue }
      out.append(ns.substring(with: NSRange(location: last, length: m.range.location - last)))
      last = m.range.location + m.range.length
    }
    out.append(ns.substring(from: last))
    return out
  }

  private static func groups(_ m: NSTextCheckingResult, _ ns: NSString) -> [String?] {
    (0 ..< m.numberOfRanges).map { k in
      let r = m.range(at: k)
      return r.location == NSNotFound ? nil : ns.substring(with: r)
    }
  }
}
