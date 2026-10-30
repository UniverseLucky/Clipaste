import AppKit
import Observation
import SwiftUI

@main
@MainActor
enum NativeTextViewLayoutTests {
    private static let feedback = """
    提个使用反馈啊
    那个小说的页面，我看你现在触控区其实是左中右，左边上一页，中间菜单，右边下一页。
    如果开了单手模式，就是左右翻页，中间是菜单。
    但是其实菜单区域应该不需要那么大，我看香色闺阁还有阅读这种，他们都是把屏幕拆成9宫格。单手的时候只有正中间的那个格子是菜单，其他地方都是翻页，这样操作就会比较跟手一点，随便点哪里都能翻页。现在云书阁我经常点了不翻页，有种不丝滑的感觉
    """

    static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        _ = NSScroller.preferredScrollerStyle
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        switch CommandLine.arguments.dropFirst().first {
        case "updates":
            verifyUnchangedContent()
        case "layout":
            verifyScrollBoundary()
        case "content":
            verifyContentTransitions()
        default:
            verifyScrollBoundary()
            verifyUnchangedContent()
            verifyContentTransitions()
        }
        print("原生文本预览回归验证通过")
    }

    private static func verifyScrollBoundary() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        let richText = NSAttributedString(string: feedback, attributes: [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .paragraphStyle: paragraph
        ])

        for scrollerStyle in [NSScroller.Style.legacy, .overlay] {
            let preview = PreviewHarness(text: "短文本")
            defer { preview.window.orderOut(nil) }
            preview.scrollView.scrollerStyle = scrollerStyle
            preview.flush()
            let shortTextWidth = preview.scrollView.contentSize.width

            preview.state.text = feedback
            preview.state.attributedText = richText
            preview.flush()
            precondition(
                abs(preview.scrollView.contentSize.width - shortTextWidth) < 0.5,
                "内容变长并出现滚动条时，文本可用宽度必须保持稳定"
            )

            for width in [400.0, 500.0, 700.0] {
                preview.resize(width: width, height: 180)
                let contentHeight = ceil(
                    preview.layoutManager.usedRect(for: preview.textContainer).height
                        + preview.textView.textContainerInset.height * 2
                )
                let contentWidth = preview.scrollView.contentSize.width

                // 在真实排版高度上下逐像素调整，覆盖刚好需要滚动的临界位置。
                for offset in [-2.0, -1, 0, 1, 2] {
                    preview.resize(width: width, height: contentHeight + offset)
                    precondition(abs(preview.scrollView.contentSize.width - contentWidth) < 0.5)
                    precondition(abs(preview.textView.frame.width - contentWidth) < 0.5)
                    precondition(preview.textView.string == feedback)
                    let settledFrame = preview.textView.frame
                    preview.flush()
                    precondition(preview.textView.frame == settledFrame, "文本尺寸必须收敛")
                }
            }
        }
        print("通过：传统及覆盖式滚动条的临界布局")
    }

    private static func verifyUnchangedContent() {
        let text = String(repeating: feedback + "\n", count: 30)
        for richText in [nil, NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 18)])] {
            let preview = PreviewHarness(text: text, attributedText: richText)
            defer { preview.window.orderOut(nil) }
            let edits = TextEditCounter()
            preview.textView.textStorage?.delegate = edits
            preview.textView.setSelectedRange(NSRange(location: 5, length: 8))
            preview.scrollView.contentView.scroll(to: NSPoint(x: 0, y: 200))
            preview.scrollView.reflectScrolledClipView(preview.scrollView.contentView)
            preview.flush()
            edits.count = 0
            let selectedRange = preview.textView.selectedRange()
            let scrollOrigin = preview.scrollView.contentView.bounds.origin

            for scheme in [ColorScheme.dark, .light, .dark] {
                preview.state.colorScheme = scheme
                preview.flush()
            }
            precondition(edits.count == 0, "外观更新不得重新写入相同文本")
            precondition(preview.textView.selectedRange() == selectedRange, "外观更新不得重置选区")
            precondition(preview.scrollView.contentView.bounds.origin == scrollOrigin, "外观更新不得重置滚动位置")

            preview.state.style = .code
            preview.flush()
            precondition(edits.count == 0, "切换预览样式不得重新写入相同文本")
        }
        print("通过：更新外观和样式时保留全文、选区及滚动位置")
    }

    private static func verifyContentTransitions() {
        let preview = PreviewHarness(text: "")
        defer { preview.window.orderOut(nil) }
        precondition(preview.textView.string.isEmpty)

        let longText = String(repeating: "长文本 👩🏽‍💻 é，验证完整内容及滚动。\n", count: 2_000)
        preview.state.text = longText
        preview.flush()
        precondition(preview.textView.string == longText, "长文本不得丢失或截断")
        let lastCharacter = (longText as NSString).length - 2
        preview.textView.scrollRangeToVisible(NSRange(location: lastCharacter, length: 1))
        preview.flush()
        let lastGlyph = preview.layoutManager.glyphIndexForCharacter(at: lastCharacter)
        let lastRect = preview.layoutManager.boundingRect(
            forGlyphRange: NSRange(location: lastGlyph, length: 1),
            in: preview.textContainer
        ).offsetBy(
            dx: preview.textView.textContainerOrigin.x,
            dy: preview.textView.textContainerOrigin.y
        )
        precondition(preview.textView.visibleRect.intersects(lastRect), "必须能够滚动到最后一个字符")

        let font = NSFont.boldSystemFont(ofSize: 22)
        preview.state.attributedText = NSAttributedString(string: feedback, attributes: [.font: font])
        preview.flush()
        precondition(preview.textView.string == feedback)
        guard let richFont = preview.textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont else {
            preconditionFailure("富文本字体不得丢失")
        }
        // 中文排版可能替换为系统后备字体，字号及粗体语义仍须保留。
        precondition(richFont.pointSize == font.pointSize)
        precondition(richFont.fontDescriptor.symbolicTraits.contains(.bold))

        preview.state.text = feedback
        preview.state.attributedText = nil
        preview.flush()
        precondition(preview.textView.string == feedback)
        precondition(preview.textView.font?.pointSize == 14)
        precondition(preview.textView.font?.fontDescriptor.symbolicTraits.contains(.bold) == false)
        preview.state.text = ""
        preview.flush()
        precondition(preview.textView.string.isEmpty)
        print("通过：空文本、长文本、富文本及纯文本切换")
    }
}

