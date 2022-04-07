// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.



import PackageDescription

let package = Package(
    name: "SwiftKueryODBCSQL",
    products: [
        .library(
            name: "SwiftKueryODBCSQL",
            targets: ["SwiftKueryODBCSQL"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Andrew-Lees11/CunixODBC.git", from: "0.0.1"),
        .package(url: "https://github.com/Kitura/Swift-Kuery.git", .upToNextMajor(from: "4.0.0")),
        ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        
        .target(
            name: "SwiftKueryODBCSQL",
            dependencies: ["CunixODBC","SwiftKuery"]
        ),
        .testTarget(
            name: "SwiftKueryODBCSQLTests",
            dependencies: ["SwiftKueryODBCSQL"]
        )
    ]
)
