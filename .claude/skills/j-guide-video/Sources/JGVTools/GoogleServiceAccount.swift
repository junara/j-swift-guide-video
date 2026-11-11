// Google Cloud のサービスアカウントの鍵 (JSON) で、Google TTS 用のアクセストークンを取る。
// 環境変数 GOOGLE_APPLICATION_CREDENTIALS に鍵のファイルのパスを入れると使う (GOOGLE_TTS_API_KEY があればそちらが先)。
// 鍵で署名した JWT (RS256) を OAuth のトークンに交換し、期限 (1 時間) の少し前まで使い回す。gcloud は要らない
import Foundation
import Security

enum GoogleServiceAccount {
  static let credentialsEnv = "GOOGLE_APPLICATION_CREDENTIALS"
  static let service = "Google OAuth (サービスアカウント)"
  /// JWT の aud とトークンの送り先。鍵の token_uri は使わない (他人の鍵ファイルに仕込まれた値で、署名した JWT が外のサーバーに送られないように)
  static let tokenURL = "https://oauth2.googleapis.com/token"
  static let scope = "https://www.googleapis.com/auth/cloud-platform"

  struct Key {
    let path: String
    let clientEmail: String
    let keyID: String
    let privateKey: SecKey
  }

  private static let lock = NSLock()
  nonisolated(unsafe) private static var cachedKey: Key?
  /// 取ったトークン。どの鍵で取ったかも持つ (鍵が変わったら使い回さない)
  nonisolated(unsafe) private static var token: (path: String, value: String, expires: Date)?
  nonisolated(unsafe) private static var announced: Set<String> = []

  /// 環境変数が指す鍵を読む (同じパスなら 1 回だけ読む)。環境変数が無ければ nil
  static func key() throws -> Key? {
    let path = CloudHTTP.env(credentialsEnv)
    if path.isEmpty { return nil }
    lock.lock()
    defer { lock.unlock() }
    if let k = cachedKey, k.path == path { return k }
    let k = try load(path)
    cachedKey = k
    return k
  }

