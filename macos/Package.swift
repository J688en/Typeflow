// swift-tools-version: 5.9
// TypeFlow — Swift Package Manager build descriptor
//
// Build with:
//   swift build -c release
//
// Or open in Xcode:
//   open Package.swift
//
// NOTE: For a distributable .app bundle with proper assets, code signing,
// and entitlements, use the Xcode project (TypeFlow.xcodeproj) instead.
// The SPM build is useful for CI validation and quick development iterations.
// See README.md for full build and DMG creation instructions.
//
// IMPORTANT: Building with SPM will NOT bundle Assets.xcassets or apply
// the TypeFlow.entitlements file. Use Xcode for a proper .app build.

import PackageDescription

let package = Package(
    name: "TypeFlow",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TypeFlow", targets: ["TypeFlow"])
    ],
    targets: [
        .executableTarget(
            name: "TypeFlow",
            path: "TypeFlow/Sources/TypeFlow"
            // Note: Assets.xcassets and entitlements are Xcode-specific.
            // For SPM builds, the app runs without a custom icon.
        )
    ]
)
