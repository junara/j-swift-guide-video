// 解説役の人物。手の位置 (画面座標) を渡すと、肩から手まで伸び縮みする「ゴム腕」を描く。
import Foundation

public struct PresenterPose {
  public var x: Double, y: Double
  /// 左手: エプロンの前
  public var restL: Pt
  /// 右手: 下ろした位置
  public var restR: Pt
  /// 右手: 道具を指し示す
  public var gestureR: Pt
}

/// 横型での人物の位置と手の定位置 (縦型にも対応する visual は useStage().pose を使う)
public let PRESENTER = PresenterPose(
  x: GUIDE.presenter.x, y: GUIDE.presenter.y,
  restL: Pt(GUIDE.presenter.x - 30, GUIDE.presenter.y - 105),
  restR: Pt(GUIDE.presenter.x + 60, GUIDE.presenter.y - 100),
  gestureR: Pt(GUIDE.presenter.x + 260, GUIDE.presenter.y - 265)
)

/// 肩 s から手 h へのゴム腕の曲線。近いほど大きく下にたわむ
private func armPath(_ s: Pt, _ h: Pt) -> String {
  let dx = h.x - s.x
  let dy = h.y - s.y
  let d = max(1, hypot(dx, dy))
  var nx = -dy / d
  var ny = dx / d
  if ny < 0 {
    nx = -nx
    ny = -ny
  }
  let sag = min(150, max(30, (380 - d) * 0.45))
  let c = Pt((s.x + h.x) / 2 + nx * sag * 2, (s.y + h.y) / 2 + ny * sag * 2)
  return "M \(s.x) \(s.y) Q \(c.x) \(c.y) \(h.x) \(h.y)"
}

private func Arm(shoulder: Pt, target: Pt) {
  let palette = useGuide().palette
  let d = armPath(shoulder, target)
  path(d, fill: Paint.none, stroke: palette.ink, strokeWidth: 50, strokeLinecap: .round)
  path(d, fill: Paint.none, stroke: palette.primary, strokeWidth: 39, strokeLinecap: .round)
  circle(cx: target.x, cy: target.y, r: 21, fill: palette.skin, stroke: palette.ink, strokeWidth: 5)
}

/// 見た目ごとの形 (人物のローカル座標。原点 = 足元の中心)
private struct PresenterShape {
  /// 胴体
  var body: String
  /// 頭の後ろに垂れる髪 (無ければ nil)
  var backHair: String?
  /// 頭の上の髪
  var hair: String
  /// 眉 (無ければ nil)
  var brows: String?
  /// 眉の太さ
  var browWidth: Double = 8
  /// 頬の赤みの濃さ (smile 0 のとき)
  var blush: Double
}

private func presenterShape(_ look: PresenterLook) -> PresenterShape {
  switch look {
  case .male:
    // 肩幅が広く、短髪で額を出す。眉を太く、シャツの襟
    return PresenterShape(
      body: "M -124 0 L -112 -226 Q 0 -282 112 -226 L 124 0 Z",
      hair: "M -86 -390 Q -100 -490 -8 -500 Q 90 -504 88 -392 Q 80 -440 46 -456 Q 0 -440 -50 -458 Q -80 -440 -86 -390 Z",
      brows: "M -44 -404 L -16 -407 M 20 -407 L 48 -404",
      blush: 0.15
    )
  case .female:
    // 流した前髪とポニーテール (結び目は Presenter で描く)、細い眉。肩はやや細め
    return PresenterShape(
      body: "M -112 0 L -96 -226 Q 0 -284 96 -226 L 112 0 Z",
      backHair: "M 64 -476 Q 156 -480 154 -380 Q 156 -300 116 -244 Q 132 -330 92 -404 Z",
      hair: "M -92 -360 Q -112 -500 -4 -508 Q 100 -510 94 -360 Q 88 -412 64 -432 Q 20 -424 -30 -456 Q -66 -424 -92 -360 Z",
      brows: "M -44 -408 Q -32 -414 -18 -410 M 22 -410 Q 36 -414 48 -408",
      browWidth: 5,
      blush: 0.3
    )
  case .neutral:
    // 耳にかかる短めの髪。眉なし (これまでの既定の人物)
    return PresenterShape(
      body: "M -118 0 L -100 -228 Q 0 -290 100 -228 L 118 0 Z",
      hair: "M -88 -378 Q -112 -488 -28 -500 Q 82 -526 94 -408 Q 30 -420 -22 -460 Q -40 -400 -88 -378 Z",
      blush: 0.3
    )
  }
}

