// timeline の 1 フレームをビットマップに描く
import CoreGraphics
import Foundation
import JGVCore
import JGVKit

public struct FrameRenderer {
  public let timeline: Timeline
  public let visuals: [String: VisualFn]

  public init(timeline: Timeline, visuals: [String: VisualFn]) {
    self.timeline = timeline
    self.visuals = visuals
  }

  public var config: VideoConfig {
    VideoConfig(fps: timeline.fps, width: timeline.width, height: timeline.height, durationInFrames: Double(timeline.durationInFrames))
  }

  /// cg (ピクセルの大きさ pixelW x pixelH) に frame を描く。scale は動画の座標 → ピクセルの倍率
  public func draw(into cg: CGContext, pixelHeight: Int, scale: Double, frame: Int) {
    cg.saveGState()
    defer { cg.restoreGState() }
    Bitmap.prepare(cg, pixelHeight: pixelHeight, scale: scale)
    let ctx = RenderContext(cg: cg, frame: Double(frame), config: config)
    ctx.run {
      NarratedVideo(timeline: timeline, visuals: visuals)
    }
  }

  /// frame を静止画にする (scale 倍の大きさ)
  public func image(frame: Int, scale: Double = 1) -> CGImage {
    let w = Int((timeline.width * scale).rounded())
    let h = Int((timeline.height * scale).rounded())
    let cg = Bitmap.context(width: w, height: h)
    draw(into: cg, pixelHeight: h, scale: scale, frame: frame)
    return cg.makeImage()!
  }
}

/// 任意の描画を静止画にする (道具の一覧など)
public func renderStill(width: Double, height: Double, scale: Double = 1, frame: Double = 0, fps: Double = 30, background: Paint = "#ffffff", _ body: () -> Void) -> CGImage {
  let w = Int((width * scale).rounded())
  let h = Int((height * scale).rounded())
  let cg = Bitmap.context(width: w, height: h)
  Bitmap.prepare(cg, pixelHeight: h, scale: scale)
  let ctx = RenderContext(cg: cg, frame: frame, config: VideoConfig(fps: fps, width: width, height: height, durationInFrames: 60))
  ctx.run {
    fillBackground(background)
    body()
  }
  return cg.makeImage()!
}
