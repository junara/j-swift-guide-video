// 日本語の台本の読み方を確かめる (jgv yomi)。
// usage: jgv yomi [--warn-only] [script.json]   (jgv tts の最後にも --warn-only で走る)
//   --warn-only  読みの一覧を出さず、2〜4 の警告だけを出す
//
// 1. 各行の speak (無ければ text) のうち、漢字を含む語とその読みを並べる (macOS の形態素解析による目安)。
//    額(がく)・便(びん) のように意図と違う読みがあれば、speak をカタカナの読みに直す
// 2. speak で漢字をひらがなの読みに置き換えた所の前後がひらがなだと、つながって区切りを誤ることがある
//    (「食欲やはいせつぶつ」が「や/は/いせつ…」と読まれる)。形態素解析でその読みが 1 語にまとまらない
//    (はいせつ/ぶつ、じゅう/いし) ときだけ警告する。「すべりにくい」のように送り仮名が続くだけで、
//    読みが 1 語 (すべり) の中に収まるときは警告しない。カタカナ (ハイセツブツ) に直す
// 3. 漢数字と助数詞 (一本・一回・八分・三本 など) は、形態素解析が別の語に分け、読みも 1 字ずつ
//    (一(いち) 本(ぽん)) になる。続けると音が変わる組み合わせ (いっぽん・はっぷん・さんぼん) は、読み上げでも
//    誤ることがあるので警告する。カタカナ (イッポン) に直す。音が変わらない数 (二杯・四本) でも、解析が助数詞を濁らせて
//    読んでいる (二(に) 杯(ばい)) ときは警告する。表に無い助数詞は対象にしない
// 4. 1 字の漢字が、前後とつながらない読みになっている所を警告する: 熟語の中だけの読み (画面下 → 下(か)、
//    時刻の文の 時と分 → 分(ぶん)) と、1 字なのに連濁した読み (この箱を → 箱(ばこ))
// Node 版 (scripts/yomi.mjs + scripts/yomi.swift) の移植。形態素解析 (CFStringTokenizer) はこのプロセスの中で行う
import CoreFoundation
import Foundation
import JGVCore

public enum Yomi {
  public static let usage = "usage: jgv yomi [--warn-only] [script.json]"

  public static func run(_ args: [String]) throws {
    let warnOnly = args.contains("--warn-only")
    let file = args.first { !$0.hasPrefix("--") } ?? "script.json"
    try check(file: file, warnOnly: warnOnly)
  }

  /// jgv tts の最後に呼ぶ (= --warn-only)。失敗しても投げずに、エラーを表示するだけ
  public static func warn(scriptURL: URL) {
    do {
      try check(file: scriptURL.path, warnOnly: true)
    } catch {
      JSCompat.warn(userMessage(error))
    }
  }

  /// 文を macOS の形態素解析 (CFStringTokenizer) で語に分け、語ごとの読み (ひらがな) を返す。
  /// 読み上げ (AVSpeechSynthesizer) の読みと完全に同じとは限らないが、誤読しやすい語 (額 → がく、便 → びん) を見つける目安になる
  public static func tokenize(_ line: String) -> [(word: String, reading: String)] {
    let text = line as NSString
    var words: [(String, String)] = []
    guard let tok = CFStringTokenizerCreate(nil, text as CFString, CFRangeMake(0, text.length), kCFStringTokenizerUnitWordBoundary, Locale(identifier: "ja_JP") as CFLocale) else { return [] }
    while CFStringTokenizerAdvanceToNextToken(tok).rawValue != 0 {
      let r = CFStringTokenizerGetCurrentTokenRange(tok)
      let w = text.substring(with: NSRange(location: r.location, length: r.length))
      var reading = ""
      if let latin = CFStringTokenizerCopyCurrentTokenAttribute(tok, kCFStringTokenizerAttributeLatinTranscription) as? String {
        let m = NSMutableString(string: latin)
        CFStringTransform(m, nil, kCFStringTransformLatinHiragana, false)
        reading = m as String
      }
      words.append((w, reading))
    }
    return words
  }

  struct Row {
    var key: String
    var text: String
    var speak: String
  }

  static let han = JSRegex("[\\p{Script=Han}々]")
  static let hira = JSRegex("^[\\p{Script=Hiragana}ー]\\z")
  // 警告だけのとき、読みを書き換えた行も、漢数字の後に漢字が続く所 (3. の候補。一緒・十分 なども含む) も無ければ解析しない
  static let numCounter = JSRegex("[一二三四五六七八九十百千万何][\\p{Script=Han}かカヶヵ]")
  // 4. の候補: 下・上・分・前 と、連濁しやすい字 (RENDAKU)
  static let loneKanji = JSRegex("[下上分前箱紙袋皿棚蓋型粉箸]")

