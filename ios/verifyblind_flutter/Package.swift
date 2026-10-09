// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "verifyblind_flutter",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "verifyblind-flutter", targets: ["verifyblind_flutter"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // The native SDK does all the work (key pair, network, decryption). This plugin only bridges it.
        .package(url: "https://github.com/VerifyBlind/sdk-ios", from: "2.3.1")
    ],
    targets: [
        .target(
            name: "verifyblind_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "VerifyBlind", package: "sdk-ios")
            ],
            resources: [
                // If your plugin requires a privacy manifest, for example if it uses any required
                // reason APIs, update the PrivacyInfo.xcprivacy file to describe your plugin's
                // privacy impact, and then uncomment these lines. For more information, see
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),

                // If you have other resources that need to be bundled with your plugin, refer to
                // the following instructions to add them:
                // https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package
            ]
        )
    ]
)
