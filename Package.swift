// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "StudyTimer",
  platforms: [.macOS(.v27)],
  targets: [
    .executableTarget(name: "StudyTimer"),
    .testTarget(
      name: "StudyTimerTests",
      dependencies: ["StudyTimer"],
      swiftSettings: [
        // The default build system does not load the Swift Testing macro plugin from the Command Line Tools.
        .unsafeFlags([
          "-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing",
        ])
      ]
    ),
  ]
)
