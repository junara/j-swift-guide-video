// 音声ファイルの読み書き (どの形式でも 48kHz モノラルの Float にして読む / 16 ビットの wav に書く)
import AVFoundation
import Foundation

public enum AudioFile {
  /// 1 つの音声ファイルの長さの上限 (動画の長さの上限と同じ 2 時間)
  public static let maxSeconds: Double = 2 * 3600

  /// ファイルを sampleRate のモノラル Float にして読む (wav / caf / aiff / mp3 / m4a など AVAudioFile が読める形式)
  public static func readMono(_ url: URL, sampleRate: Double = 48000) throws -> [Float] {
    // FIFO・デバイスなどは、開くと読み終わらずに止まったままになるので、ふつうのファイル (とそれを指すリンク) だけを読む
    var st = stat()
    guard stat(url.path, &st) == 0 else { throw JGVError("\(url.lastPathComponent) がありません") }
    guard st.st_mode & S_IFMT == S_IFREG else { throw JGVError("\(url.lastPathComponent) はふつうのファイルではありません") }
    let file = try AVAudioFile(forReading: url)
    let src = file.processingFormat
    guard file.length > 0 else { return [] }
    // 長さ・サンプルレートがおかしいファイル (1 Hz で数万フレームなど) は、変換後のバッファが数 GB になる・フレーム数が UInt32 に入らずに落ちるので、確保の前に止める
    let seconds = Double(file.length) / src.sampleRate
    guard src.sampleRate >= 1000, seconds.isFinite, seconds <= maxSeconds, let frames = AVAudioFrameCount(exactly: file.length) else {
      throw JGVError("\(url.lastPathComponent) の長さかサンプルレートが扱える範囲の外です (\(Int(src.sampleRate)) Hz・\(file.length) フレーム。1 つの音声は \(Int(maxSeconds / 3600)) 時間まで)")
    }
    guard let inBuf = AVAudioPCMBuffer(pcmFormat: src, frameCapacity: frames) else { throw JGVError("\(url.lastPathComponent) を読むメモリを確保できません") }
    // Float32 の PCM のファイル (apple の音声など) は、1 回の read が 1024 フレーム単位の端数を残して返ることがあるので、最後まで読み足す
    try file.read(into: inBuf)
    while inBuf.frameLength < inBuf.frameCapacity && file.framePosition < file.length {
      let before = inBuf.frameLength
      guard let rest = AVAudioPCMBuffer(pcmFormat: src, frameCapacity: inBuf.frameCapacity - before) else { break }
      try file.read(into: rest)
      if rest.frameLength == 0 { break }
      appendFrames(rest, to: inBuf)
    }
    let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
    var buf = inBuf
    if src.sampleRate != sampleRate || src.channelCount != 1 || src.commonFormat != .pcmFormatFloat32 || src.isInterleaved {
      guard let conv = AVAudioConverter(from: src, to: target) else {
        throw JGVError("\(url.lastPathComponent) の形式を変換できません")
      }
      // ステレオなどは左右を平均してモノラルにする
      if src.channelCount > 1 { conv.downmix = true }
      conv.sampleRateConverterQuality = AVAudioQuality.max.rawValue
      guard let cap = AVAudioFrameCount(exactly: (Double(inBuf.frameLength) * sampleRate / src.sampleRate + 4096).rounded(.down)),
            let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: cap) else {
        throw JGVError("\(url.lastPathComponent) を変換するメモリを確保できません")
      }
      var fed = false
      var error: NSError?
      let status = conv.convert(to: out, error: &error) { _, st in
        if fed { st.pointee = .endOfStream; return nil }
        fed = true
        st.pointee = .haveData
        return inBuf
      }
      // error を伴わない失敗も、黙って無音にせずエラーにする
      if status == .error { throw error ?? JGVError("\(url.lastPathComponent) の音声の変換に失敗しました") }
      buf = out
    }
    guard let ch = buf.floatChannelData else { return [] }
    return Array(UnsafeBufferPointer(start: ch[0], count: Int(buf.frameLength)))
  }

  /// src のフレームを dst の後ろに足す (形式は同じ。dst に入るところまで)
  private static func appendFrames(_ src: AVAudioPCMBuffer, to dst: AVAudioPCMBuffer) {
    let n = min(src.frameLength, dst.frameCapacity - dst.frameLength)
    let fmt = src.format
    let abl = UnsafeMutableAudioBufferListPointer(dst.mutableAudioBufferList)
    let sbl = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: src.audioBufferList))
    let bytesPerFrame = Int(fmt.streamDescription.pointee.mBytesPerFrame)
    for (d, s) in zip(abl, sbl) {
      guard let dp = d.mData, let sp = s.mData else { continue }
      memcpy(dp + Int(dst.frameLength) * bytesPerFrame, sp, Int(n) * bytesPerFrame)
    }
    dst.frameLength += n
    for i in 0..<abl.count { abl[i].mDataByteSize = UInt32(Int(dst.frameLength) * bytesPerFrame) }
  }

  /// モノラル 16 ビットの wav に書く
  public static func writeWav(_ samples: [Float], sampleRate: Int, to url: URL) throws {
    var d = Data()
    func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
    func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
    let bytes = samples.count * 2
    d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + bytes))
    d.append(contentsOf: Array("WAVE".utf8))
    d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1); u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
    d.append(contentsOf: Array("data".utf8)); u32(UInt32(bytes))
    var pcm = [Int16](repeating: 0, count: samples.count)
    for (k, v) in samples.enumerated() { pcm[k] = Int16(max(-32768, min(32767, (Double(v) * 32767).rounded()))) }
    pcm.withUnsafeBytes { d.append(contentsOf: $0) }
    // 一時ファイルに書いてから置き換える (書く先がシンボリックリンクでも、リンクの先を書き換えずにリンク自体を置き換える)
    try d.write(to: url, options: .atomic)
  }
}
