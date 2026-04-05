import AppKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

@main
enum Main {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let opts = parseArgs(args) else {
            printUsage()
            exit(64)
        }

        let pdfURL = URL(fileURLWithPath: opts.pdfPath)
        guard let doc = PDFDocument(url: pdfURL) else {
            fputs("error: cannot open PDF at \(opts.pdfPath)\n", stderr)
            exit(1)
        }

        let pageIndex = opts.page1Based - 1
        guard pageIndex >= 0, pageIndex < doc.pageCount,
              let page = doc.page(at: pageIndex)
        else {
            fputs("error: page \(opts.page1Based) out of range (1…\(doc.pageCount))\n", stderr)
            exit(1)
        }

        let mediaBox = page.bounds(for: .mediaBox)
        let scale = opts.dpi / 72.0
        let pixelW = max(1, Int(ceil(mediaBox.width * scale)))
        let pixelH = max(1, Int(ceil(mediaBox.height * scale)))

        guard let cgImage = renderPage(page, pixelWidth: pixelW, pixelHeight: pixelH, scale: scale) else {
            fputs("error: render failed\n", stderr)
            exit(1)
        }

        if opts.toClipboard {
            guard copyPNGToPasteboard(cgImage: cgImage) else {
                fputs("error: clipboard write failed\n", stderr)
                exit(1)
            }
            print("ok: copied PNG to pasteboard (\(pixelW)×\(pixelH))")
            return
        }

        guard let outPath = opts.outputPath else {
            fputs("error: missing --out (or use --clipboard)\n", stderr)
            exit(64)
        }

        let outURL = URL(fileURLWithPath: outPath)
        let ext = outURL.pathExtension.lowercased()
        let utType: UTType = switch ext {
        case "jpg", "jpeg": .jpeg
        case "tiff", "tif": .tiff
        default: .png
        }

        guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, utType.identifier as CFString, 1, nil) else {
            fputs("error: cannot create image at \(outPath)\n", stderr)
            exit(1)
        }

        var props: [CFString: Any] = [:]
        if utType == .jpeg {
            props[kCGImageDestinationLossyCompressionQuality] = opts.jpegQuality
        }

        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            fputs("error: write failed\n", stderr)
            exit(1)
        }
    }

    private static func printUsage() {
        let msg = """
        usage:
          pdfpageexport --pdf <path> --page <1-based> --dpi <number> --out <path.png|jpg|tiff> [--jpeg-quality 0…1]
          pdfpageexport --pdf <path> --page <1-based> --dpi <number> --clipboard

        Rasterizes one PDF page with PDFKit. Use --clipboard to put PNG on the general pasteboard.
        """
        fputs("\(msg)\n", stderr)
    }

    struct Options {
        var pdfPath: String
        var page1Based: Int
        var dpi: CGFloat
        var outputPath: String?
        var toClipboard: Bool
        var jpegQuality: CGFloat = 0.92
    }

    private static func parseArgs(_ args: [String]) -> Options? {
        var pdfPath: String?
        var page: Int?
        var dpi: CGFloat?
        var out: String?
        var toClipboard = false
        var jpegQ: CGFloat = 0.92

        var i = args.startIndex
        while i < args.endIndex {
            let a = args[i]
            switch a {
            case "--pdf":
                guard i + 1 < args.endIndex else { return nil }
                pdfPath = args[args.index(after: i)]
                i = args.index(i, offsetBy: 2)
            case "--page":
                guard i + 1 < args.endIndex, let p = Int(args[args.index(after: i)]), p > 0 else { return nil }
                page = p
                i = args.index(i, offsetBy: 2)
            case "--dpi":
                guard i + 1 < args.endIndex, let d = Double(args[args.index(after: i)]), d > 0 else { return nil }
                dpi = CGFloat(d)
                i = args.index(i, offsetBy: 2)
            case "--out":
                guard i + 1 < args.endIndex else { return nil }
                out = args[args.index(after: i)]
                i = args.index(i, offsetBy: 2)
            case "--clipboard":
                toClipboard = true
                i = args.index(after: i)
            case "--jpeg-quality":
                guard i + 1 < args.endIndex, let q = Double(args[args.index(after: i)]), (0 ... 1).contains(q) else {
                    return nil
                }
                jpegQ = CGFloat(q)
                i = args.index(i, offsetBy: 2)
            default:
                return nil
            }
        }

        guard let pdfPath, let page, let dpi else { return nil }
        if toClipboard {
            return Options(pdfPath: pdfPath, page1Based: page, dpi: dpi, outputPath: nil, toClipboard: true, jpegQuality: jpegQ)
        }
        guard let out else { return nil }
        return Options(pdfPath: pdfPath, page1Based: page, dpi: dpi, outputPath: out, toClipboard: false, jpegQuality: jpegQ)
    }

    private static func copyPNGToPasteboard(cgImage: CGImage) -> Bool {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return false }

        let pb = NSPasteboard.general
        pb.clearContents()
        let pngOk = pb.setData(data as Data, forType: .png)

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        if let tiff = nsImage.tiffRepresentation {
            _ = pb.setData(tiff, forType: .tiff)
        }

        return pngOk
    }

    private static func renderPage(_ page: PDFPage, pixelWidth: Int, pixelHeight: Int, scale: CGFloat) -> CGImage? {
        let mediaBox = page.bounds(for: .mediaBox)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: 0, y: mediaBox.height)
        ctx.scaleBy(x: 1, y: -1)

        page.draw(with: .mediaBox, to: ctx)
        return ctx.makeImage()
    }
}
