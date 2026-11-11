// キュー (cues/*.cue) の読み取りの単体テスト (swift test)
import Testing
@testable import JGVKit

@Suite struct CueParseTests {
  @Test func readsTabsAsSeparators() {
    let p = parseCue("init\tmug@table\tlid=0\n0.0\tH>gesture~.5\n1.2\tsay\tmug.top\t熱いので注意\n")
    #expect(p.errors.isEmpty, "\(p.errors)")
    #expect(p.cues.count == 2)
    #expect(p.initNum["lid"] == 0)
  }

  @Test func numbersAreDecimalOnly() {
    let p = parseCue("init a=1e3 b=inf c=-.5 d=+.25 e=1.\n")
    #expect(p.initNum["c"] == -0.5)
    #expect(p.initNum["d"] == 0.25)
    #expect(p.initNum["e"] == 1)
    // 10 進でないものは文字の値
    #expect(p.initNum["a"] == nil && p.initStr["a"] == "1e3")
    #expect(p.initNum["b"] == nil && p.initStr["b"] == "inf")
  }

  @Test func countdownNeedsMinutesAndSeconds() {
    #expect(parseCue("0.0 t=cd 3:00 0:00@1.0\n").errors.isEmpty)
    #expect(!parseCue("0.0 t=cd 3 0@1.0\n").errors.isEmpty)
    #expect(!parseCue("0.0 t=cd 99999999999:00 0:00@1.0\n").errors.isEmpty)
  }

  @Test func rejectsNegativeAnchors() {
    #expect(parseAnchor("-1.0") == nil)
    #expect(parseAnchor("0.-1") == nil)
    #expect(parseAnchor("2.1+.3")?.line == 2)
    #expect(parseAnchor("end-1.05")?.line == nil)
  }

  @Test func readsInheritance() {
    #expect(parseCue("init <Prepare kettle@rest\n").inherit == "Prepare")
  }
}

@Suite struct CueBoundsTests {
  @Test func rejectsHugeOffsets() {
    // 大きなずらし秒は、時刻の計算が巨大になってメモリが尽きるので誤り
    #expect(parseAnchor("0.0-100000000") == nil)
    #expect(parseAnchor("0.0+1.5") != nil)
    #expect(!parseCue("0.0-100000000 say rest こんにちは\n").errors.isEmpty)
  }

  @Test func wavePeriodMustBePositive() {
    #expect(parseCue("0.0 a=wave 5 0.8@end\n").errors.isEmpty)
    #expect(!parseCue("0.0 a=wave 5 0@end\n").errors.isEmpty)
  }
}