  static func check(file: String, warnOnly: Bool) throws {
    let log = JSCompat.log
    let script: JSON
    do {
      script = try JSON.read(URL(fileURLWithPath: file))
    } catch let e as JSON.ParseError {
      throw ToolError("yomi: \(e.message)")
    } catch {
      throw ToolError("yomi: \(file) が読めません: \(error.localizedDescription)")
    }
    let lang = JSCompat.coalesce(script["lang"], nil)?.string ?? "ja-JP"
    if !lang.hasPrefix("ja") {
      if !warnOnly { log("yomi: \(file) は \(lang) なので確かめません (日本語の台本だけ)") }
      return
    }

    var rows: [Row] = []
    for (si, sc) in (script["scenes"]?.array ?? []).enumerated() {
      for (li, raw) in (sc["lines"]?.array ?? []).enumerated() {
        let text: String, speak: String
        if case let .string(s) = raw {
          text = s
          speak = s
        } else {
          text = JSCompat.coalesce(raw["text"], nil)?.string ?? ""
          speak = (JSCompat.coalesce(raw["speak"], JSCompat.coalesce(raw["text"], nil))?.string ?? "")
        }
        rows.append(Row(key: "\(si)-\(li)", text: text, speak: speak.replacingOccurrences(of: "\n", with: " ")))
      }
    }

    if warnOnly && rows.allSatisfy({ JSCompat.same($0.text, $0.speak) && !numCounter.test($0.speak) && !loneKanji.test($0.speak) }) { return }

    // 1. 漢字を含む語の読み
    let tokens: [[(word: String, reading: String)]] = rows.map { tokenize($0.speak) }
    if !warnOnly {
      log("読み (漢字を含む語。macOS の形態素解析による目安。意図と違う読みは speak をカタカナで書き直す):")
      for (i, r) in rows.enumerated() {
        let words = tokens[i].filter { han.test($0.word) }.map { $0.reading.isEmpty ? $0.word : "\($0.word)(\($0.reading))" }
        if !words.isEmpty { log("  \(JSCompat.padEnd(r.key, 5)) \(words.joined(separator: " "))") }
      }
    }

    let warns = hiraganaWarns(rows, tokens)
    let counterWarns = counterWarnings(rows, tokens)
    let loneWarns = loneWarnings(rows, tokens)
    if !warns.isEmpty {
      log("\(warnOnly ? "" : "\n")WARN: ひらがなの読みが前後のひらがなとつながり、区切りを誤ることがあります。カタカナで書いてください (例: はいせつぶつ → ハイセツブツ):")
      for w in warns { log(w) }
    }
    if !counterWarns.isEmpty {
      log("\(warnOnly && warns.isEmpty ? "" : "\n")WARN: 漢数字と助数詞が別の語に分かれ、続けた読みと違う音で読まれることがあります。正しい読みをカタカナで speak に書いてください (一本 → イッポン、二杯 → ニハイ。例の読みは目安):")
      for w in counterWarns { log(w) }
    }
    if !loneWarns.isEmpty {
      log("\(warnOnly && warns.isEmpty && counterWarns.isEmpty ? "" : "\n")WARN: 1 字の漢字が、前後とつながらない読みになっています。意図と違えば、前後の語ごとカタカナで speak に書いてください (例: 画面下 → ガメンシタ。管理下 (かんりか) のように正しいこともある):")
      for w in loneWarns { log(w) }
    }
  }

  /// コードポイントごとの文字列
  static func chars(_ s: String) -> [String] { s.unicodeScalars.map { String($0) } }

  // 語ごとの範囲 (speak の文字 (コードポイント) の位置) [[開始, 終了), …]
  static func spansOf(_ speak: String, _ words: [(word: String, reading: String)]) -> [(Int, Int)] {
    let s = Array(speak.utf16)
    var out: [(Int, Int)] = []
    var at = 0
    for (w, _) in words {
      let wu = Array(w.utf16)
      let idx = JSCompat.indexOf(s, wu, at)
      if idx < 0 { continue }
      let from = JSCompat.utf16String(s[0 ..< idx]).unicodeScalars.count
      out.append((from, from + w.unicodeScalars.count))
      at = idx + wu.count
    }
    return out
  }

