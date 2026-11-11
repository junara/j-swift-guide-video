// 掃除機 (拡大): 表側にノズルを当てる → 3 段を順に吸い取り、ホコリが消えていく
import JGVKit

private let F = (x: 1080.0, y: 520.0, scale: 1.45)

func Vacuum(_ props: Props) {
  let n = useNarration()
  let from = n.at(1, 0.1)
  let to = n.endOf(1)
  let span = (to - from) / 3
  let rowY = { (r: Double) in F.y + (r - 1) * 100 }
  let sweep = { (r: Double) in interpolate(n.frame, [from + span * r, from + span * (r + 0.9)], [0, 1], .clamp) }
  let r = min(2, max(0, floor((n.frame - from) / span)))
  let s = sweep(r)
  let dir: Double = jsMod(r, 2) == 0 ? 1 : -1
  let xL = F.x - 190
  let xR = F.x + 190
  let sweepX = dir > 0 ? xL + (xR - xL) * s : xR - (xR - xL) * s
  let approach = n.ease(0, 0.2)
  let working = n.frame >= from && n.frame < to
  let nozzle = n.frame < from ? mix(Pt(1500, 420), Pt(xL, rowY(0)), approach) : n.frame >= to ? Pt(xR + 60, rowY(2) + 40) : Pt(sweepX, rowY(r))
  let grip = place(nozzle.x, nozzle.y, 0.9, 0, NOZZLE_PARTS.grip)
  let dust = [0.0, 1, 2].map { 1 - sweep($0) }
  Stage {
    Presenter(handR: mix(Pt(440, 680), POINT, n.ease(0, -0.3)))
    CloseUp(steps: [
      CloseUpStep("表側から掃除機をかける", at: n.at(0, -0.2)),
      CloseUpStep("ホコリを丁寧に吸い取る", at: n.at(1, -0.1)),
    ]) {
      Filter(x: F.x, y: F.y, scale: F.scale, dust: dust, label: true)
      // 吸い込まれるホコリ
      if working {
        for i in 0 ..< 8 {
          let k = jsMod(n.frame * 0.12 + random("v\(i)"), 1)
          let sx = nozzle.x + (random("vx\(i)") - 0.5) * 220
          let sy = nozzle.y + 50 + random("vy\(i)") * 40
          circle(cx: sx + (nozzle.x - sx) * k, cy: sy + (nozzle.y - sy) * k, r: 6 * (1 - k) + 2, fill: "#9b958a")
        }
      }
      VacuumNozzle(x: nozzle.x, y: nozzle.y, scale: 0.9, on: working)
      SleeveArm(from: Pt(1640, 300), to: grip, bend: 0.1)
    }
  }
}
