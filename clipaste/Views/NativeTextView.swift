import SwiftUI
import AppKit

struct NativeTextView: NSViewRepresentable {
    enum Style {
        case plain
        case code
    }

    var text: String
    var attributedText: NSAttributedString?
    var style: Style = .plain

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        // 传统滚动条固定预留宽度，避免显隐触发反复换行；覆盖式滚动条仍由系统控制显示。
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = false

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        // 核心配置：只读、可选中
        textView.isEditable = false
        textView.isSelectable = true

        // 长文本只按需排版；非连续布局仍在主线程执行。
        textView.layoutManager?.allowsNonContiguousLayout = true

        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )

        configureTextView(textView, coordinator: context.coordinator)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        configureTextView(textView, coordinator: context.coordinator)
    }

    private func configureTextView(_ textView: NSTextView, coordinator: Coordinator) {
        let inset = NSSize(
            width: style == .code ? 16 : 20,
            height: style == .code ? 14 : 20
        )
        if textView.textContainerInset != inset {
            textView.textContainerInset = inset
        }

        // SwiftUI 的尺寸和外观更新不应重置全文、选区或滚动位置。
        if let attrText = attributedText {
            if coordinator.attributedText?.isEqual(to: attrText) != true {
                textView.textStorage?.setAttributedString(attrText)
                coordinator.attributedText = attrText
                coordinator.text = nil
            }
        } else if coordinator.attributedText != nil || coordinator.text != text {
            // 纯文本降级模式
            textView.font = .systemFont(ofSize: 14, weight: .regular)
            textView.textColor = NSColor.labelColor
            textView.string = text
            coordinator.text = text
            coordinator.attributedText = nil
        }
        applyBackgroundStyle(to: textView)
    }

    private func applyBackgroundStyle(to textView: NSTextView) {
        guard style == .code else {
            textView.drawsBackground = false
            textView.backgroundColor = .clear
            return
        }

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        textView.drawsBackground = true
        textView.backgroundColor = isDark
            ? NSColor(red: 0.17, green: 0.18, blue: 0.23, alpha: 1.0)
            : NSColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
    }

    final class Coordinator {
        var text: String?
        var attributedText: NSAttributedString?
    }
}
