// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "StudyTimer",
  platforms: [.macOS(.v27)],
  targets: [
    .executableTarget(name: "StudyTimer")
  ]
)
