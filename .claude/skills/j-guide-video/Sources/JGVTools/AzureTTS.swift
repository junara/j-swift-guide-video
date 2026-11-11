// Azure AI Speech の音声合成 (tts.engine: "azure")。環境変数 AZURE_SPEECH_KEY (キー) と AZURE_SPEECH_REGION (地域。japaneast など) を入れるだけで使える。
// 文は SSML に包んで送る。キーは Ocp-Apim-Subscription-Key ヘッダーで送る
import Foundation

enum AzureTTS {
  static let keyEnv = "AZURE_SPEECH_KEY"
  static let regionEnv = "AZURE_SPEECH_REGION"
  static let service = "Azure TTS"

  /// キーと地域。地域は英小文字と数字だけ (URL のホスト名に入れるので、ほかの文字でキーの送り先が変わらないように)
  static func credentials() throws -> (key: String, region: String) {
    let key = CloudHTTP.env(keyEnv), region = CloudHTTP.env(regionEnv)
    if key.isEmpty || region.isEmpty {
      let missing = [key.isEmpty ? keyEnv : nil, region.isEmpty ? regionEnv : nil].compactMap { $0 }.joined(separator: " と ")
      throw ToolError("Azure AI Speech を使うには、環境変数 \(keyEnv) (Speech リソースのキー) と \(regionEnv) (地域。japaneast など) が必要です。足りないもの: \(missing)")
    }
    if region.range(of: "^[a-z0-9]+$", options: .regularExpression) == nil {
      throw ToolError("\(regionEnv) は地域の名前 (japaneast / eastus など、英小文字と数字だけ) で書いてください: \(region)")
    }
    return (key, region)
  }

  private static func request(_ path: String) throws -> URLRequest {
    let c = try credentials()
    let url = try CloudHTTP.url("https://\(c.region).tts.speech.microsoft.com", path, overrideEnv: "JGV_AZURE_TTS_BASE", service: service)
    var req = URLRequest(url: url, timeoutInterval: 60)
    req.setValue(c.key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
    req.setValue("j-guide-video", forHTTPHeaderField: "User-Agent")
    return req
  }

  /// SSML に入れる文字のエスケープ
  static func escape(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;")
  }

  /// 1 行を合成して、24kHz 16bit モノラルの wav を out に書く (voice は必須。書かなければ jgv tts が defaultVoice で選ぶ)
  static func synth(text: String, lang: String, voice: String, to out: URL) throws {
    let xmlLang = GoogleTTS.languageCode(voice: voice, lang: lang)
    let ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='\(escape(xmlLang))'><voice name='\(escape(voice))'>\(escape(text))</voice></speak>"
    let data = try CloudHTTP.call(service: service, text: text) {
      var req = try request("/cognitiveservices/v1")
      req.httpMethod = "POST"
      req.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
      req.setValue("riff-24khz-16bit-mono-pcm", forHTTPHeaderField: "X-Microsoft-OutputFormat")
      req.httpBody = Data(ssml.utf8)
      return req
    }
    if data.isEmpty { throw ToolError("\(service) の応答に音声がありませんでした: \(text)") }
    try data.write(to: out)
  }

  private struct Voice { var name: String; var locale: String; var gender: String; var type: String; var status: String }

  private static func allVoices() throws -> [Voice] {
    let data = try CloudHTTP.call(service: service) { try request("/cognitiveservices/voices/list") }
    let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
    // 項目ごとに分けて取り出す (1 つの式に as? と ?? を並べると、古い Swift では型を決めるのに時間がかかりすぎる)
    func str(_ d: [String: Any], _ k: String) -> String { d[k] as? String ?? "" }
    return list.map { (d: [String: Any]) -> Voice in
      Voice(name: str(d, "ShortName"), locale: str(d, "Locale"), gender: str(d, "Gender"), type: str(d, "VoiceType"), status: str(d, "Status"))
    }.filter { !$0.name.isEmpty }.sorted { $0.name < $1.name }
  }

  /// その言語で使える声の名前 (jgv voices --azure)
  static func voices(_ lang: String) throws -> [(name: String, info: String)] {
    CloudTTS.pick(try allVoices(), lang: lang) { $0.locale }.map { (name: $0.name, info: "\($0.gender)\t\($0.type)") }
  }

  /// voice を書かなかったときの声: 台本の言語の代表的な声 (preferred)、無ければ正式版 (GA) のニューラル音声のうち名前の順で最初のもの
  /// (それも無ければ廃止予定でないニューラル音声、それも無ければ最初の声)
  /// 言語ごとの代表的な声 (一覧にあれば、名前の順より先に選ぶ。名前の順の先頭は子どもの声などのことがあるため)
  static let preferred = [
    "ja-JP-NanamiNeural", "en-US-JennyNeural", "en-GB-SoniaNeural", "zh-CN-XiaoxiaoNeural", "zh-TW-HsiaoChenNeural", "zh-HK-HiuMaanNeural",
    "ko-KR-SunHiNeural", "vi-VN-HoaiMyNeural", "fr-FR-DeniseNeural", "de-DE-KatjaNeural", "es-ES-ElviraNeural",
  ]

  static func defaultVoice(_ lang: String) throws -> String {
    let list = CloudTTS.pick(try allVoices(), lang: lang) { $0.locale }
    let ga = { (v: Voice) in v.status.isEmpty || v.status == "GA" }
    let pref = preferred.compactMap { p in list.first { $0.name == p && $0.status != "Deprecated" } }.first
    guard let v = pref ?? list.first(where: { $0.type == "Neural" && ga($0) }) ?? list.first(where: { $0.type == "Neural" && $0.status != "Deprecated" }) ?? list.first else {
      throw ToolError("\(service) に \(lang) の声がありません。jgv voices \(lang) --azure で確かめて、tts.voice に書いてください")
    }
    return v.name
  }
}
