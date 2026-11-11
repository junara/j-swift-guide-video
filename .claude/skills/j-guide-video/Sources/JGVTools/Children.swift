// jgv が起動した子プロセス (動画の実行ファイル・swift build・macOS の音声の合成) を、jgv が Ctrl-C などで止まるときに一緒に止める。
// Foundation の Process は子を別のプロセスグループで起動するので、端末の Ctrl-C は子に届かず、子だけが残って書き出しを続けてしまう
import Foundation

/// 動いている子のプロセス番号の表。シグナルのハンドラから読むので、Swift の配列ではなく固定の大きさの生のメモリにする
/// (ハンドラの中で遅延初期化・排他性の確かめ・参照の数え直しが起きないように)
private let slotCount = 64
nonisolated(unsafe) private let childPids: UnsafeMutablePointer<pid_t> = {
  let p = UnsafeMutablePointer<pid_t>.allocate(capacity: slotCount)
  p.initialize(repeating: 0, count: slotCount)
  return p
}()
/// ハンドラが使う表の先頭 (遅延初期化の済んだ値をここへ写してから、ハンドラを置く)
nonisolated(unsafe) private var handlerTable: UnsafeMutablePointer<pid_t>? = nil
/// 子ごとに送るシグナル (swift build は SIGINT、swift のインタプリタは SIGTERM。起動直後の swift-driver は SIGINT を無視している)
nonisolated(unsafe) private let childSignals: UnsafeMutablePointer<Int32> = {
  let p = UnsafeMutablePointer<Int32>.allocate(capacity: slotCount)
  p.initialize(repeating: SIGINT, count: slotCount)
  return p
}()

/// シグナルのハンドラ: 子ごとに決めたシグナル (既定 SIGINT) を送ってから終わる (ハンドラの中では kill と _exit だけを使う)。
/// SIGINT にするのは、swift build (SwiftPM) が SIGINT なら自分の子 (コンパイラ) を止めてから終わるため。動画の実行ファイルなどは既定の動作で終わる
private func forwardSignal(_ sig: Int32) {
  // 子はそれぞれ自分がリーダーのプロセスグループにいる (Foundation の Process がそう起動する) ので、グループごとに送る。
  // tts.command を sh -c で書いたときの孫 (sh が待っているコマンド) まで止まる。グループに送れなければ子だけに送る
  if let t = handlerTable { for i in 0 ..< slotCount where t[i] > 0 { if kill(-t[i], childSignals[i]) != 0 { kill(t[i], childSignals[i]) } } }
  _exit(128 + sig)
}

enum Children {
  private static let lock = NSLock()
  private static let signals: [Int32] = [SIGINT, SIGTERM, SIGHUP]
  private static let installOnce: Void = {
    handlerTable = childPids
    // SIG_IGN にすると子にも引き継がれてしまうので、ハンドラを置く (exec した子では既定に戻る)
    for sig in signals { signal(sig, forwardSignal) }
  }()

  /// 表を書き換える間はシグナルを止めておく (起動してから表に入れるまでの間に Ctrl-C が来ても、子を取りこぼさない)
  private static func withSignalsBlocked(_ body: () throws -> Void) rethrows {
    var set = sigset_t(), old = sigset_t()
    sigemptyset(&set)
    for s in signals { sigaddset(&set, s) }
    pthread_sigmask(SIG_BLOCK, &set, &old)
    defer { pthread_sigmask(SIG_SETMASK, &old, nil) }
    try body()
  }

  /// p を起動して、jgv が止まるときに一緒に止める対象に入れる。終わったら finished(p) で外す
  static func run(_ p: Process, stop: Int32 = SIGINT) throws {
    _ = installOnce
    // ほかのスレッド (音声の合成の並列の作業) では、シグナルをずっと止めておく。シグナルはメインのスレッドで受けるので、
    // 起動してから表に入れるまでの間に、別のスレッドでハンドラが動いて子を取りこぼすことが無い
    if !Thread.isMainThread {
      var set = sigset_t()
      sigemptyset(&set)
      for s in signals { sigaddset(&set, s) }
      pthread_sigmask(SIG_BLOCK, &set, nil)
    }
    try withSignalsBlocked {
      try p.run()
      lock.lock()
      defer { lock.unlock() }
      if let i = (0 ..< slotCount).first(where: { childPids[$0] == 0 }) { childSignals[i] = stop; childPids[i] = p.processIdentifier }
    }
  }

  static func finished(_ p: Process) {
    lock.lock()
    defer { lock.unlock() }
    let pid = p.processIdentifier
    if let i = (0 ..< slotCount).first(where: { childPids[$0] == pid }) { childPids[i] = 0 }
  }
}
