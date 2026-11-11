// OpenAI の音声合成 (tts.engine: "openai")。環境変数 OPENAI_API_KEY に API キーを入れるだけで使える。
// 言語は文から自動で判断される (API に言語を渡さない)。声の一覧を返す API は無いので、jgv voices --openai は決まった一覧を出す。
// OpenAI の利用規約では、聞く人に AI が作った音声であることを伝える必要があるので、クレジットの既定に「AI 音声」と出す (TTS.swift)
import Foundation
import JGVCore

enum OpenAITTS {
  static let keyEnv = "OPENAI_API_KEY"
  static let service = "OpenAI TTS"
  private static let base = "https://api.openai.com/v1"
  /// tts.model の既定 (instructions で話し方を指示できるモデル)
  static let defaultModel = "gpt-4o-mini-tts"
  /// OpenAI は /v1/audio/speech のモデル (tts-1 / tts-1-hd / gpt-4o-mini-tts) を 2027-01-06 に止める予定 (後継の gpt-realtime-2.1-mini は Realtime API 用で、この API では使えない)
  static let shutdownNotice = "OpenAI は音声合成のモデル (tts-1 / tts-1-hd / gpt-4o-mini-tts) を 2027-01-06 に止める予定です。止まったあとは google / azure / amazon などを使ってください"
  /// voice を書かなかったときの声 (OpenAI が勧める marin。tts-1 / tts-1-hd では使えないので alloy)
  static func defaultVoice(model: String) -> String { model.hasPrefix("tts-1") ? "alloy" : "marin" }
  /// 声の名前 (API で一覧を取れないので、ドキュメントの一覧。tts-1 / tts-1-hd で使えるのは onlyNew が false のもの)
  static let knownVoices: [(name: String, onlyNew: Bool)] = [
    ("alloy", false), ("ash", false), ("ballad", true), ("cedar", true), ("coral", false), ("echo", false), ("fable", false),
    ("marin", true), ("nova", false), ("onyx", false), ("sage", false), ("shimmer", false), ("verse", true),
  ]

  static func apiKey() throws -> String {
    let key = CloudHTTP.env(keyEnv)
    if key.isEmpty {
      throw ToolError("OpenAI の音声合成を使うには、環境変数 \(keyEnv) に OpenAI の API キーが必要です (例: ~/.zshrc に export \(keyEnv)=…)")
    }
    return key
  }

  /// tts.model / tts.instructions を確かめる (instructions は tts-1 / tts-1-hd では使えない)
  static func validate(_ tts: JSON) throws {
    if let m = tts["model"], (m.string ?? "").isEmpty { throw ToolError("tts.model はモデルの名前 (gpt-4o-mini-tts / tts-1 / tts-1-hd など) で書いてください: \(m.description)") }
    if let i = tts["instructions"] {
      guard i.string != nil else { throw ToolError("tts.instructions は話し方の指示 (文字列) で書いてください: \(i.description)") }
      if (tts["model"]?.string ?? defaultModel).hasPrefix("tts-1") {
        throw ToolError("tts.instructions は tts-1 / tts-1-hd では使えません (gpt-4o-mini-tts などで使えます)")
      }
    }
  }

  /// 1 行を合成して、wav を out に書く
  static func synth(text: String, voice: String, tts: JSON, to out: URL) throws {
    var body: [String: Any] = [
      "model": tts["model"]?.string ?? defaultModel, "input": text, "voice": voice.isEmpty ? defaultVoice(model: tts["model"]?.string ?? defaultModel) : voice, "response_format": "wav",
    ]
    if let i = tts["instructions"]?.string, !i.isEmpty { body["instructions"] = i }
    let data = try JSONSerialization.data(withJSONObject: body)
    let audio: Data
    do {
      audio = try callSpeech(text: text, data: data)
    } catch let e as ToolError where e.message.contains("model_not_found") || e.message.contains("model") && (e.message.contains("does not exist") || e.message.contains(": 404 ")) {
      throw ToolError("\(e.message)\n\(shutdownNotice)")
    }
    if audio.isEmpty { throw ToolError("\(service) の応答に音声がありませんでした: \(text)") }
    try audio.write(to: out)
  }

  private static func callSpeech(text: String, data: Data) throws -> Data {
    try CloudHTTP.call(service: service, text: text, fatal: quotaExceeded) {
      var req = URLRequest(url: try CloudHTTP.url(base, "/audio/speech", overrideEnv: "JGV_OPENAI_TTS_BASE", service: service), timeoutInterval: 120)
      req.httpMethod = "POST"
      req.setValue("Bearer \(try apiKey())", forHTTPHeaderField: "Authorization")
      req.setValue("application/json", forHTTPHeaderField: "Content-Type")
      req.httpBody = data
      return req
    }
  }

  /// 残高・上限が尽きた 429 は、待っても直らないのでやり直さない
  private static func quotaExceeded(_ r: CloudHTTP.Response) -> Bool {
    r.status == 429 && r.bodyText.contains("insufficient_quota")
  }

  /// jgv voices --openai (API を呼ばない。言語は文から自動で判断されるので、どの声もどの言語でも読める)
  static func voices() -> [(name: String, info: String)] {
    knownVoices.map { (name: $0.name, info: $0.onlyNew ? "gpt-4o-mini-tts" : "gpt-4o-mini-tts, tts-1, tts-1-hd") }
  }
}
