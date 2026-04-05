import ApplicationServices
import AppKit
import Foundation

/// Dumps a shallow Accessibility tree for the frontmost Preview window (or any frontmost app if --any).
/// Grant "Accessibility" permission for Terminal/your IDE when prompted.
/// Run: swift run preview_ax_dump
///      swift run preview_ax_dump --any
@main
enum PreviewAXDumpMain {
    static func main() {
        let anyApp = CommandLine.arguments.contains("--any")

        guard let app = NSWorkspace.shared.frontmostApplication else {
            fputs("error: no frontmost application\n", stderr)
            exit(1)
        }

        if !anyApp, app.bundleIdentifier != "com.apple.Preview" {
            fputs("error: frontmost app is \(app.localizedName ?? "?"), not Preview. Use --any to dump anyway.\n", stderr)
            exit(1)
        }

        let pid = app.processIdentifier
        let appEl = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        var wErr = AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &windowRef)
        if wErr != .success || windowRef == nil {
            windowRef = nil
            wErr = AXUIElementCopyAttributeValue(appEl, kAXMainWindowAttribute as CFString, &windowRef)
        }
        if wErr != .success {
            if wErr.rawValue == -25211 {
                fputs(
                    "error: AX API disabled or denied (-25211). Enable Accessibility for this app in\n  System Settings > Privacy & Security > Accessibility\n",
                    stderr
                )
            } else {
                fputs("error: AX window: \(wErr.rawValue)\n", stderr)
            }
            exit(1)
        }
        guard let window = windowRef else {
            fputs("error: no window from AX\n", stderr)
            exit(1)
        }

        print("AX dump for \(app.localizedName ?? "app") pid=\(pid)")
        print(String(repeating: "=", count: 60))
        dumpElement(window as! AXUIElement, depth: 0, maxDepth: 5, maxChildren: 24)
    }

    private static func dumpElement(_ el: AXUIElement, depth: Int, maxDepth: Int, maxChildren: Int) {
        guard depth <= maxDepth else { return }
        let indent = String(repeating: "  ", count: depth)

        let role = copyStringAttr(el, kAXRoleAttribute as CFString) ?? "?"
        let title = copyStringAttr(el, kAXTitleAttribute as CFString)
        let value = copyStringAttr(el, kAXValueAttribute as CFString)
        let desc = copyStringAttr(el, kAXDescriptionAttribute as CFString)

        var parts: [String] = ["[\(role)]"]
        if let title, !title.isEmpty { parts.append("title=\"\(title.prefix(120))\"") }
        if let value, !value.isEmpty { parts.append("value=\"\(value.prefix(120))\"") }
        if let desc, !desc.isEmpty { parts.append("desc=\"\(desc.prefix(80))\"") }

        print("\(indent)\(parts.joined(separator: " "))")

        guard depth < maxDepth else { return }

        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &children) == .success,
              let kids = children as? [AXUIElement]
        else { return }

        for child in kids.prefix(maxChildren) {
            dumpElement(child, depth: depth + 1, maxDepth: maxDepth, maxChildren: maxChildren)
        }
        if kids.count > maxChildren {
            print("\(indent)  … \(kids.count - maxChildren) more children")
        }
    }

    private static func copyStringAttr(_ el: AXUIElement, _ name: CFString) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name, &ref) == .success else { return nil }
        if let s = ref as? String { return s }
        if let n = ref as? NSNumber { return n.stringValue }
        return nil
    }
}
