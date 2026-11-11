// クラウドの TTS (tts.engine: "google" / "azure" / "amazon" / "openai") の共通部分。
// どれも環境変数にキーを入れるだけで使える (スクリプトは要らない)。jgv tts はここを通して呼ぶ
import Foundation
import JGVCore

/// クラウドの TTS ごとの違い (TTS.swift / MD2Script.swift / jgv voices から使う)
enum CloudTTS {
  static let engines = ["google", "azure", "amazon", "openai"]

  static func name(_ engine: String) -> String {
    switch engine {
    case "google": return "Google Cloud Text-to-Speech"
    case "azure": return "Azure AI Speech"
    case "openai": return "OpenAI TTS"
    default: return "Amazon Polly"
    }
  }

  /// engine ごとに tts に書ける設定 (engine と voice のほか)
  static func settings(_ engine: String) -> [String] {
    switch engine {
    case "amazon": return ["parallel", "pollyEngine"]
    case "openai": return ["parallel", "model", "instructions"]
    default: return ["parallel"]
    }
  }

  /// tts の設定を確かめる (書き間違いを、有料の API を呼ぶ前に止める)
  static func validate(_ engine: String, _ tts: JSON) throws {
    if engine == "openai" { try OpenAITTS.validate(tts) }
    if engine == "amazon", let e = tts["pollyEngine"] {
      guard let s = e.string, AmazonTTS.engines.contains(s) else {
        throw ToolError("tts.pollyEngine は \(AmazonTTS.engines.joined(separator: " / ")) のどれかで書いてください: \(e.description)")
      }
    }
  }

  /// 認証情報が無ければ、何を設定すればよいかを書いたエラーにする
  static func requireCredentials(_ engine: String) throws {
    switch engine {
    case "google": _ = try GoogleTTS.credentials()
    case "azure": _ = try AzureTTS.credentials()
    case "openai": _ = try OpenAITTS.apiKey()
    default: _ = try AmazonTTS.credentials()
    }
  }

  /// md2script 用: 認証情報が足りなければ、その説明 (止めずに警告にする)
  static func missingCredentials(_ engine: String) -> String? {
    do { try requireCredentials(engine); return nil } catch let e as ToolError { return e.message } catch { return "\(error)" }
  }

  /// キャッシュキーに入れる言語 (voice を書かないと、多言語版で同じ文の音声を別の言語に流用してしまうため)
  /// amazon は声で言語が決まり、openai は言語を送らないので入れない (lang を ja-JP → ja に直しただけで有料の API を呼び直さないように)
  static func cacheLang(_ engine: String, voice: String, lang: String) -> String {
    engine == "amazon" || engine == "openai" ? "" : GoogleTTS.languageCode(voice: voice, lang: engine == "google" ? GoogleTTS.googleLang(lang) : lang)
  }

  /// voice を書かなかったときの声。google は API が言語から選ぶので空のまま。azure / amazon は声の一覧から選ぶ。openai は決まった声
  static func defaultVoice(_ engine: String, lang: String, tts: JSON) throws -> String {
    switch engine {
    case "azure": return try AzureTTS.defaultVoice(lang)
    case "amazon": return try AmazonTTS.defaultVoice(lang, engine: tts["pollyEngine"]?.string ?? AmazonTTS.engines[1])
    case "openai": return OpenAITTS.defaultVoice(model: tts["model"]?.string ?? OpenAITTS.defaultModel)
    default: return ""
    }
  }

  /// API が返す音声の拡張子
  static func rawExt(_ engine: String) -> String { engine == "amazon" ? "mp3" : "wav" }

