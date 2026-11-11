// Google Cloud Text-to-Speech (tts.engine: "google")。API キーを環境変数 GOOGLE_TTS_API_KEY に入れるだけで使える。
// キーは URL ではなく X-Goog-Api-Key ヘッダーで送る (ログや履歴に残りにくいように)。
// API キーが無ければ、GOOGLE_APPLICATION_CREDENTIALS のサービスアカウントの鍵で取ったアクセストークンを Authorization ヘッダーで送る
import Foundation

enum GoogleTTS {
  static let keyEnv = "GOOGLE_TTS_API_KEY"
  static let service = "Google TTS"
  private static let base = "https://texttospeech.googleapis.com/v1"

  enum Auth {
    case apiKey(String)
    case serviceAccount(GoogleServiceAccount.Key)
  }

  /// 認証情報。API キー (GOOGLE_TTS_API_KEY) が先で、無ければサービスアカウントの鍵 (GOOGLE_APPLICATION_CREDENTIALS)。
  /// どちらも無ければ使い方を書いたエラーにする
  static func credentials() throws -> Auth {
    let key = CloudHTTP.env(keyEnv)
    if !key.isEmpty { return .apiKey(key) }
    if let k = try GoogleServiceAccount.key() { return .serviceAccount(k) }
    throw ToolError("Google Cloud Text-to-Speech を使うには、環境変数 \(keyEnv) に Google Cloud の API キーを入れるか (例: ~/.zshrc に export \(keyEnv)=…)、"
      + "\(GoogleServiceAccount.credentialsEnv) にサービスアカウントの鍵 (JSON) のパスを入れてください")
  }

  /// 送る languageCode。voice (ja-JP-Neural2-B など) があれば、その頭の言語を使う (台本の lang と食い違うと API がエラーにするため)
  static func languageCode(voice: String, lang: String) -> String {
    if let r = voice.range(of: "^[a-z]{2,3}-[A-Z]{2}(?=-)", options: .regularExpression) { return String(voice[r]) }
    return lang
  }

  /// Google の中国語の言語コードは cmn-CN (普通話)・cmn-TW・yue-HK (広東語)。台本の zh-CN などを置き換えて送る
  static func googleLang(_ lang: String) -> String {
    switch lang.lowercased() {
    case "zh", "zh-cn", "zh-hans", "zh-hans-cn": return "cmn-CN"
    case "zh-tw", "zh-hant", "zh-hant-tw": return "cmn-TW"
    case "zh-hk", "zh-hant-hk": return "yue-HK"
    default: return lang
    }
  }

  private static func request(_ path: String) throws -> URLRequest {
    var req = URLRequest(url: try CloudHTTP.url(base, path, overrideEnv: "JGV_GOOGLE_TTS_BASE", service: service), timeoutInterval: 60)
    switch try credentials() {
    case .apiKey(let key): req.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
    case .serviceAccount(let k): req.setValue("Bearer \(try GoogleServiceAccount.accessToken(k))", forHTTPHeaderField: "Authorization")
    }
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    return req
  }

  /// 1 行を合成して、LINEAR16 の wav を out に書く
  static func synth(text: String, lang: String, voice: String, to out: URL) throws {
    var voiceObj: [String: Any] = ["languageCode": languageCode(voice: voice, lang: googleLang(lang))]
    if !voice.isEmpty { voiceObj["name"] = voice }
    let body = try JSONSerialization.data(withJSONObject: [
      "input": ["text": text], "voice": voiceObj, "audioConfig": ["audioEncoding": "LINEAR16"],
    ])
    let data = try CloudHTTP.call(service: service, text: text) {
      var req = try request("/text:synthesize")
      req.httpMethod = "POST"
      req.httpBody = body
      return req
    }
    let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    guard let b64 = obj?["audioContent"] as? String, let audio = Data(base64Encoded: b64), !audio.isEmpty else {
      throw ToolError("\(service) の応答に音声がありませんでした: \(text)")
    }
    try audio.write(to: out)
  }

  /// その言語で使える声の名前 (jgv voices --google)
  static func voices(_ lang: String) throws -> [(name: String, gender: String)] {
    var c = URLComponents(string: "/voices")!
    c.queryItems = [URLQueryItem(name: "languageCode", value: googleLang(lang))]
    let data = try CloudHTTP.call(service: service) { try request(c.string!) }
    let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    let voices: [[String: Any]] = obj?["voices"] as? [[String: Any]] ?? []
    let list: [(String, String)] = voices.map { (d: [String: Any]) -> (String, String) in
      let name: String = d["name"] as? String ?? ""
      let gender: String = d["ssmlGender"] as? String ?? ""
      return (name, gender)
    }
    return list.sorted { $0.0 < $1.0 }.map { (name: $0.0, gender: $0.1) }
  }
}