  // 2. ひらがなの読みが前後のひらがなとつながっている所
  // text と speak の文字単位の差分 (LCS) から、置き換えた所を取り出す
  static func hunks(_ a: [Unicode.Scalar], _ b: [Unicode.Scalar]) -> [(from: String, to: String, at: Int)] {
    let n = a.count, m = b.count
    var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
    if n > 0 && m > 0 {
      for i in stride(from: n - 1, through: 0, by: -1) {
        for j in stride(from: m - 1, through: 0, by: -1) {
          dp[i][j] = a[i] == b[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
        }
      }
    }
    var res: [(from: String, to: String, at: Int)] = []
    var i = 0, j = 0
    var cur: (from: String, to: String, at: Int)? = nil
    func flush() {
      if let c = cur { res.append(c) }
      cur = nil
    }
    while i < n || j < m {
      if i < n && j < m && a[i] == b[j] {
        flush()
        i += 1
        j += 1
      } else {
        if cur == nil { cur = (from: "", to: "", at: j) }
        if j < m && (i >= n || dp[i][j + 1] >= dp[i + 1][j]) {
          cur!.to.unicodeScalars.append(b[j])
          j += 1
        } else {
          cur!.from.unicodeScalars.append(a[i])
          i += 1
        }
      }
    }
    flush()
    return res
  }

  static func hiraganaWarns(_ rows: [Row], _ tokens: [[(word: String, reading: String)]]) -> [String] {
    var warns: [String] = []
    for (i, r) in rows.enumerated() {
      if JSCompat.same(r.text, r.speak) { continue }
      let s = chars(r.speak)
      let spans = spansOf(r.speak, tokens[i])
      for h in hunks(Array(r.text.unicodeScalars), Array(r.speak.unicodeScalars)) {
        if !han.test(h.from) || h.to.isEmpty || !chars(h.to).allSatisfy({ hira.test($0) }) { continue }
        let end = h.at + chars(h.to).count
        let before = h.at - 1 >= 0 && h.at - 1 < s.count ? s[h.at - 1] : ""
        let after = end < s.count ? s[end] : ""
        if !hira.test(before) && !hira.test(after) { continue }
        // 読みが 1 語の中に収まっていれば、区切りは正しく取れている (すべり|にくい)
        if spans.contains(where: { $0.0 <= h.at && end <= $0.1 }) { continue }
        let split = spans.filter { $0.0 < end && h.at < $0.1 }.map { s[min($0.0, s.count) ..< min($0.1, s.count)].joined() }.joined(separator: "/")
        warns.append("  \(JSCompat.padEnd(r.key, 5)) 「\(h.from)」→「\(h.to)」が \(split.isEmpty ? "前後のひらがなとつながっています" : "\(split) と区切られています"): \(r.speak)")
      }
    }
    return warns
  }

  // 3. 漢数字と助数詞の続けた読み (読みの例は目安)。音が変わらない数は「数の読み + 助数詞のもとの読み」
  //    促音: 一・八・十 + か・さ・た・は行 (いっぽん・はっさい・じゅっかい)、六・百 + か・は行 (ろっぽん・ひゃっかい)
  //    撥音: 三・千・万・何 + 本・杯・分・階 など (さんぼん・さんぷん・さんがい)。濁り方は語ごとに違うので表で持つ
  //    数が 2 字以上の語 (二十・三千) は、読みの終わり (じゅう・ぜん) で決める。
  //    袋 (ひとふくろ)・束・晩・倍 のように音が変わらない語や和語の助数詞を拾わないよう、漢語の助数詞だけを表で持つ
  //    { 助数詞: [読み, 撥音の後の読み (変わるときだけ)] }
  static let counters: [String: [String]] = [
    "本": ["ほん", "ぼん"], "杯": ["はい", "ばい"], "匹": ["ひき", "びき"], "分": ["ふん", "ぷん"], "歩": ["ほ", "ぽ"], "泊": ["はく", "ぱく"],
    "発": ["はつ", "ぱつ"], "品": ["ひん", "ぴん"], "敗": ["はい", "ぱい"], "階": ["かい", "がい"], "軒": ["けん", "げん"],
    "回": ["かい"], "個": ["こ"], "冊": ["さつ"], "頭": ["とう"], "歳": ["さい"], "才": ["さい"], "足": ["そく", "ぞく"], "着": ["ちゃく"], "通": ["つう"],
    "点": ["てん"], "件": ["けん"], "曲": ["きょく"], "缶": ["かん"], "巻": ["かん"], "周": ["しゅう"], "週": ["しゅう"], "週間": ["しゅうかん"],
    "箇所": ["かしょ"], "か所": ["かしょ"], "カ所": ["かしょ"], "ヶ所": ["かしょ"], "ヵ所": ["かしょ"], "滴": ["てき"], "錠": ["じょう"], "席": ["せき"], "層": ["そう"],
  ]
  static let sokuon: [(String, String, String)] = [
    ("いち", "いっ", "かさたは"),
    ("はち", "はっ", "かさたは"),
    ("じゅう", "じゅっ", "かさたは"),
    ("ろく", "ろっ", "かは"),
    ("ひゃく", "ひゃっ", "かは"),
    ("びゃく", "びゃっ", "かは"),
    ("ぴゃく", "ぴゃっ", "かは"),
  ]
  static func rowOf(_ c: String) -> String? {
    ["かきくけこ", "さしすせそ", "たちつてと", "はひふへほ"].first { $0.unicodeScalars.contains { String($0) == c } }.map { String($0.unicodeScalars.first!) }
  }
  static let nasal = ["さん", "せん", "ぜん", "まん", "なん"]
  static func isKansuji(_ w: String) -> Bool { !w.isEmpty && w.unicodeScalars.allSatisfy { "〇一二三四五六七八九十百千万".unicodeScalars.contains($0) } }
  static func isNumber(_ w: String) -> Bool { isKansuji(w) || w == "何" }
  static func endsWith(_ s: String, _ e: String) -> Bool { s.utf16.count >= e.utf16.count && Array(s.utf16).suffix(e.utf16.count).elementsEqual(e.utf16) }

  static func joinedOf(numY: String, cntW: String, cntY: String) -> String? {
    guard let entry = counters[cntW] else { return nil }
    let base = entry[0]
    let afterN: String? = entry.count > 1 ? entry[1] : nil
    let bs = chars(base)
    let baseHead = bs[0]
    let baseRest = bs.dropFirst().joined()
    // 解析の読みが表の語の読みのどれとも違えば、別の意味の語 (三分の一 の 分(ぶん)) なので対象にしない
    let pIndex = chars("はひふへほ").firstIndex(of: baseHead)
    let pHead: String? = pIndex.map { chars("ぱぴぷぺぽ")[$0] }
    let candidates = [base, afterN, pHead.map { $0 + baseRest }].compactMap { $0 }
    if !candidates.contains(where: { JSCompat.same($0, cntY) }) { return nil }
    // 続けたときの正しい読み。音が変わらない組み合わせ (二杯・四本) は、数の読み + 助数詞のもとの読み
    var expected = numY + base
    let sok = sokuon.first { endsWith(numY, $0.0) }
    let row = rowOf(baseHead)
    if let sok, let row, sok.2.contains(row) {
      let ny = Array(numY.utf16)
      let stem = JSCompat.utf16String(ny[0 ..< ny.count - sok.0.utf16.count])
      expected = stem + sok.1 + (row == "は" ? (pHead ?? "") : baseHead) + baseRest
    } else if let afterN, nasal.contains(where: { endsWith(numY, $0) }) {
      expected = numY + afterN
    } else if cntW == "分" && endsWith(numY, "よん") {
      expected = numY + "ぷん" // 四分 (よんぷん)
    }
    // 解析の読みをそのままつないだものと違えば警告する (一(いち) 本(ぽん) → いっぽん、二(に) 杯(ばい) → にはい)
    return JSCompat.same(expected, numY + cntY) ? nil : expected
  }

  static func toKata(_ s: String) -> String {
    var out = String.UnicodeScalarView()
    for u in s.unicodeScalars {
      if u.value >= 0x3041 && u.value <= 0x3096, let k = Unicode.Scalar(u.value + 0x60) { out.append(k) } else { out.append(u) }
    }
    return String(out)
  }

  static func counterWarnings(_ rows: [Row], _ tokens: [[(word: String, reading: String)]]) -> [String] {
    var counterWarns: [String] = []
    for (i, r) in rows.enumerated() {
      // 語と speak の中の位置 (隣り合っているかを見る。UTF-16 の位置)
      let su = Array(r.speak.utf16)
      var ws: [(w: String, y: String, from: Int, to: Int)] = []
      var at = 0
      for (w, y) in tokens[i] {
        let wu = Array(w.utf16)
        let idx = JSCompat.indexOf(su, wu, at)
        if idx < 0 { continue }
        // 続けて分かれた漢数字 (十 一) は 1 つの数にする (十一本 → じゅういち + ぽん)
        if let prev = ws.last, prev.to == idx, isKansuji(prev.w), isKansuji(w) {
          ws[ws.count - 1] = (w: prev.w + w, y: prev.y + y, from: prev.from, to: idx + wu.count)
        } else {
          ws.append((w: w, y: y, from: idx, to: idx + wu.count))
        }
        at = idx + wu.count
      }
      var k = 0
      while k + 1 < ws.count {
        defer { k += 1 }
        let num = ws[k]
        let cnt = ws[k + 1]
        if num.to != cnt.from || !isNumber(num.w) || num.y.isEmpty { continue }
        // 十分に・十分な (じゅうぶん) は時間ではない。文の始めの「十分に」は 十(じゅう) 分(ふん) と分かれる
        // (十分で・十分だけ は時間のことが多いので警告する)
        if num.w == "十" && cnt.w == "分", cnt.to < su.count, su[cnt.to] == 0x306B || su[cnt.to] == 0x306A { continue }
        if let joined = joinedOf(numY: num.y, cntW: cnt.w, cntY: cnt.y) {
          counterWarns.append("  \(JSCompat.padEnd(r.key, 5)) 「\(num.w)\(cnt.w)」が \(num.w)(\(num.y)) \(cnt.w)(\(cnt.y)) と分かれています (続けた読みの例: \(toKata(joined))): \(r.speak)")
        }
      }
    }
    return counterWarns
  }

  // 4. 1 字の漢字の読み
  //    熟語の中だけの読み: 下(か・げ)・上(じょう)・前(ぜん)。上(じょう) は漢字の後 (画面上・設定上) なら正しいので除く。
  //    分(ぶん) は「その分」「2人分」のように正しいことが多いので、時刻の文 (7時・30秒・時と分) で数の後でないときだけ
  //    連濁: 1 字で使うときは濁らない字 (箱 は はこ。この箱を → 箱(ばこ) は誤り)
  static let lone: [String: [String]] = ["下": ["か", "げ"], "上": ["じょう"], "前": ["ぜん"]]
  static let rendaku: [String: String] = ["箱": "ばこ", "紙": "がみ", "袋": "ぶくろ", "皿": "ざら", "棚": "だな", "蓋": "ぶた", "型": "がた", "粉": "ごな", "箸": "ばし"]
  static let singleHan = JSRegex("^\\p{Script=Han}\\z")
  static let endsKanji = JSRegex("[\\p{Script=Han}〇0-9０-９]\\z")
  static let endsKana = JSRegex("[\\p{Script=Katakana}ーA-Za-zＡ-Ｚａ-ｚ]\\z")
  static let timeContext = JSRegex("[0-9０-９〇二三四五六七八九十]時(?!間)|秒|時と分")

  static func loneWarnings(_ rows: [Row], _ tokens: [[(word: String, reading: String)]]) -> [String] {
    var loneWarns: [String] = []
    for (i, r) in rows.enumerated() {
      let words = tokens[i]
      for (k, t) in words.enumerated() {
        let (w, y) = t
        if !singleHan.test(w) || y.isEmpty { continue }
        let prev = k > 0 ? words[k - 1].word : ""
        let afterKanji = endsKanji.test(prev)
        // 連濁は前の語とつながっていれば正しい (ハート型・段ボール箱。カタカナ語は解析で別の語に分かれる)
        let joined = afterKanji || endsKana.test(prev)
        // 時刻の文: 数 + 時 (時間・同時は除く。一時 (一時停止) と紛れるので 一 は数に入れない)、秒、「時と分」
        let timeCtx = timeContext.test(r.speak)
        var why: String? = nil
        if lone[w]?.contains(where: { JSCompat.same($0, y) }) == true && !(w == "上" && afterKanji) { why = "熟語の中だけの読み" }
        else if w == "分" && JSCompat.same(y, "ぶん") && timeCtx && !afterKanji { why = "時刻なら ふん" }
        else if let rd = rendaku[w], JSCompat.same(rd, y), !joined { why = "1 字なのに濁った読み" }
        if let why { loneWarns.append("  \(JSCompat.padEnd(r.key, 5)) 「\(w)」が \(w)(\(y)) と読まれています (\(why)): \(r.speak)") }
      }
    }
    return loneWarns
  }
}
