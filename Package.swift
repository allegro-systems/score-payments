// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ScorePayments",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ScorePayments", targets: ["ScorePayments"]),
    ],
    dependencies: [
        .package(url: "https://github.com/allegro-systems/score.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "ScorePayments",
            dependencies: [
                .product(name: "Score", package: "Score"),
                .product(name: "ScoreData", package: "Score"),
            ]
        ),
        .testTarget(
            name: "ScorePaymentsTests",
            dependencies: ["ScorePayments"]
        ),
    ]
)