  static func load(_ path: String) throws -> Key {
    let where_ = "\(credentialsEnv) の鍵 (\(path))"
    guard let data = FileManager.default.contents(atPath: (path as NSString).expandingTildeInPath) else {
      throw ToolError("\(where_) を読めませんでした。サービスアカウントの鍵 (JSON) のファイルのパスを書いてください")
    }
    guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
      throw ToolError("\(where_) が JSON ではありません")
    }
    let type = obj["type"] as? String ?? ""
    guard type == "service_account" else {
      throw ToolError("\(where_) はサービスアカウントの鍵ではありません (type: \(type.isEmpty ? "なし" : type))。"
        + "gcloud auth application-default login で作った認証情報などは使えません。サービスアカウントの鍵 (JSON) か、API キー (GOOGLE_TTS_API_KEY) を使ってください")
    }
    guard let email = obj["client_email"] as? String, !email.isEmpty, let pem = obj["private_key"] as? String, !pem.isEmpty else {
      throw ToolError("\(where_) に client_email か private_key がありません")
    }
    return Key(path: path, clientEmail: email, keyID: obj["private_key_id"] as? String ?? "", privateKey: try privateKey(pem, where_))
  }

  /// PEM (PKCS#8 の BEGIN PRIVATE KEY か、PKCS#1 の BEGIN RSA PRIVATE KEY) から RSA の秘密鍵を作る
  static func privateKey(_ pem: String, _ where_: String) throws -> SecKey {
    let pkcs8 = pem.contains("BEGIN PRIVATE KEY")
    let body = pem.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty && !$0.hasPrefix("-----") }.joined()
    guard var der = Data(base64Encoded: body) else { throw ToolError("\(where_) の private_key を読めませんでした (PEM ではありません)") }
    if pkcs8 {
      guard let inner = pkcs1(fromPKCS8: [UInt8](der)) else { throw ToolError("\(where_) の private_key を読めませんでした (RSA の鍵ではありません)") }
      der = Data(inner)
    }
    let attrs: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPrivate]
    var err: Unmanaged<CFError>?
    guard let k = SecKeyCreateWithData(der as CFData, attrs as CFDictionary, &err) else {
      throw ToolError("\(where_) の private_key を読めませんでした: \(err?.takeRetainedValue().localizedDescription ?? "")")
    }
    return k
  }

  /// DER の要素を 1 つ読む: (タグ, 中身の始まり, 中身の終わり)
  private static func tlv(_ b: [UInt8], _ i: Int) -> (tag: UInt8, start: Int, end: Int)? {
    guard i + 1 < b.count else { return nil }
    var p = i + 1
    var len = Int(b[p]); p += 1
    if len & 0x80 != 0 {
      let n = len & 0x7f
      guard n >= 1, n <= 4, p + n <= b.count else { return nil }
      len = 0
      for _ in 0..<n { len = len << 8 | Int(b[p]); p += 1 }
    }
    guard p + len <= b.count else { return nil }
    return (b[i], p, p + len)
  }

  /// PKCS#8 (SEQUENCE { INTEGER, SEQUENCE { OID, … }, OCTET STRING { PKCS#1 } }) から PKCS#1 の RSA の鍵を取り出す
  static func pkcs1(fromPKCS8 b: [UInt8]) -> [UInt8]? {
    guard let outer = tlv(b, 0), outer.tag == 0x30 else { return nil }
    guard let version = tlv(b, outer.start), version.tag == 0x02,
          let algo = tlv(b, version.end), algo.tag == 0x30,
          let oid = tlv(b, algo.start), oid.tag == 0x06,
          let octets = tlv(b, algo.end), octets.tag == 0x04 else { return nil }
    // 1.2.840.113549.1.1.1 (rsaEncryption)
    guard Array(b[oid.start..<oid.end]) == [0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01] else { return nil }
    return Array(b[octets.start..<octets.end])
  }

  private static func base64url(_ d: Data) -> String {
    d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
  }

  /// 鍵で署名した JWT (RS256)
  static func assertion(_ k: Key, now: Date = Date()) throws -> String {
    var header: [String: Any] = ["alg": "RS256", "typ": "JWT"]
    if !k.keyID.isEmpty { header["kid"] = k.keyID }
    let iat = Int(now.timeIntervalSince1970)
    let claims: [String: Any] = ["iss": k.clientEmail, "scope": scope, "aud": tokenURL, "iat": iat, "exp": iat + 3600]
    let input = base64url(try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys, .withoutEscapingSlashes])) + "."
      + base64url(try JSONSerialization.data(withJSONObject: claims, options: [.sortedKeys, .withoutEscapingSlashes]))
    var err: Unmanaged<CFError>?
    guard let sig = SecKeyCreateSignature(k.privateKey, .rsaSignatureMessagePKCS1v15SHA256, Data(input.utf8) as CFData, &err) else {
      throw ToolError("\(credentialsEnv) の鍵で署名できませんでした: \(err?.takeRetainedValue().localizedDescription ?? "")")
    }
    return input + "." + base64url(sig as Data)
  }

  /// アクセストークン。期限の 5 分前までは使い回す (並列の合成で何度も取り直さないように、取る間はロックする)
  static func accessToken(_ k: Key) throws -> String {
    lock.lock()
    defer { lock.unlock() }
    if let t = token, t.path == k.path, t.expires.timeIntervalSinceNow > 300 { return t.value }
    var form = URLComponents()
    form.queryItems = [
      URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:jwt-bearer"),
      URLQueryItem(name: "assertion", value: try assertion(k)),
    ]
    let body = Data((form.percentEncodedQuery ?? "").utf8)
    let data: Data
    do {
      data = try CloudHTTP.call(service: service) {
        let base = String(tokenURL.dropLast("/token".count))
        var req = URLRequest(url: try CloudHTTP.url(base, "/token", overrideEnv: "JGV_GOOGLE_TOKEN_BASE", service: service), timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return req
      }
    } catch let e as ToolError where e.message.contains("invalid_grant") {
      // 鍵が無効 (消した・止めた)、鍵とメールの組が違う、このマシンの時計がずれている、のどれか
      throw ToolError("\(e.message) (\(k.clientEmail)。鍵が削除・無効になっていないか、このマシンの時計が合っているかを確かめてください)")
    }
    let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    guard let value = obj?["access_token"] as? String, !value.isEmpty else {
      throw ToolError("\(service) の応答にアクセストークンがありませんでした (\(k.clientEmail))")
    }
    let ttl = (obj?["expires_in"] as? NSNumber)?.doubleValue ?? 3600
    token = (k.path, value, Date().addingTimeInterval(ttl))
    // ほかの用途で GOOGLE_APPLICATION_CREDENTIALS を入れたままのとき、気づかずにそのプロジェクトに料金がかからないように、どのアカウントで呼ぶかを 1 回だけ伝える
    if announced.insert(k.path).inserted {
      FileHandle.standardError.write("WARN: Google TTS をサービスアカウント \(k.clientEmail) (\(credentialsEnv)) で呼びます。料金はこのアカウントのプロジェクトにかかります\n".data(using: .utf8)!)
    }
    return value
  }
}
