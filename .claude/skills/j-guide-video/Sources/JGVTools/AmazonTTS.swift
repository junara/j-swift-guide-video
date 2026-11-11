// Amazon Polly (tts.engine: "amazon")。環境変数 AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (一時的な認証情報なら AWS_SESSION_TOKEN も) と
// AWS_REGION (ap-northeast-1 など。無ければ AWS_DEFAULT_REGION) を入れるだけで使える。リクエストには AWS の署名 (Signature Version 4) を付ける。
// ~/.aws/credentials のプロファイルや SSO は読まない (環境変数だけ)
import CryptoKit
import Foundation

enum AmazonTTS {
  static let service = "Amazon Polly"
  /// tts.pollyEngine に書ける値 (既定は neural)
  static let engines = ["standard", "neural", "long-form", "generative"]

  struct Credentials { var accessKey: String; var secretKey: String; var sessionToken: String; var region: String }

  static func credentials() throws -> Credentials {
    let ak = CloudHTTP.env("AWS_ACCESS_KEY_ID"), sk = CloudHTTP.env("AWS_SECRET_ACCESS_KEY")
    let region = [CloudHTTP.env("AWS_REGION"), CloudHTTP.env("AWS_DEFAULT_REGION")].first { !$0.isEmpty } ?? ""
    let missing = [ak.isEmpty ? "AWS_ACCESS_KEY_ID" : nil, sk.isEmpty ? "AWS_SECRET_ACCESS_KEY" : nil, region.isEmpty ? "AWS_REGION" : nil].compactMap { $0 }
    if !missing.isEmpty {
      throw ToolError("Amazon Polly を使うには、環境変数 AWS_ACCESS_KEY_ID・AWS_SECRET_ACCESS_KEY (IAM のアクセスキー) と AWS_REGION (地域。ap-northeast-1 など) が必要です。足りないもの: \(missing.joined(separator: " と "))")
    }
    // 地域は URL のホスト名に入れるので、英小文字・数字・ハイフンだけ (ほかの文字で送り先が変わらないように)
    if region.range(of: "^[a-z0-9-]+$", options: .regularExpression) == nil {
      throw ToolError("AWS_REGION は地域の名前 (ap-northeast-1 など、英小文字・数字・ハイフンだけ) で書いてください: \(region)")
    }
    return Credentials(accessKey: ak, secretKey: sk, sessionToken: CloudHTTP.env("AWS_SESSION_TOKEN"), region: region)
  }

  // ---------- Signature Version 4 ----------

  private static func hex(_ d: some Sequence<UInt8>) -> String { d.map { String(format: "%02x", $0) }.joined() }
  private static func sha256(_ d: Data) -> String { hex(SHA256.hash(data: d)) }
  private static func hmac(_ key: Data, _ s: String) -> Data { Data(HMAC<SHA256>.authenticationCode(for: Data(s.utf8), using: SymmetricKey(data: key))) }

  /// RFC 3986 の予約されていない文字以外を %XX にする (署名の正規化に使う)
  static func encode(_ s: String) -> String {
    let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    return s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s
  }

  /// リクエストに署名する (X-Amz-Date・X-Amz-Security-Token・Authorization を付ける)。now はテスト用
  static func sign(_ req: inout URLRequest, _ c: Credentials, service svc: String = "polly", now: Date = Date()) {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    let amzDate = f.string(from: now)
    let dateStamp = String(amzDate.prefix(8))
    let url = req.url!
    let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    // URLSession が送る Host ヘッダーと同じにする (既定以外のポートは付ける)
    let h = url.host ?? ""
    let host = (h.contains(":") ? "[\(h)]" : h) + (url.port.map { ":\($0)" } ?? "")
    req.setValue(amzDate, forHTTPHeaderField: "X-Amz-Date")
    if !c.sessionToken.isEmpty { req.setValue(c.sessionToken, forHTTPHeaderField: "X-Amz-Security-Token") }

    var headers: [String: String] = ["host": host, "x-amz-date": amzDate]
    if let ct = req.value(forHTTPHeaderField: "Content-Type") { headers["content-type"] = ct }
    if !c.sessionToken.isEmpty { headers["x-amz-security-token"] = c.sessionToken }
    let names = headers.keys.sorted()
    let canonicalHeaders = names.map { "\($0):\(headers[$0]!.trimmingCharacters(in: .whitespaces))\n" }.joined()
    let signedHeaders = names.joined(separator: ";")
    let path = comps.percentEncodedPath.isEmpty ? "/" : comps.percentEncodedPath
    let query = (comps.queryItems ?? []).map { (encode($0.name), encode($0.value ?? "")) }.sorted { $0 < $1 }.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
    let canonical = [req.httpMethod ?? "GET", path, query, canonicalHeaders, signedHeaders, sha256(req.httpBody ?? Data())].joined(separator: "\n")

    let scope = "\(dateStamp)/\(c.region)/\(svc)/aws4_request"
    let toSign = ["AWS4-HMAC-SHA256", amzDate, scope, sha256(Data(canonical.utf8))].joined(separator: "\n")
    var key = hmac(Data("AWS4\(c.secretKey)".utf8), dateStamp)
    key = hmac(key, c.region)
    key = hmac(key, svc)
    key = hmac(key, "aws4_request")
    let signature = hex(hmac(key, toSign))
    req.setValue("AWS4-HMAC-SHA256 Credential=\(c.accessKey)/\(scope), SignedHeaders=\(signedHeaders), Signature=\(signature)", forHTTPHeaderField: "Authorization")
  }

