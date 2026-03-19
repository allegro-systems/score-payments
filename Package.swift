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
        .package(path: "../../score"),
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
