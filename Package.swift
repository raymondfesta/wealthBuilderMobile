// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FinancialAnalyzer",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "FinancialAnalyzer",
            targets: ["FinancialAnalyzer"])
    ],
    dependencies: [
        .package(url: "https://github.com/plaid/plaid-link-ios", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "FinancialAnalyzer",
            dependencies: [
                .product(name: "LinkKit", package: "plaid-link-ios")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "FinancialAnalyzerTests",
            dependencies: ["FinancialAnalyzer"],
            path: "Tests"
        )
    ]
)