  /// 1 行を合成して out に書く
  static func synth(_ engine: String, text: String, lang: String, voice: String, tts: JSON, to out: URL) throws {
    switch engine {
    case "google": try GoogleTTS.synth(text: text, lang: lang, voice: voice, to: out)
    case "azure": try AzureTTS.synth(text: text, lang: lang, voice: voice, to: out)
    case "openai": try OpenAITTS.synth(text: text, voice: voice, tts: tts, to: out)
    default: try AmazonTTS.synth(text: text, voice: voice, engine: tts["pollyEngine"]?.string ?? AmazonTTS.engines[1], to: out)
    }
  }

  /// jgv voices --google / --azure / --amazon
  static func voices(_ engine: String, lang: String, pollyEngine: String? = nil) throws -> [(name: String, info: String)] {
    switch engine {
    case "google": return try GoogleTTS.voices(lang).map { (name: $0.name, info: $0.gender) }
    case "azure": return try AzureTTS.voices(lang)
    case "openai": return OpenAITTS.voices()
    default: return try AmazonTTS.voices(lang, engine: pollyEngine ?? AmazonTTS.engines[1])
    }
  }

  /// 言語の候補から声を選ぶ: 台本の言語と同じもの、無ければ言語の頭 (ja / en) が同じもの
  static func pick<T>(_ list: [T], lang: String, locale: (T) -> String) -> [T] {
    // zh-Hant / zh-Hans などの書き方は、地域のタグ (zh-TW / zh-CN / zh-HK) に直してから探す
    let lang = { () -> String in
      switch lang.lowercased() {
      case "zh-hant", "zh-hant-tw": return "zh-TW"
      case "zh-hans", "zh-hans-cn": return "zh-CN"
      case "zh-hant-hk": return "zh-HK"
      case "zh-hant-mo": return "zh-MO"
      default: return lang
      }
    }()
    let exact = list.filter { locale($0).lowercased() == lang.lowercased() }
    if !exact.isEmpty { return exact }
    let head = { (s: String) in String(s.lowercased().split(separator: "-").first ?? "") }
    // 中国語は Amazon Polly では cmn (普通話)・yue (広東語)。香港・マカオは広東語を先に探す
    let l = lang.lowercased()
    // (Azure は香港の広東語を zh-HK (繁体字) と yue-CN (簡体字) で持つので、zh-HK を先に探す。Polly の広東語は yue-CN だけ)
    let want = l == "zh-hk" || l == "zh-mo" ? ["zh-hk", "yue", "zh", "cmn"] : head(lang) == "zh" ? ["zh", "cmn"] : [head(lang)]
    for w in want {
      let found = list.filter { w.contains("-") ? locale($0).lowercased() == w : head(locale($0)) == w }
      if !found.isEmpty { return found }
    }
    return []
  }
}

/// クラウドの TTS の HTTP の共通部分 (同期の送受信・やり直し・テスト用の送り先の上書き)
enum CloudHTTP {
  struct Transient: Error {
    let message: String
    /// 送る前に失敗した (接続できなかった) か。送った後の失敗 (タイムアウト・切断) は、サーバーが処理し終えている (課金されている) ことがある
    var notSent = false
  }

  /// 応答 (やり直すかどうかの判定に使う。AWS は誤りの種類をヘッダー x-amzn-ErrorType で返す)
  struct Response {
    var status: Int
    var data: Data
    var headers: [String: String]  // 名前は小文字
    func header(_ name: String) -> String { headers[name.lowercased()] ?? "" }
    var bodyText: String { String(decoding: data.prefix(2000), as: UTF8.self) }
  }

  /// 通信の一時的な失敗 (やり直す)
  private static let notSentErrors: Set<URLError.Code> = [.cannotConnectToHost, .notConnectedToInternet, .dnsLookupFailed, .cannotFindHost]
  private static let transientErrors: Set<URLError.Code> = [.timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet, .dnsLookupFailed, .cannotFindHost]

  private final class Box: @unchecked Sendable {
    var data = Data()
    var status = 0
    var headers: [String: String] = [:]
    var error: Error?
  }

