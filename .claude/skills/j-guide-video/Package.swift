// swift-tools-version: 6.0
// j-guide-video: 手順書から、ナレーションに同期したイラストの手順動画を作る (macOS 専用)。
//   jgv        … CLI (new / dev / check / tts / snapshots / render など。一覧は jgv --help)
//   JGVCore    … 描画 DSL (CoreGraphics)・アニメーションの計算・timeline の型
//   JGVKit     … ナレーション同期のフックと、ガイドレイアウトの部品 (人物・道具・画面・シーンの型)
//   JGVRender  … 動画 (AVAssetWriter)・静止画の書き出し。動画プロジェクトの実行ファイルの入口
//   JGVTools   … 台本・音声・timeline・字幕などの処理
// 動画プロジェクト (jgv init で作る) には kit を置かない。jgv がキャッシュに作るビルド用のパッケージから JGVCore / JGVKit / JGVRender を参照する
import PackageDescription

let package = Package(
  name: "j-guide-video",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "jgv", targets: ["jgv"]),
    .library(name: "JGVKit", targets: ["JGVCore", "JGVKit", "JGVRender"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
  ],
  targets: [
    .target(name: "JGVCore"),
    .target(name: "JGVKit", dependencies: ["JGVCore"]),
    .target(name: "JGVRender", dependencies: ["JGVCore", "JGVKit"]),
    .target(name: "JGVTools", dependencies: ["JGVCore"]),
    .executableTarget(
      name: "jgv",
      dependencies: ["JGVTools", "JGVRender", .product(name: "ArgumentParser", package: "swift-argument-parser")]
    ),
    // 単体テスト (swift test)。解析・検証・キャッシュの掃除の安全を確かめる
    .testTarget(name: "JGVCoreTests", dependencies: ["JGVCore"]),
    .testTarget(name: "JGVKitTests", dependencies: ["JGVKit"]),
    .testTarget(name: "JGVToolsTests", dependencies: ["JGVTools"]),
  ],
  swiftLanguageModes: [.v5]
)
