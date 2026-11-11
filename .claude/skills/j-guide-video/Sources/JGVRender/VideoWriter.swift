// 動画の書き出し (AVAssetWriter)。フレームは複数のスレッドで並列に描き、順番どおりに H.264 で書く。音声は AAC
import AVFoundation
import CoreVideo
import Foundation
import JGVCore

public enum VideoWriter {
  /// frames 枚を描いて url (mp4) に書き出す。draw はフレーム番号の絵を cg に描く (スレッドをまたいで同時に呼ばれる)
  public static func write(
    to url: URL, width: Int, height: Int, fps: Double, frames: Int, audio: [Float]?, audioRate: Double = AudioMix.sampleRate,
    parallel: Int = max(1, ProcessInfo.processInfo.activeProcessorCount - 1),
    progress: ((Int) -> Void)? = nil,
    draw: @escaping (CGContext, Int) -> Void
  ) throws {
    let fm = FileManager.default
    // フォルダなどファイルでないものは消さずに止める (--out の指定の誤りで中身ごと消さないように)
    var isDir: ObjCBool = false
    if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue, !Safety.isSymlink(url) {
      throw AudioMix.err("\(url.path) はフォルダです (書き出す mp4 のファイルのパスを指定してください)")
    }
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    // 隣の一時ファイルに書き、書き終えてから名前を変える。中断 (Ctrl-C) しても、再生できない書きかけの動画が url に残らない。
    // url がシンボリックリンクでも、リンクの先には書かずにリンク自体を置き換える
    // 一時ファイルの名前にはプロセスの番号を入れる (同じ出力先へ同時に書き出しても、互いの書きかけを消さない)
    let dir = url.deletingLastPathComponent()
    let prefix = ".\(url.lastPathComponent).writing-"
    // 前に中断したときの残り (書いたプロセスがもう動いていないもの) を消す
    for f in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] where f.hasPrefix(prefix) && f.hasSuffix(".mp4") {
      let pid = Int32(f.dropFirst(prefix.count).dropLast(4)) ?? 0
      if pid == 0 || kill(pid, 0) != 0 && errno != EPERM { try? fm.removeItem(at: dir.appendingPathComponent(f)) }
    }
    let tmp = dir.appendingPathComponent("\(prefix)\(getpid()).mp4")
    try? fm.removeItem(at: tmp)
    let writer = try AVAssetWriter(outputURL: tmp, fileType: .mp4)
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
      ],
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: Int(Double(width * height) * fps * 0.08),
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoExpectedSourceFrameRateKey: fps,
        AVVideoMaxKeyFrameIntervalKey: Int(fps * 2),
      ],
    ]
    let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    vIn.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vIn, sourcePixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: width,
      kCVPixelBufferHeightKey as String: height,
    ])
    writer.add(vIn)

    var aIn: AVAssetWriterInput?
    if audio != nil {
      let a = AVAssetWriterInput(mediaType: .audio, outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: audioRate,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 192_000,
      ])
      a.expectsMediaDataInRealTime = false
      writer.add(a)
      aIn = a
    }

    guard writer.startWriting() else { throw writer.error ?? AudioMix.err("書き出しを始められません") }
    // 音声を書くキュー (直列)。audioStop.value はこのキューの上でだけ読み書きする
    let audioQueue = DispatchQueue(label: "jgv.audio")
    let audioStop = StopFlag()
    // 途中で失敗したら書き出しを取り消し、書きかけの mp4 を残さない (描くスレッドは fail() で止めてから抜ける)。
    // cancelWriting は append と同時に呼べないので、先に音声のキューで今の書き込みが終わるのを待ち、それ以降は書かせない
    var completed = false
    defer {
      if !completed {
        audioQueue.sync { audioStop.value = true }
        if writer.status == .writing { writer.cancelWriting() }
        try? FileManager.default.removeItem(at: tmp)
      }
    }
    writer.startSession(atSourceTime: .zero)
    guard let pool = adaptor.pixelBufferPool else { throw AudioMix.err("ピクセルバッファを用意できません") }

    // 音声は別のキューで、書けるときに書く
    let audioDone = DispatchSemaphore(value: 0)
    if let aIn, let audio {
      var pos = 0
      let chunk = 4096
      let format = audioFormat(rate: audioRate)
      aIn.requestMediaDataWhenReady(on: audioQueue) {
        while !audioStop.value && aIn.isReadyForMoreMediaData {
          if pos >= audio.count {
            aIn.markAsFinished()
            audioDone.signal()
            return
          }
          let n = min(chunk, audio.count - pos)
          if let sb = sampleBuffer(audio, from: pos, count: n, rate: audioRate, format: format), !aIn.append(sb) {
            // 書けなくなった (writer が失敗した) ときは、もう呼ばれないので待っている側を起こす
            audioDone.signal()
            return
          }
          pos += n
        }
      }
    } else {
      audioDone.signal()
    }

    // 映像: 並列に描いて、描き終わったものから順番に書く
    let lock = NSCondition()
    var ready: [Int: CVPixelBuffer] = [:]
    var nextToRender = 0
    var failure: Error?
    // 書き待ちのフレームの数。大きい画面でもメモリが 1 GB ほどに収まるように、1 フレームの大きさで上限を決める
    let frameBytes = max(1, width * height * 4)
    // (並列の数より小さくてもよい。描くスレッドは空くまで待つ)
    let window = max(1, min(parallel * 3, (1 << 30) / frameBytes))
    var written = 0

    let group = DispatchGroup()
    for _ in 0 ..< parallel {
      group.enter()
      // 既定のスタック (512 KB) は、入れ子の深い絵 (g { … } の重なり・SVG の素材) の再帰には小さいので、メインスレッドと同じ 8 MB にする
      let worker = Thread {
        defer { group.leave() }
        while true {
          lock.lock()
          while nextToRender < frames && nextToRender - written >= window && failure == nil { lock.wait() }
          if nextToRender >= frames || failure != nil { lock.unlock(); return }
          let k = nextToRender
          nextToRender += 1
          lock.unlock()
          var pb: CVPixelBuffer?
          CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
          guard let buffer = pb else {
            lock.lock(); failure = AudioMix.err("ピクセルバッファが足りません"); lock.broadcast(); lock.unlock()
            return
          }
          CVPixelBufferLockBaseAddress(buffer, [])
          let cg = Bitmap.context(width: width, height: height, data: CVPixelBufferGetBaseAddress(buffer), bytesPerRow: CVPixelBufferGetBytesPerRow(buffer))
          // プールのバッファには前のフレームが残っているので、消してから描く (背景が半透明・塗られないときに残像にならないように。静止画と同じ白紙から描く)
          cg.clear(CGRect(x: 0, y: 0, width: width, height: height))
          autoreleasepool { draw(cg, k) }
          CVPixelBufferUnlockBaseAddress(buffer, [])
          lock.lock()
          ready[k] = buffer
          lock.broadcast()
          lock.unlock()
        }
      }
      worker.stackSize = 8 << 20
      worker.start()
    }

    /// 書けなくなったとき: 描いているスレッドに知らせて止まるのを待ってから (待たせたままにしない)、そのエラーを返す
    func fail(_ e: Error) -> Error {
      lock.lock()
      if failure == nil { failure = e }
      lock.broadcast()
      lock.unlock()
      group.wait()
      return e
    }
    // fps が整数でなくても (29.97 など) フレームの時刻が音声とずれないように、1/1000 フレームの刻みで表す (30 fps なら timescale 30000)
    let timescale = CMTimeScale((fps * 1000).rounded())
    while written < frames {
      lock.lock()
      while ready[written] == nil && failure == nil { lock.wait() }
      if let failure { lock.unlock(); throw fail(failure) }
      let buffer = ready.removeValue(forKey: written)!
      lock.unlock()
      while !vIn.isReadyForMoreMediaData {
        if writer.status == .failed { throw fail(writer.error ?? AudioMix.err("フレーム \(written) を書けません")) }
        usleep(1000)
      }
      let time = CMTime(value: CMTimeValue(written) * 1000, timescale: timescale)
      if !adaptor.append(buffer, withPresentationTime: time) {
        throw fail(writer.error ?? AudioMix.err("フレーム \(written) を書けません"))
      }
      lock.lock()
      written += 1
      lock.broadcast()
      lock.unlock()
      progress?(written)
    }
    group.wait()
    vIn.markAsFinished()
    // 音声が書き終わるのを待つ (writer が失敗すると音声のブロックは呼ばれなくなるので、待ち続けない)
    while audioDone.wait(timeout: .now() + .milliseconds(200)) == .timedOut {
      if writer.status == .failed { throw writer.error ?? AudioMix.err("音声を書けません") }
    }
    if writer.status == .failed { throw writer.error ?? AudioMix.err("書き出しに失敗しました") }
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    if writer.status != .completed { throw writer.error ?? AudioMix.err("書き出しに失敗しました") }
    // 書き終えた: 前の動画 (またはリンク) を外して、一時ファイルを url にする
    // rename は前の動画 (またはリンク自体) を 1 回で置き換える (消してから移す間に、ほかの書き出しと取り合わない)
    guard rename(tmp.path, url.path) == 0 else { throw AudioMix.err("\(url.path) に書き出せません (\(String(cString: strerror(errno))))") }
    completed = true
  }

  static func audioFormat(rate: Double) -> CMAudioFormatDescription? {
    var asbd = AudioStreamBasicDescription(
      mSampleRate: rate, mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
      mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0
    )
    var fmt: CMAudioFormatDescription?
    CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &fmt)
    return fmt
  }

  /// モノラルの samples[from..<from+count] を 16 ビットのステレオにした CMSampleBuffer
  static func sampleBuffer(_ samples: [Float], from: Int, count: Int, rate: Double, format: CMAudioFormatDescription?) -> CMSampleBuffer? {
    guard let format else { return nil }
    var pcm = [Int16](repeating: 0, count: count * 2)
    // モノラルを左右に分ける (左右とも -3 dB。足した大きさがモノラルのときと同じになるように)
    for k in 0 ..< count {
      let v = Int16(max(-32768, min(32767, (samples[from + k] * 32767 * 0.70710678).rounded())))
      pcm[2 * k] = v
      pcm[2 * k + 1] = v
    }
    let bytes = count * 4
    var block: CMBlockBuffer?
    CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: bytes, blockAllocator: nil, customBlockSource: nil,
                                       offsetToData: 0, dataLength: bytes, flags: 0, blockBufferOut: &block)
    guard let block else { return nil }
    pcm.withUnsafeBytes { raw in
      _ = CMBlockBufferReplaceDataBytes(with: raw.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: bytes)
    }
    var sb: CMSampleBuffer?
    CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: count,
                                                         presentationTimeStamp: CMTime(value: CMTimeValue(from), timescale: CMTimeScale(rate)),
                                                         packetDescriptions: nil, sampleBufferOut: &sb)
    return sb
  }

  /// 動画の t 秒のフレームを取り出す (snapshots --video)
  public static func frame(of url: URL, at t: Double, maxWidth: Int) throws -> CGImage {
    let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    gen.requestedTimeToleranceBefore = .zero
    gen.requestedTimeToleranceAfter = .zero
    gen.maximumSize = CGSize(width: maxWidth, height: 10000)
    return try gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil)
  }
}

/// 音声のキューを止める印 (audioQueue の上でだけ読み書きするので、ロックは要らない)
final class StopFlag: @unchecked Sendable {
  var value = false
}
