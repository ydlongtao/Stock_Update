import AppKit
import Foundation

struct WidgetPayload: Decodable {
    struct SymbolRow: Decodable {
        let symbol: String
        let price: String
        let change_pct: String
        let signal: String
        let signal_class: String
    }

    let generated_at: String
    let date: String
    let title: String
    let overall_signal: String
    let overall_signal_class: String
    let summary: String
    let report_path: String
    let symbols: [SymbolRow]
}

final class WidgetView: NSView {
    private let stack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "US ETF Signal")
    private let signalLabel = NSTextField(labelWithString: "Loading")
    private let timeLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let rowsStack = NSStackView()
    private var reportPath = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        layer?.borderWidth = 1

        stack.orientation = .vertical
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        signalLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        signalLabel.alignment = .center
        signalLabel.wantsLayer = true
        signalLabel.layer?.cornerRadius = 8
        signalLabel.maximumNumberOfLines = 1
        signalLabel.lineBreakMode = .byTruncatingTail

        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = .secondaryLabelColor
        summaryLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        summaryLabel.textColor = .labelColor
        summaryLabel.maximumNumberOfLines = 3
        summaryLabel.lineBreakMode = .byTruncatingTail

        rowsStack.orientation = .vertical
        rowsStack.spacing = 6

        let header = NSStackView(views: [titleLabel, timeLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fill
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)

        stack.addArrangedSubview(header)
        stack.addArrangedSubview(signalLabel)
        stack.addArrangedSubview(rowsStack)
        stack.addArrangedSubview(summaryLabel)

        let click = NSClickGestureRecognizer(target: self, action: #selector(openReport))
        addGestureRecognizer(click)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(_ payload: WidgetPayload) {
        reportPath = payload.report_path
        titleLabel.stringValue = payload.title
        signalLabel.stringValue = payload.overall_signal.uppercased()
        signalLabel.textColor = color(for: payload.overall_signal_class)
        signalLabel.layer?.backgroundColor = color(for: payload.overall_signal_class).withAlphaComponent(0.14).cgColor
        timeLabel.stringValue = shortTime(payload.generated_at)
        summaryLabel.stringValue = payload.summary

        rowsStack.arrangedSubviews.forEach { view in
            rowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for row in payload.symbols {
            rowsStack.addArrangedSubview(symbolRow(row))
        }
    }

    func renderError(_ message: String) {
        titleLabel.stringValue = "US ETF Signal"
        signalLabel.stringValue = "NO DATA"
        signalLabel.textColor = color(for: "observe")
        signalLabel.layer?.backgroundColor = color(for: "observe").withAlphaComponent(0.14).cgColor
        timeLabel.stringValue = ""
        summaryLabel.stringValue = message
    }

    private func symbolRow(_ row: WidgetPayload.SymbolRow) -> NSView {
        let symbol = NSTextField(labelWithString: row.symbol)
        symbol.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        symbol.widthAnchor.constraint(equalToConstant: 48).isActive = true

        let price = NSTextField(labelWithString: row.price)
        price.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        price.alignment = .right

        let change = NSTextField(labelWithString: row.change_pct)
        change.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        change.textColor = color(for: row.signal_class)
        change.alignment = .right
        change.widthAnchor.constraint(equalToConstant: 64).isActive = true

        let stack = NSStackView(views: [symbol, price, change])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.distribution = .fill
        return stack
    }

    private func color(for signalClass: String) -> NSColor {
        switch signalClass {
        case "positive":
            return NSColor.systemGreen
        case "negative":
            return NSColor.systemRed
        case "neutral":
            return NSColor.systemGray
        default:
            return NSColor.systemBlue
        }
    }

    private func shortTime(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else {
            return value.prefix(16).description
        }
        let display = DateFormatter()
        display.dateFormat = "MM/dd HH:mm"
        return display.string(from: date)
    }

    @objc private func openReport() {
        guard !reportPath.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: reportPath))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let widget = WidgetView(frame: NSRect(x: 0, y: 0, width: 320, height: 430))
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        window = NSWindow(
            contentRect: NSRect(x: 80, y: 520, width: 320, height: 430),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = widget
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)

        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.reload()
        }
    }

    private func reload() {
        let path = CommandLine.arguments.dropFirst().first
            ?? ProcessInfo.processInfo.environment["STOCK_SIGNAL_WIDGET_JSON"]
            ?? defaultWidgetPath()
        let url = URL(fileURLWithPath: path)
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(WidgetPayload.self, from: data)
            widget.render(payload)
        } catch {
            widget.renderError("Waiting for data at \(path)")
        }
    }

    private func defaultWidgetPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Documents/Stock_Update/data/latest_signal_widget.json"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
