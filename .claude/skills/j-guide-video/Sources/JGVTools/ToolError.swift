// jgv のサブコマンドのエラー。localizedDescription がそのまま利用者へのメッセージになる
import Foundation
import JGVCore

public struct ToolError: LocalizedError, CustomStringConvertible {
  public let message: String
  /// 使い方 (引数の誤りのとき。表示する側が message の後に出す)
  public var usage: String?
  public init(_ message: String, usage: String? = nil) {
    self.message = message
    self.usage = usage
  }
  public init(message: String, usage: String? = nil) {
    self.init(message, usage: usage)
  }
  /// メッセージを出さずに終了コード 1 で終わる (子プロセスが既にエラーを表示したときなど)
  public static let silent = ToolError("")
  public var isSilent: Bool { message.isEmpty }
  public var errorDescription: String? { message }
  public var description: String { message }
}

/// ToolError 以外のエラーを利用者へのメッセージにする。
/// JSON.ParseError は LocalizedError でないので localizedDescription が「The operation couldn't be completed. (JGVCore.JSON.ParseError error 1.)」になる。
/// 自前の (CustomStringConvertible な) エラーは description、Foundation のエラー (ファイルが無い など) は localizedDescription を使う
public func userMessage(_ error: Error) -> String {
  if let e = error as? ToolError { return e.message }
  if let e = error as? JSON.ParseError { return e.message }
  if error is LocalizedError { return error.localizedDescription }
  // NSError (Foundation のエラー) の description は "Error Domain=… Code=…" なので使わない (Swift のエラーは NSError に橋渡しされるので型で見る)
  if !(type(of: error) is NSError.Type), let e = (error as Any) as? CustomStringConvertible { return e.description }
  return error.localizedDescription
}

/// 進み具合・補足・警告を stderr に出す (stdout には結果だけを出し、パイプやリダイレクトで扱えるようにする)
/// 先に print した結果より前に出ないよう、stdout を先に流す (パイプの stdout はバッファされる)
public func note(_ s: String) {
  fflush(stdout)
  FileHandle.standardError.write(Data((s + "\n").utf8))
}