  private static func request(_ path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
    let c = try credentials()
    let url = try CloudHTTP.url("https://polly.\(c.region).amazonaws.com", path, overrideEnv: "JGV_AMAZON_TTS_BASE", service: service)
    var req = URLRequest(url: url, timeoutInterval: 60)
    req.httpMethod = method
    if let body {
      req.httpBody = body
      req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    sign(&req, c)
    return req
  }

  /// Polly の流量制限は 400 で返ることがあるので、それもやり直す (種類はヘッダー x-amzn-ErrorType、本文は "Rate exceeded" だけのことが多い)
  private static func throttled(_ r: CloudHTTP.Response) -> Bool {
    r.status == 400 && (r.header("x-amzn-ErrorType").contains("Throttling") || r.bodyText.contains("Throttling") || r.bodyText.contains("Rate exceeded"))
  }

  /// 1 行を合成して、mp3 を out に書く (voice は必須。書かなければ jgv tts が defaultVoice で選ぶ)
  static func synth(text: String, voice: String, engine: String, to out: URL) throws {
    let body = try JSONSerialization.data(withJSONObject: ["Text": text, "TextType": "text", "OutputFormat": "mp3", "VoiceId": voice, "Engine": engine])
    let data = try CloudHTTP.call(service: service, text: text, retryable: throttled) {
      try request("/v1/speech", method: "POST", body: body)
    }
    if data.isEmpty { throw ToolError("\(service) の応答に音声がありませんでした: \(text)") }
    try data.write(to: out)
  }

  private struct Voice { var id: String; var lang: String; var gender: String; var engines: [String] }

  /// その engine で使える声 (NextToken で続きがあれば最後まで読む)
  private static func allVoices(engine: String) throws -> [Voice] {
    var out: [Voice] = []
    var next: String? = nil
    repeat {
      // クエリは署名と同じ規則 (RFC 3986) で %XX にする (NextToken の + / = が、送った値と署名した値でずれないように)
      let path = "/v1/voices?Engine=\(encode(engine))" + (next.map { "&NextToken=\(encode($0))" } ?? "")
      let data = try CloudHTTP.call(service: service, retryable: throttled) { try request(path) }
      let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
      // 項目ごとに分けて取り出す (古い Swift で型を決めるのに時間がかからないように)
      func str(_ d: [String: Any], _ k: String) -> String { d[k] as? String ?? "" }
      let voices: [[String: Any]] = obj?["Voices"] as? [[String: Any]] ?? []
      out += voices.map { (d: [String: Any]) -> Voice in
        let engines: [String] = d["SupportedEngines"] as? [String] ?? []
        return Voice(id: str(d, "Id"), lang: str(d, "LanguageCode"), gender: str(d, "Gender"), engines: engines)
      }
      next = obj?["NextToken"] as? String
    } while next != nil
    return out.filter { !$0.id.isEmpty }.sorted { $0.id < $1.id }
  }

  /// その言語で、その engine (既定 neural) が使える声 (jgv voices --amazon [--polly-engine=generative])
  static func voices(_ lang: String, engine: String) throws -> [(name: String, info: String)] {
    guard engines.contains(engine) else { throw ToolError("--polly-engine は \(engines.joined(separator: " / ")) のどれかで書いてください: \(engine)") }
    return CloudTTS.pick(try allVoices(engine: engine), lang: lang) { $0.lang }.map { (name: $0.id, info: "\($0.gender)\t\($0.lang)\t\($0.engines.joined(separator: ","))") }
  }

  /// voice を書かなかったときの声: 台本の言語で、その engine が使える代表的な声 (preferred)、無ければ名前の順で最初のもの
  /// 言語ごとの代表的な声 (その engine で使えて一覧にあれば、名前の順より先に選ぶ)
  static let preferred = ["Kazuha", "Joanna", "Amy", "Zhiyu", "Hiujin", "Seoyeon", "Lea", "Vicki", "Lucia"]

  static func defaultVoice(_ lang: String, engine: String) throws -> String {
    // 一覧は Engine で絞ってもらっているが、念のため SupportedEngines でも確かめる
    let usable = try allVoices(engine: engine).filter { $0.engines.isEmpty || $0.engines.contains(engine) }
    let list = CloudTTS.pick(usable, lang: lang, locale: { $0.lang })
    guard let v = preferred.compactMap({ p in list.first { $0.id == p } }).first ?? list.first else {
      throw ToolError("\(service) に \(lang) の声 (\(engine)) がありません。jgv voices \(lang) --amazon で確かめて、tts.voice に書いてください")
    }
    return v.id
  }
}
