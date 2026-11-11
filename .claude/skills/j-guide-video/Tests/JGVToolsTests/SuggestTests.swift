// 打ち間違えたサブコマンドに出す候補のテスト (swift test)
import Testing
@testable import JGVTools

struct SuggestTests {
  let names = ["new", "init", "dev", "check", "snapshots", "render", "still", "overview", "open", "voices"]

  @Test func distance() {
    #expect(Suggest.distance(Array("render"), Array("render")) == 0)
    #expect(Suggest.distance(Array("rendr"), Array("render")) == 1)
    #expect(Suggest.distance(Array("dve"), Array("dev")) == 2)
    #expect(Suggest.distance(Array(""), Array("dev")) == 3)
    #expect(Suggest.distance(Array("dev"), Array("")) == 3)
  }

  @Test func suggestsNearNames() {
    #expect(Suggest.closest("rendr", in: names) == "render")
    #expect(Suggest.closest("snapshot", in: names) == "snapshots")
    #expect(Suggest.closest("chek", in: names) == "check")
    #expect(Suggest.closest("dve", in: names) == "dev")
    #expect(Suggest.closest("RENDER", in: names) == "render")
  }

  @Test func suggestsByPrefix() {
    #expect(Suggest.closest("overv", in: names) == "overview")
    #expect(Suggest.closest("voi", in: names) == "voices")
  }

  @Test func noSuggestionForFarWords() {
    #expect(Suggest.closest("xyz", in: names) == nil)
    #expect(Suggest.closest("z", in: names) == nil)
    #expect(Suggest.closest("translate", in: names) == nil)
    #expect(Suggest.closest("rendr", in: []) == nil)
  }
}