  /// 環境変数 (前後の空白は外す)
  static func env(_ name: String) -> String {
    (ProcessInfo.processInfo.environment[name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// リダイレクトに従わない (キーを付けたヘッダーのまま別の送り先へ行かないように。3xx はそのままエラーとして返る)
  final class NoRedirect: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
      completionHandler(nil)
    }
  }
  /// 送り先に伝えるツールの名前と版 (git を呼ぶので 1 回だけ求める)
  static let userAgent = "j-guide-video/\(Project.skillRevision() ?? "unknown")"
  /// ephemeral: ディスクのキャッシュ (URLCache) を使わない。.default だと、API キーのヘッダーを含むリクエストと合成した音声が
  /// ~/Library/Caches/<実行ファイル名>/Cache.db に平文で残る。クッキー・資格情報も保存しない
  static let session: URLSession = {
    let c = URLSessionConfiguration.ephemeral
    c.urlCache = nil
    c.requestCachePolicy = .reloadIgnoringLocalCacheData
    c.httpCookieStorage = nil
    c.httpShouldSetCookies = false
    c.urlCredentialStorage = nil
    return URLSession(configuration: c, delegate: NoRedirect(), delegateQueue: nil)
  }()

  /// 同期で HTTP を呼ぶ (TTS の pool はスレッドで並列に動くので、ここではブロックしてよい)
  static func send(_ req: URLRequest, service: String) throws -> Response {
    let box = Box()
    let done = DispatchSemaphore(value: 0)
    var req = req
    // どのツールからの呼び出しかを送り先に伝える (TTS ごとにばらばらにしない)
    if req.value(forHTTPHeaderField: "User-Agent") == nil || req.value(forHTTPHeaderField: "User-Agent") == "j-guide-video" {
      req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    }
    session.dataTask(with: req) { data, res, err in
      box.data = data ?? Data()
      box.status = (res as? HTTPURLResponse)?.statusCode ?? 0
      for (k, v) in (res as? HTTPURLResponse)?.allHeaderFields ?? [:] {
        if let k = k as? String, let v = v as? String { box.headers[k.lowercased()] = v }
      }
      box.error = err
      done.signal()
    }.resume()
    done.wait()
    if let e = box.error {
      let message = "\(service) に接続できませんでした: \(e.localizedDescription)"
      if let u = e as? URLError, transientErrors.contains(u.code) { throw Transient(message: message, notSent: notSentErrors.contains(u.code)) }
      throw ToolError(message)
    }
    return Response(status: box.status, data: box.data, headers: box.headers)
  }

  private static let lock = NSLock()
  nonisolated(unsafe) private static var announced: Set<String> = []

  /// 送り先の URL。overrideEnv (JGV_GOOGLE_TTS_BASE など) はテスト用 (モックのサーバーに向ける)。
  /// キーを送るので、上書きはこのマシンの中 (localhost / 127.0.0.1 / [::1]) だけにする
  /// (他人のプロジェクトの設定に仕込まれた値で、キーが外のサーバーに送られないように)
  static func url(_ base: String, _ path: String, overrideEnv: String, service: String) throws -> URL {
    let override = ProcessInfo.processInfo.environment[overrideEnv] ?? ""
    if override.isEmpty {
      guard let u = URL(string: base + path) else { throw ToolError("\(service) の URL を作れませんでした: \(base + path)") }
      return u
    }
    let trimmed = override.hasSuffix("/") ? String(override.dropLast()) : override
    guard let u = URL(string: trimmed + path), let host = u.host, ["http", "https"].contains(u.scheme ?? ""),
          ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host) else {
      throw ToolError("\(overrideEnv) はテスト用で、このマシンの中の URL (http://127.0.0.1:… など) だけ使えます: \(override)")
    }
    // 送り先を変えていることは 1 回だけ伝える
    lock.lock()
    let first = announced.insert(overrideEnv).inserted
    lock.unlock()
    if first { FileHandle.standardError.write("WARN: \(service) の送り先を \(trimmed) に変えています (\(overrideEnv))\n".data(using: .utf8)!) }
    return u
  }

