// JSON の値 (script.json / timeline.json / defaults.json)。キーの順番を保って読み書きし、
// JS の JSON.stringify(x, null, 2) と同じ形で書き出す (Node 版と同じファイルになるように)
import Foundation

public enum JSON: Equatable, CustomStringConvertible, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
  ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByNilLiteral
{
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSON])
  case object([(String, JSON)])

  public init(stringLiteral value: String) { self = .string(value) }
  public init(integerLiteral value: Int) { self = .number(Double(value)) }
  public init(floatLiteral value: Double) { self = .number(value) }
  public init(booleanLiteral value: Bool) { self = .bool(value) }
  public init(arrayLiteral elements: JSON...) { self = .array(elements) }
  public init(dictionaryLiteral elements: (String, JSON)...) { self = .object(elements) }
  public init(nilLiteral: ()) { self = .null }

  public static func == (a: JSON, b: JSON) -> Bool {
    switch (a, b) {
    case (.null, .null): return true
    case let (.bool(x), .bool(y)): return x == y
    case let (.number(x), .number(y)): return x == y
    case let (.string(x), .string(y)): return x == y
    case let (.array(x), .array(y)): return x == y
    case let (.object(x), .object(y)):
      return x.count == y.count && x.allSatisfy { kv in y.contains { $0.0 == kv.0 && $0.1 == kv.1 } }
    default: return false
    }
  }

  // ---------- 取り出し ----------

  public subscript(key: String) -> JSON? {
    get { if case let .object(kv) = self { return kv.first { $0.0 == key }?.1 }; return nil }
    set {
      guard case var .object(kv) = self else { return }
      if let i = kv.firstIndex(where: { $0.0 == key }) {
        if let v = newValue { kv[i].1 = v } else { kv.remove(at: i) }
      } else if let v = newValue {
        kv.append((key, v))
      }
      self = .object(kv)
    }
  }

  public subscript(index: Int) -> JSON? {
    if case let .array(a) = self, index >= 0, index < a.count { return a[index] }
    return nil
  }

  public var string: String? { if case let .string(s) = self { return s }; return nil }
  public var double: Double? { if case let .number(n) = self { return n }; return nil }
  /// 整数 (小数は切り捨て)。無限大や Int に収まらない数は nil (Int(Double) は落ちるので)
  public var int: Int? { double.flatMap { $0.isFinite && abs($0) < 9.0e18 ? Int($0) : nil } }
  public var bool: Bool? { if case let .bool(b) = self { return b }; return nil }
  public var array: [JSON]? { if case let .array(a) = self { return a }; return nil }
  public var object: [(String, JSON)]? { if case let .object(o) = self { return o }; return nil }
  public var isNull: Bool { if case .null = self { return true }; return false }
  public var keys: [String] { object?.map { $0.0 } ?? [] }

  // ---------- 読み込み ----------

  public struct ParseError: Error, CustomStringConvertible {
    public let message: String
    public var description: String { message }
  }

  public static func parse(_ text: String) throws -> JSON {
    var p = Parser(Array(text.utf8))
    p.skip()
    let v = try p.value()
    p.skip()
    if p.i < p.s.count { throw p.error("JSON の後に余分な文字があります") }
    return v
  }

  public static func read(_ url: URL) throws -> JSON {
    var data = try Data(contentsOf: url)
    // 先頭の BOM (EF BB BF。Windows のエディタが付けることがある) は読み飛ばす
    if data.starts(with: [0xEF, 0xBB, 0xBF]) { data = data.dropFirst(3) }
    do {
      return try parse(String(decoding: data, as: UTF8.self))
    } catch let e as ParseError {
      throw ParseError(message: "\(url.path): \(e.message)")
    }
  }

  private struct Parser {
    let s: [UInt8]
    var i = 0
    /// 入れ子の深さ (深すぎる JSON でスタックがあふれて落ちないように、上限で止める)
    var depth = 0
    init(_ s: [UInt8]) { self.s = s }

    func error(_ m: String) -> ParseError {
      var line = 1, col = 1
      for k in 0 ..< min(i, s.count) { if s[k] == 10 { line += 1; col = 1 } else { col += 1 } }
      return ParseError(message: "\(m) (\(line) 行 \(col) 文字目)")
    }

    mutating func skip() {
      while i < s.count, s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13 { i += 1 }
    }

    mutating func value() throws -> JSON {
      depth += 1
      defer { depth -= 1 }
      if depth > 128 { throw error("入れ子が深すぎます (128 段まで)") }
      skip()
      guard i < s.count else { throw error("JSON が途中で終わっています") }
      switch s[i] {
      case UInt8(ascii: "{"):
        i += 1
        var kv: [(String, JSON)] = []
        skip()
        if i < s.count, s[i] == UInt8(ascii: "}") { i += 1; return .object(kv) }
        while true {
          skip()
          guard i < s.count, s[i] == UInt8(ascii: "\"") else { throw error("オブジェクトのキーが文字列ではありません") }
          let k = try string()
          skip()
          guard i < s.count, s[i] == UInt8(ascii: ":") else { throw error(": がありません") }
          i += 1
          let v = try value()
          kv.append((k, v))
          skip()
          guard i < s.count else { throw error("} がありません") }
          if s[i] == UInt8(ascii: ",") { i += 1; continue }
          if s[i] == UInt8(ascii: "}") { i += 1; return .object(kv) }
          throw error(", か } がありません")
        }
      case UInt8(ascii: "["):
        i += 1
        var a: [JSON] = []
        skip()
        if i < s.count, s[i] == UInt8(ascii: "]") { i += 1; return .array(a) }
        while true {
          a.append(try value())
          skip()
          guard i < s.count else { throw error("] がありません") }
          if s[i] == UInt8(ascii: ",") { i += 1; continue }
          if s[i] == UInt8(ascii: "]") { i += 1; return .array(a) }
          throw error(", か ] がありません")
        }
      case UInt8(ascii: "\""):
        return .string(try string())
      case UInt8(ascii: "t"):
        if s[i...].starts(with: Array("true".utf8)) { i += 4; return .bool(true) }
      case UInt8(ascii: "f"):
        if s[i...].starts(with: Array("false".utf8)) { i += 5; return .bool(false) }
      case UInt8(ascii: "n"):
        if s[i...].starts(with: Array("null".utf8)) { i += 4; return .null }
      default:
        let start = i
        while i < s.count, "+-0123456789.eE".utf8.contains(s[i]) { i += 1 }
        // 1e999 などの無限大は JSON の数ではないので読めない値にする (fps などに入ると Int() で落ちる)
        if let d = Double(String(decoding: s[start ..< i], as: UTF8.self)), d.isFinite { return .number(d) }
        i = start
      }
      throw error("読めない値があります")
    }

    mutating func string() throws -> String {
      i += 1
      var bytes: [UInt8] = []
      while i < s.count {
        let c = s[i]
        if c == UInt8(ascii: "\"") { i += 1; return String(decoding: bytes, as: UTF8.self) }
        if c == UInt8(ascii: "\\") {
          i += 1
          guard i < s.count else { break }
          let e = s[i]
          switch e {
          case UInt8(ascii: "n"): bytes.append(10)
          case UInt8(ascii: "t"): bytes.append(9)
          case UInt8(ascii: "r"): bytes.append(13)
          case UInt8(ascii: "b"): bytes.append(8)
          case UInt8(ascii: "f"): bytes.append(12)
          case UInt8(ascii: "u"):
            guard i + 4 < s.count, let code = UInt32(String(decoding: s[i + 1 ... i + 4], as: UTF8.self), radix: 16) else { throw error("\\u の後が読めません") }
            i += 4
            var scalar = code
            // サロゲートペア
            if code >= 0xD800 && code < 0xDC00, i + 6 < s.count, s[i + 1] == UInt8(ascii: "\\"), s[i + 2] == UInt8(ascii: "u"),
               let low = UInt32(String(decoding: s[i + 3 ... i + 6], as: UTF8.self), radix: 16), low >= 0xDC00 && low < 0xE000 {
              scalar = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
              i += 6
            }
            bytes += Array(String(Character(Unicode.Scalar(scalar) ?? "?")).utf8)
          default: bytes.append(e)
          }
          i += 1
          continue
        }
        bytes.append(c)
        i += 1
      }
      throw error("文字列が閉じていません")
    }
  }

  // ---------- 書き出し (JSON.stringify(x, null, 2) と同じ形) ----------

  public var description: String { stringify(indent: 2) }

  public func stringify(indent: Int = 2) -> String {
    var out = ""
    write(&out, indent: indent, level: 0)
    return out
  }

  private func write(_ out: inout String, indent: Int, level: Int) {
    let nl = indent > 0 ? "\n" : ""
    let pad = String(repeating: " ", count: indent * (level + 1))
    let padEnd = String(repeating: " ", count: indent * level)
    switch self {
    case .null: out += "null"
    case let .bool(b): out += b ? "true" : "false"
    case let .number(n): out += JSON.jsNumber(n)
    case let .string(s): out += JSON.quote(s)
    case let .array(a):
      if a.isEmpty { out += "[]"; return }
      out += "[" + nl
      for (k, v) in a.enumerated() {
        out += pad
        v.write(&out, indent: indent, level: level + 1)
        if k < a.count - 1 { out += "," }
        out += nl
      }
      out += padEnd + "]"
    case let .object(kv):
      if kv.isEmpty { out += "{}"; return }
      out += "{" + nl
      for (k, item) in kv.enumerated() {
        out += pad + JSON.quote(item.0) + (indent > 0 ? ": " : ":")
        item.1.write(&out, indent: indent, level: level + 1)
        if k < kv.count - 1 { out += "," }
        out += nl
      }
      out += padEnd + "}"
    }
  }

  /// JS の数値の文字列化 (1 → "1"、0.5 → "0.5"、1e-7 → "1e-7")
  public static func jsNumber(_ n: Double) -> String {
    if !n.isFinite { return "null" }
    if n == n.rounded(), abs(n) < 1e21 { return String(format: "%.0f", n) == "-0" ? "0" : String(format: "%.0f", n) }
    var s = "\(n)"
    if let e = s.firstIndex(of: "e") {
      let mant = s[..<e]
      var exp = String(s[s.index(after: e)...])
      let neg = exp.hasPrefix("-")
      exp = String(exp.drop { $0 == "-" || $0 == "+" || $0 == "0" })
      let ev = Int(exp) ?? 0
      if neg && ev <= 6 {
        // JS は 1e-6 までは小数で書く
        return Decimal(string: s).map { "\($0)" } ?? s
      }
      s = "\(mant)e\(neg ? "-" : "+")\(exp)"
    }
    return s
  }

  /// JSON の文字列のエスケープ (JSON.stringify と同じ: 制御文字と " \ だけ)
  public static func quote(_ s: String) -> String {
    var out = "\""
    for u in s.unicodeScalars {
      switch u {
      case "\"": out += "\\\""
      case "\\": out += "\\\\"
      case "\n": out += "\\n"
      case "\r": out += "\\r"
      case "\t": out += "\\t"
      case "\u{8}": out += "\\b"
      case "\u{c}": out += "\\f"
      default:
        if u.value < 0x20 { out += String(format: "\\u%04x", u.value) } else { out.unicodeScalars.append(u) }
      }
    }
    return out + "\""
  }
}