/// 人物 (x, y は足元。既定は配置の presenter)。
/// smile: 笑顔の度合い (0〜1)。0.5 以上で目が「^ ^」になる。完成・成功の場面で easeAt などで上げる
/// look: 見た目 (.male 男性 / .female 女性 / .neutral 中性)。省略時は script.json の guide.presenter (既定 .neutral)
public func Presenter(handL: Pt? = nil, handR: Pt? = nil, x: Double? = nil, y: Double? = nil, smile: Double = 0, look: PresenterLook? = nil) {
  let stage = useStage()
  let x = x ?? stage.presenter.x
  let y = y ?? stage.presenter.y
  // 手の既定は「下ろした位置」。人物の位置 (x, y) を変えたときも、その人物の手元にする
  let dx = x - stage.presenter.x
  let dy = y - stage.presenter.y
  let handL = handL ?? Pt(stage.pose.restL.x + dx, stage.pose.restL.y + dy)
  let handR = handR ?? Pt(stage.pose.restR.x + dx, stage.pose.restR.y + dy)
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let scene = useContextValue(SceneInfo.self)
  let gd = useGuide()
  let palette = gd.palette
  let look = look ?? gd.presenter
  let shape = presenterShape(look)
  let t = frame / fps
  // シーン内なら読み上げ中は口が動く
  let speaking = scene?.lines.contains { frame >= $0.start && frame < $0.end } ?? false
  let blink = jsMod(frame, 110) < 4 ? 0.15 : 1
  let breath = sin(t * 2.2) * 2
  let mouthOpen = speaking ? 0.35 + 0.65 * abs(sin(t * 9.5)) : 0
  let sL = Pt(x - 100, y - 240 + breath)
  let sR = Pt(x + 100, y - 240 + breath)
  let ink = palette.ink
  g(strokeLinecap: .round, strokeLinejoin: .round) {
    g(stroke: ink, strokeWidth: 6, transform: [.translate(x, y + breath)]) {
      // 胴体とエプロン
      path(shape.body, fill: palette.primary)
      path("M -58 0 L -55 -222 L 52 -222 L 56 0 Z", fill: palette.apron)
      path("M -50 -224 Q 0 -178 48 -224", fill: Paint.none)
      if let back = shape.backHair { path(back, fill: palette.hair) }
      // 首と頭
      rect(x: -24, y: -318, width: 48, height: 64, rx: 20, fill: palette.skin)
      if look == .male {
        // シャツの襟
        path("M -26 -262 L -4 -226 L -30 -216 L -42 -246 Z", fill: palette.cream, strokeWidth: 5)
        path("M 26 -262 L 4 -226 L 30 -216 L 42 -246 Z", fill: palette.cream, strokeWidth: 5)
      }
      ellipse(cx: 0, cy: -385, rx: 88, ry: 104, fill: palette.skin)
      path(shape.hair, fill: palette.hair)
      if look == .female {
        // ポニーテールの結び目
        circle(cx: 84, cy: -464, r: 11, fill: palette.accent, strokeWidth: 4)
      }
      // 顔
      if let brows = shape.brows { path(brows, fill: Paint.none, strokeWidth: shape.browWidth) }
      if look == .female {
        // 少し縦長の目 (小さなハイライト)。笑うと「^ ^」
        if smile >= 0.5 {
          path("M -40 -370 Q -30 -383 -20 -370 M 24 -370 Q 34 -383 44 -370", fill: Paint.none, strokeWidth: 6)
        } else if blink < 1 {
          path("M -38 -374 L -22 -374 M 26 -374 L 42 -374", fill: Paint.none, strokeWidth: 5)
        } else {
          for ex in [-30.0, 34.0] {
            ellipse(cx: ex, cy: -374, rx: 6, ry: 8, fill: ink, stroke: Paint.none)
            circle(cx: ex + 2, cy: -377, r: 2, fill: "#ffffff", stroke: Paint.none)
          }
        }
        path("M 4 -362 L -1 -348 H 9", fill: Paint.none, strokeWidth: 3)
        if speaking {
          ellipse(cx: 4, cy: -324, rx: 13, ry: 3 + 8 * mouthOpen, fill: "#8a3b33", strokeWidth: 4)
        } else {
          path("M \(-11 - 5 * smile) \(-328 - 2 * smile) Q 4 \(-316 + 9 * smile) \(19 + 5 * smile) \(-328 - 2 * smile)", fill: Paint.none, strokeWidth: 4)
        }
        circle(cx: -48, cy: -338, r: 12, fill: palette.accent, stroke: Paint.none, opacity: shape.blush + 0.3 * smile)
        circle(cx: 56, cy: -338, r: 12, fill: palette.accent, stroke: Paint.none, opacity: shape.blush + 0.3 * smile)
      } else {
        if smile >= 0.5 {
          path("M -40 -370 Q -30 -384 -20 -370 M 23 -370 Q 33 -384 43 -370", fill: Paint.none, strokeWidth: 6)
        } else {
          path("M -30 -375 h 2 M 33 -375 h 2", strokeWidth: 10 * blink + 1)
        }
        path("M 4 -365 L -2 -348 H 10", fill: Paint.none, strokeWidth: 3)
        if speaking {
          ellipse(cx: 4, cy: -322, rx: 15, ry: 3 + 9 * mouthOpen, fill: "#8a3b33", strokeWidth: 4)
        } else {
          path("M \(-13 - 6 * smile) \(-326 - 2 * smile) Q 5 \(-312 + 10 * smile) \(22 + 6 * smile) \(-328 - 2 * smile)", fill: Paint.none, strokeWidth: 4)
        }
        circle(cx: -48, cy: -338, r: 12, fill: palette.accent, stroke: Paint.none, opacity: shape.blush + 0.3 * smile)
        circle(cx: 56, cy: -338, r: 12, fill: palette.accent, stroke: Paint.none, opacity: shape.blush + 0.3 * smile)
      }
    }
    Arm(shoulder: sL, target: handL)
    Arm(shoulder: sR, target: handR)
  }
}

/// 拡大カードの中などで、画面外 (from) から伸びる袖と手
public func SleeveArm(from: Pt, to: Pt, bend: Double = 0.25, width: Double = 40) {
  let palette = useGuide().palette
  let mx = (from.x + to.x) / 2
  let my = (from.y + to.y) / 2
  let nx = -(to.y - from.y) * bend
  let ny = (to.x - from.x) * bend
  let d = "M \(from.x) \(from.y) Q \(mx + nx) \(my + ny) \(to.x) \(to.y)"
  g(strokeLinecap: .round) {
    path(d, fill: Paint.none, stroke: palette.ink, strokeWidth: width + 11)
    path(d, fill: Paint.none, stroke: palette.primary, strokeWidth: width)
    circle(cx: to.x, cy: to.y, r: width * 0.55, fill: palette.skin, stroke: palette.ink, strokeWidth: 5)
  }
}