  /// キーを入れる環境変数 (値をエラーの文に出さない)
  static let secretEnvs = [GoogleTTS.keyEnv, AzureTTS.keyEnv, OpenAITTS.keyEnv, "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN"]

  /// 手元のキーの値を *** にする (短すぎる値は、ふつうの文字まで伏せてしまうので対象にしない)
  static func redact(_ s: String) -> String {
    var out = s
    for v in secretEnvs.map(env) where v.count >= 8 { out = out.replacingOccurrences(of: v, with: "***") }
    return out
  }

  /// エラーの応答から理由を取り出す (JSON の error.message / message / Message、無ければ本文の頭)
  static func errorMessage(_ service: String, _ status: Int, _ data: Data) -> String {
    let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    // 式を分ける (1 つの式で ?? をつなぐと、古い Swift では型を決めるのに時間がかかりすぎてビルドが止まる)
    let nested: String? = (obj?["error"] as? [String: Any])?["message"] as? String
    let top: String? = obj?["message"] as? String
    let upper: String? = obj?["Message"] as? String
    var described: String? = nil
    if let d = obj?["error_description"] as? String {
      let code: String? = obj?["error"] as? String
      described = code.map { "\($0): \(d)" } ?? d
    }
    let raw: String = nested ?? top ?? upper ?? described ?? String(decoding: data.prefix(500), as: UTF8.self)
    // 相手の返す文をそのまま出すので、長さを切り、手元のキーの値が入っていれば伏せる
    // (署名の不一致のエラーが、送ったヘッダー (セッショントークンなど) をそのまま返すことがある)
    let msg = redact(raw.count > 500 ? String(raw.prefix(500)) + "…" : raw)
    // 403 はキーの誤りのほか、API が有効でない・課金が無い・権限 (IAM) が足りないときにも返る
    let hint = status == 401 || msg.contains("API key") || msg.contains("UNAUTHENTICATED") ? " (キー・地域などの環境変数を確かめてください)"
      : status == 403 ? " (キー・地域の環境変数のほか、API の有効化・課金・権限 (IAM) を確かめてください)" : ""
    return "\(service): \(status) \(msg.isEmpty ? "(本文なし)" : msg)\(hint)"
  }

  /// 呼び出して、200 なら本文を返す。429・5xx (と retryable が真を返す応答) と通信の一時的な失敗は、少し待って 3 回までやり直す
  /// (fatal が真を返す応答は、待っても直らないのでやり直さない)。make は毎回呼ぶ (署名に時刻を入れる API があるため)
  static func call(service: String, text: String? = nil, retryable: (Response) -> Bool = { _ in false }, fatal: (Response) -> Bool = { _ in false },
                   _ make: () throws -> URLRequest) throws -> Data {
    let suffix = text.map { "\n文: \($0)" } ?? ""
    var attempt = 0
    while true {
      let r: Response
      let req = try make()
      do {
        r = try send(req, service: service)
      } catch let e as Transient {
        attempt += 1
        // POST (合成) は、送った後の失敗ではやり直さない (同じ行の料金が重なりうる)。接続できなかったときだけやり直す
        if attempt < 4 && (e.notSent || req.httpMethod?.uppercased() != "POST") { Thread.sleep(forTimeInterval: Double(1 << (attempt - 1))); continue }
        throw ToolError("\(e.message)\(suffix)")
      }
      if r.status == 200 { return r.data }
      attempt += 1
      if (r.status == 429 || r.status >= 500 || retryable(r)) && !fatal(r) && attempt < 4 {
        Thread.sleep(forTimeInterval: Double(1 << (attempt - 1)))
        continue
      }
      throw ToolError("\(errorMessage(service, r.status, r.data))\(suffix)")
    }
  }
}
