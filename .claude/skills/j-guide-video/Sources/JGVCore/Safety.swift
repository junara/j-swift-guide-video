// ファイルを消す・書く前の確かめと、いくつかのモジュールで共通に使う小さな道具
// (visual 名の形、SHA の 16 進、jgv のエラー)
import CryptoKit
import Foundation

/// jgv のエラー (JGVCore / JGVRender で使う。メッセージはそのまま利用者に見せる)
public struct JGVError: LocalizedError, CustomStringConvertible {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
  public var description: String { message }
}

public enum Safety {
  /// visual 名 (visuals/<名前>.swift・Swift の関数名・cues/<名前>.cue になる) の形。英大文字で始まる英数字・_
  public static func isVisualName(_ s: String) -> Bool {
    s.range(of: "^[A-Z][A-Za-z0-9_]*$", options: .regularExpression) != nil
  }

  /// url がシンボリックリンクか (リンクの先は見ない)
  public static func isSymlink(_ url: URL) -> Bool {
    (try? FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeSymbolicLink
  }

  /// url が (リンクではない) ふつうのファイルか
  public static func isRegularFile(_ url: URL) -> Bool {
    (try? FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeRegular
  }

  /// 読んで出力 (brief / overview) に載せてよいプロジェクトのファイルか: ふつうのファイルで、それもそのフォルダもシンボリックリンクではない
  /// (リンクでプロジェクトの外のファイルの中身を、データを読むだけのコマンドの出力に載せないように)
  public static func isPlainFile(_ url: URL, under root: URL) -> Bool {
    isRegularFile(url) && (try? requireNoSymlinks(under: root, url)) != nil
  }

  /// root から url までのフォルダ (root は含めない) にシンボリックリンクが無いことを確かめる。
  /// jgv がその中のファイルを消す・書き直すので、プロジェクトに置かれたリンクでほかの場所のファイルを消さないように
  public static func requireNoSymlinks(under root: URL, _ url: URL) throws {
    // standardizedFileURL は、あるパスだけ /private を外す (/private/tmp → /tmp) ので使わず、文字のまま比べる
    let base = root.pathComponents
    let comps = url.pathComponents
    guard comps.starts(with: base), !comps.dropFirst(base.count).contains(where: { $0 == ".." || $0 == "." }) else {
      throw JGVError("\(url.path) はプロジェクト (\(root.path)) の外です")
    }
    var cur = root
    for c in comps.dropFirst(base.count) {
      cur.appendPathComponent(c)
      if isSymlink(cur) {
        throw JGVError("\(cur.path) がシンボリックリンクです。jgv はこの中のファイルを消す・書き直すので、リンクをやめてふつうのフォルダにしてください")
      }
    }
  }
}

extension Digest {
  /// 16 進の文字列 (小文字)
  public var hex: String { map { String(format: "%02x", $0) }.joined() }
}

/// ファイルの中身の SHA-256 (16 進)。読めなければ nil。timeline が作られた台本の確かめに使う (jgv tts が書き、render が照合する)
public func sha256Hex(of url: URL) -> String? {
  (try? Data(contentsOf: url)).map { SHA256.hash(data: $0).hex }
}