@Observable
@MainActor
private final class PreviewState {
    var text: String
    var attributedText: NSAttributedString?
    var style: NativeTextView.Style = .plain
    var colorScheme: ColorScheme = .light
    var width: CGFloat = 500
    var height: CGFloat = 180

    init(text: String, attributedText: NSAttributedString?) {
        self.text = text
        self.attributedText = attributedText
    }
}

private struct PreviewHarnessView: View {
    let state: PreviewState

    var body: some View {
        NativeTextView(text: state.text, attributedText: state.attributedText, style: state.style)
            .frame(width: state.width, height: state.height)
            .environment(\.colorScheme, state.colorScheme)
    }
}

@MainActor
private final class PreviewHarness {
    let state: PreviewState
    let host: NSHostingView<PreviewHarnessView>
    let window: NSWindow
    let scrollView: NSScrollView
    let textView: NSTextView
    let layoutManager: NSLayoutManager
    let textContainer: NSTextContainer

    init(text: String, attributedText: NSAttributedString? = nil) {
        let state = PreviewState(text: text, attributedText: attributedText)
        let host = NSHostingView(rootView: PreviewHarnessView(state: state))
        let window = NSWindow(
            contentRect: NSRect(x: -2_000, y: -2_000, width: 500, height: 180),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.contentView = host
        window.orderBack(nil)
        host.layoutSubtreeIfNeeded()
        guard let scrollView = Self.descendants(of: host).compactMap({ $0 as? NSScrollView }).first,
              let textView = scrollView.documentView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            preconditionFailure("无法创建原生文本预览")
        }
        self.state = state
        self.host = host
        self.window = window
        self.scrollView = scrollView
        self.textView = textView
        self.layoutManager = layoutManager
        self.textContainer = textContainer
        flush()
    }

    func resize(width: CGFloat, height: CGFloat) {
        state.width = width
        state.height = height
        window.setContentSize(NSSize(width: width, height: height))
        flush()
    }

    func flush() {
        host.layoutSubtreeIfNeeded()
        layoutManager.ensureLayout(for: textContainer)
        textView.displayIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        host.layoutSubtreeIfNeeded()
        layoutManager.ensureLayout(for: textContainer)
    }

    private static func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}

private final class TextEditCounter: NSObject, NSTextStorageDelegate {
    var count = 0

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        count += 1
    }
}
