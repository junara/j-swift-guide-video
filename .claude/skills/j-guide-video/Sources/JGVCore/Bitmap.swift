// 描き先のビットマップと、静止画 (PNG / JPEG) の読み書き・一覧画像 (タイル) の作成
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum Bitmap {
  public static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
  /// BGRA (CVPixelBuffer の kCVPixelFormatType_32BGRA と同じ並び)
  public static let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

  public static func context(width: Int, height: Int, data: UnsafeMutableRawPointer? = nil, bytesPerRow: Int = 0) -> CGContext {
    // 縮小した静止画 (jgv check の 0.05 倍など) でも 0 にならないように 1 ピクセル以上にする
    let width = max(1, width), height = max(1, height)
    guard let cg = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                             space: colorSpace, bitmapInfo: bitmapInfo) else {
      fatalError("ビットマップを作れませんでした (\(width)x\(height))")
    }
    cg.setShouldAntialias(true)
    cg.setAllowsAntialiasing(true)
    cg.interpolationQuality = .high
    cg.setShouldSmoothFonts(false)
    return cg
  }

  /// y を下向き・倍率 scale (動画の座標 → ピクセル) にする
  public static func prepare(_ cg: CGContext, pixelHeight: Int, scale: Double) {
    cg.translateBy(x: 0, y: CGFloat(pixelHeight))
    cg.scaleBy(x: scale, y: -scale)
  }

  public static func writePNG(_ image: CGImage, to url: URL) throws {
    try write(image, to: url, type: UTType.png, quality: nil)
  }

  public static func writeJPEG(_ image: CGImage, to url: URL, quality: Double = 0.9) throws {
    try write(image, to: url, type: UTType.jpeg, quality: quality)
  }

  static func write(_ image: CGImage, to url: URL, type: UTType, quality: Double?) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
      throw JGVError("\(url.path) に書き出せません")
    }
    var props: [CFString: Any] = [:]
    if let quality { props[kCGImageDestinationLossyCompressionQuality] = quality }
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    if !CGImageDestinationFinalize(dest) {
      throw JGVError("\(url.path) の書き出しに失敗しました")
    }
  }

  public static func read(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
  }

  /// 静止画を cols 列に並べた一覧画像 (各コマは幅 cellW に縮める。コマの間は padding。nil のコマは白)
  public static func tile(_ images: [CGImage?], cols: Int, cellW: Int, padding: Int, background: RGBA = RGBA(1, 1, 1)) -> CGImage? {
    let cols = max(1, cols)
    guard let first = images.compactMap({ $0 }).first else { return nil }
    let w = min(cellW, first.width)
    let h = Int((Double(first.height) * Double(w) / Double(first.width)).rounded())
    let rows = Int((Double(images.count) / Double(max(1, cols))).rounded(.up))
    let W = cols * w + (cols - 1) * padding
    let H = rows * h + (rows - 1) * padding
    let cg = context(width: W, height: H)
    cg.setFillColor(background.cgColor)
    cg.fill(CGRect(x: 0, y: 0, width: W, height: H))
    for (k, img) in images.enumerated() {
      guard let img else { continue }
      let r = k / cols, c = k % cols
      let x = c * (w + padding)
      let y = H - r * (h + padding) - h
      cg.draw(img, in: CGRect(x: x, y: y, width: w, height: h))
    }
    return cg.makeImage()
  }

  /// 画像を横に並べる (gaps[i] は i 番目の画像の右の余白とその色)
  public static func hstack(_ images: [CGImage], height: Int, gaps: [(Int, RGBA)]) -> CGImage? {
    let sized = images.map { img -> (CGImage, Int) in (img, Int((Double(img.width) * Double(height) / Double(img.height)).rounded())) }
    let W = sized.enumerated().reduce(0) { $0 + $1.element.1 + ($1.offset < gaps.count ? gaps[$1.offset].0 : 0) }
    let cg = context(width: W, height: height)
    var x = 0
    for (k, item) in sized.enumerated() {
      cg.draw(item.0, in: CGRect(x: x, y: 0, width: item.1, height: height))
      x += item.1
      if k < gaps.count {
        cg.setFillColor(gaps[k].1.cgColor)
        cg.fill(CGRect(x: x, y: 0, width: gaps[k].0, height: height))
        x += gaps[k].0
      }
    }
    return cg.makeImage()
  }
}
