// 手順書 (Markdown) から読み上げる文を作るところのテスト (swift test)
import Foundation
import Testing
@testable import JGVCore
@testable import JGVTools

@Suite(.serialized) struct MD2ScriptTests {
  /// 手順書を台本にして、工程ごとの読み上げる文を返す
  func lines(_ md: String, lang: String) throws -> [[String]] {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("jgv-md-\(UUID().uuidString)")
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: dir) }
    try md.write(to: dir.appendingPathComponent("p.md"), atomically: true, encoding: .utf8)
    let cwd = fm.currentDirectoryPath
    fm.changeCurrentDirectoryPath(dir.path)
    defer { fm.changeCurrentDirectoryPath(cwd) }
    try MD2Script.run(["p.md", "-o", "s.json", "--lang", lang, "--no-library"])
    let j = try JSON.read(dir.appendingPathComponent("s.json"))
    return (j["scenes"]?.array ?? []).map { s in (s["lines"]?.array ?? []).compactMap { $0.string ?? $0["text"]?.string } }
  }

  @Test func keepsNumbersInsideParagraphs() throws {
    let l = try lines("# T\n\n## A [a]\n\nSet the oven to gas mark\n5.\nThen wait.\n", lang: "en-US")
    #expect(l[0].joined(separator: " ").contains("gas mark 5"))
  }

  @Test func dropsEmptyListItems() throws {
    let l = try lines("# T\n\n## A [a]\n\n1. First item\n2.\n3. **\n- \n", lang: "en-US")
    #expect(l[0] == ["First item."])
  }

  @Test func stripsTaskCheckboxes() throws {
    let l = try lines("# T\n\n## A [a]\n\n- [ ] Buy milk\n- [x] Pour it\n", lang: "en-US")
    #expect(l[0].allSatisfy { !$0.contains("[") })
  }

  @Test func keepsJapaneseAmounts() throws {
    let l = try lines("# T\n\n## A [a]\n\n砂糖を大さじ、\n2. 加える。\n", lang: "ja-JP")
    #expect(l[0] == ["砂糖を大さじ、2加える。"])
  }

  @Test func breakTagBecomesSpace() throws {
    let l = try lines("# T\n\n## A [a]\n\nLine one<br>line two.\n", lang: "en-US")
    #expect(l[0].joined(separator: " ").contains("one line"))
  }

  @Test func itemsAfterContinuationLinesStayItems() throws {
    // 字下げした続きの行
    var l = try lines("# T\n\n## A [a]\n\n1. 卵を割る\n   殻が入らないように注意する\n2. よく混ぜる\n", lang: "ja-JP")
    #expect(!l[0].joined().contains("2."))
    // 英語の続きの行
    l = try lines("# T\n\n## A [a]\n\n1. Remove the screw.\n   It may be stiff.\n3. Lift the handle.\n", lang: "en-US")
    #expect(!l[0].contains("3."))
    #expect(l[0].last == "Lift the handle.")
    // 項目の中の段落 (空行の後の字下げ)
    l = try lines("# T\n\n## A [a]\n\n1. a\n\n   note\n2. b\n", lang: "en-US")
    #expect(!l[0].joined(separator: " ").contains("2."))
    // 字下げしない遅延継続
    l = try lines("# T\n\n## A [a]\n\n1. フライパンを温める\nバターを入れる\n2. 卵を流し入れる\n", lang: "ja-JP")
    #expect(!l[0].joined().contains("2."))
  }

  @Test func numberedListAfterSentenceStaysList() throws {
    var l = try lines("# T\n\n## A [a]\n\n中火にします。\n3. 油をひく\n4. 野菜を炒める\n", lang: "ja-JP")
    #expect(l[0] == ["中火にします。", "油をひく。", "野菜を炒める。"])
    l = try lines("# T\n\n## A [a]\n\n1. 鍋に湯を沸かす\n2. 麺を入れる\n\n注意：吹きこぼれに注意する。\n3. 火を弱める\n4. ざるにあげる\n", lang: "ja-JP")
    #expect(!l[0].joined().contains("3.") && !l[0].joined().contains("4."))
    l = try lines("# T\n\n## A [a]\n\nNext, clean the filter.\n3. Pull out the filter.\n4. Rinse it.\n", lang: "en-US")
    #expect(l[0] == ["Next, clean the filter.", "Pull out the filter.", "Rinse it."])
    l = try lines("# T\n\n## A [a]\n\nContinue with:\n4. Wait 30 seconds.\n5. Pour the rest.\n", lang: "en-US")
    #expect(!l[0].contains("4.") && !l[0].contains("5.") && l[0].contains("Wait 30 seconds."))
  }

  @Test func numberedListAfterUnpunctuatedLineStaysList() throws {
    var l = try lines("# T\n\n## A [a]\n\nOpen Settings\n2. Tap Wi-Fi\n3. Choose your network\n", lang: "en-US")
    #expect(l[0] == ["Open Settings.", "Tap Wi-Fi.", "Choose your network."])
    l = try lines("# T\n\n## A [a]\n\n鍋に水を入れる\n2. 火にかける\n3. だしを入れる\n", lang: "ja-JP")
    #expect(!l[0].joined().contains("2.") && !l[0].joined().contains("3."))
    l = try lines("# T\n\n## A [a]\n\nPreheat the oven to 180 C\n2. Grease the tin.\n", lang: "en-US")
    #expect(l[0] == ["Preheat the oven to 180 C.", "Grease the tin."])
    l = try lines("# T\n\n## A [a]\n\nSay \"ready.\"\n2. Press start.\n", lang: "en-US")
    #expect(!l[0].contains("2."))
  }

  @Test func listsAfterIntroLinesStayLists() throws {
    var l = try lines("# T\n\n## A [a]\n\nYou need:\n1. 2 eggs\n2. 100 g sugar\n", lang: "en-US")
    #expect(l[0].count == 3 && l[0][1] == "2 eggs.")
    l = try lines("# T\n\n## A [a]\n\nTo install the CLI:\n1. download the archive\n2. unzip it\n", lang: "en-US")
    #expect(l[0].count == 3)
    l = try lines("# T\n\n## A [a]\n\nBefore you start, read this.\n2. make sure the power is off.\n", lang: "en-US")
    #expect(l[0].last == "make sure the power is off.")
    l = try lines("# T\n\n## A [a]\n\n準備ができたら、\n1. 電源を入れます。\n", lang: "ja-JP")
    #expect(!l[0].joined().contains("1電源"))
  }

  @Test func listsContinueAcrossNotes() throws {
    var l = try lines("# T\n\n## A [a]\n\n1. open the app\n2. go to settings\n\nNote: you may need admin rights\n3. tap reset\n4. confirm\n", lang: "en-US")
    #expect(l[0].suffix(2) == ["tap reset.", "confirm."])
    l = try lines("# T\n\n## A [a]\n\nOpen the menu\n2) tap Settings\n3) tap Wi-Fi\n", lang: "en-US")
    #expect(l[0] == ["Open the menu.", "tap Settings.", "tap Wi-Fi."])
    l = try lines("# T\n\n## A [a]\n\n1. 鍋を温める\n\n※火に注意、\n2. 油をひく\n", lang: "ja-JP")
    #expect(!l[0].joined().contains("2油"))
  }

  @Test func keepsKeyNamesAndPlaceholders() throws {
    // <Enter> <URL> のような山かっこは HTML のタグではないので消さない (インラインコードの中も)
    let l = try lines("# T\n\n## A [a]\n\nPress `<Enter>` to confirm.\n\nType `git clone <URL>` and press <Tab>.\n\nIf a<b and c>d then stop.\n", lang: "en-US")
    let all = l[0].joined(separator: " ")
    #expect(all.contains("<Enter>"))
    #expect(all.contains("git clone <URL>"))
    #expect(all.contains("<Tab>"))
    #expect(all.contains("a<b and c>d"))
  }

  @Test func stripsKnownHtmlTags() throws {
    let l = try lines("# T\n\n## A [a]\n\nPress <kbd>Enter</kbd> and <b>wait</b>.<img src=\"x.png\"> <a href=\"https://example.com\">Open</a> it.\n", lang: "en-US")
    let all = l[0].joined(separator: " ")
    #expect(!all.contains("<"))
    #expect(all.contains("Press Enter and wait"))
    #expect(all.contains("Open it"))
  }

  @Test func inlineCodeKeepsItsContents() throws {
    // インラインコードの中の * や _ は、斜体・太字として消さない
    let l = try lines("# T\n\n## A [a]\n\nRun `a*b*c` and `__init__`.\n", lang: "en-US")
    #expect(l[0].joined(separator: " ").contains("a*b*c"))
    #expect(l[0].joined(separator: " ").contains("__init__"))
  }

  @Test func inlineCodeAtLineStartIsNotAFence() throws {
    // 行頭の ```x``` はインラインコード。コードブロックの開始とみなすと、以降の工程がすべて消える
    let l = try lines("# T\n\n## A [a]\n\nFirst.\n\n## B [b]\n\n```brew install foo``` を実行します。\n\n## C [c]\n\nThird.\n\n## D [d]\n\nFourth.\n", lang: "en-US")
    #expect(l.count == 4)
    #expect(l[3] == ["Fourth."])
  }

  @Test func fencedCodeIsNotRead() throws {
    let l = try lines("# T\n\n## A [a]\n\nBefore.\n\n```sh\n## not a heading\necho hi\n```\n\nAfter.\n\n~~~\nsecret\n~~~\n", lang: "en-US")
    #expect(l.count == 1)
    #expect(l[0] == ["Before.", "After."])
  }

  @Test func multiLineCommentsAreNotRead() throws {
    let l = try lines("# T\n\n## A [a]\n\nBefore.\n\n<!--\nTODO: do not read this\n## hidden [x]\n-->\n\nAfter. <!-- inline --> Done.\n", lang: "en-US")
    #expect(l.count == 1)
    #expect(!l[0].joined(separator: " ").contains("TODO"))
    #expect(!l[0].joined(separator: " ").contains("inline"))
    #expect(l[0].first == "Before.")
    #expect(l[0].contains("Done."))
  }

  @Test func fenceTracksItsOwnMarker() {
    var f = Fence()
    let opened = f.feed("```swift")
    #expect(opened && f.isOpen)
    let tilde = f.feed("~~~") // ``` の中の ~~~ は中身
    #expect(!tilde && f.isOpen)
    let closed = f.feed("```")
    #expect(closed && !f.isOpen)
    let inline = f.feed("```x``` is inline")
    let short = f.feed("``not a fence")
    #expect(!inline && !short && !f.isOpen)
  }
}
