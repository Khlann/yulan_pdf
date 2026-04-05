// swift-tools-version: 5.9
import PackageDescription

// 页览 (Yulan) — SPM 包名与目录 yulan_pdf 一致
let package = Package(
    name: "yulan_pdf",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "pdfpageexport",
            path: "Sources/pdfpageexport"
        ),
        .executableTarget(
            name: "preview_ax_dump",
            path: "Sources/preview_ax_dump"
        ),
    ]
)
