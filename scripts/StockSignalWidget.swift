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
    private static let side: CGFloat = 200

    private let stack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "US ETF Signal")
    private let signalLabel = NSTextField(labelWithString: "Loading")
    private let timeLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let gridStack = NSStackView()
    private var reportPath = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        layer?.borderWidth = 1

        stack.orientation = .vertical
        stack.spacing = 5
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        signalLabel.font = NSFont.systemFont(ofSize: 13.5, weight: .bold)
        signalLabel.alignment = .center
        signalLabel.wantsLayer = true
        signalLabel.layer?.cornerRadius = 5
        signalLabel.maximumNumberOfLines = 1
        signalLabel.lineBreakMode = .byTruncatingTail

        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        timeLabel.textColor = .secondaryLabelColor
        summaryLabel.font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        summaryLabel.textColor = .labelColor
        summaryLabel.maximumNumberOfLines = 2
        summaryLabel.lineBreakMode = .byWordWrapping
        summaryLabel.cell?.wraps = true
        summaryLabel.cell?.isScrollable = false
        summaryLabel.cell?.usesSingleLineMode = false
        summaryLabel.preferredMaxLayoutWidth = 188
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.heightAnchor.constraint(equalToConstant: 34).isActive = true

        gridStack.orientation = .horizontal
        gridStack.spacing = 4
        gridStack.distribution = .fillEqually
        gridStack.alignment = .top
        gridStack.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView(views: [titleLabel, timeLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fill
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)

        stack.addArrangedSubview(header)
        stack.addArrangedSubview(signalLabel)
        stack.addArrangedSubview(gridStack)
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

        gridStack.arrangedSubviews.forEach { view in
            gridStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let columns = [NSStackView(), NSStackView()]
        for column in columns {
            column.orientation = .vertical
            column.spacing = 2
            column.distribution = .fillEqually
            column.alignment = .leading
            gridStack.addArrangedSubview(column)
        }

        for (index, row) in payload.symbols.enumerated() {
            columns[index % 2].addArrangedSubview(symbolTile(row))
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

    private func symbolTile(_ row: WidgetPayload.SymbolRow) -> NSView {
        let symbol = NSTextField(labelWithString: row.symbol)
        symbol.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .bold)
        symbol.textColor = color(for: row.signal_class)

        let value = NSTextField(labelWithString: "\(row.price) \(row.change_pct)")
        value.font = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular)
        value.textColor = .labelColor
        value.lineBreakMode = .byTruncatingTail
        value.maximumNumberOfLines = 1

        let stack = NSStackView(views: [symbol, value])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading
        stack.distribution = .fill
        stack.widthAnchor.constraint(equalToConstant: 90).isActive = true
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
    private let widget = WidgetView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
    private var timer: Timer?
    private var isUpdating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        window = NSWindow(
            contentRect: NSRect(x: 80, y: 670, width: 200, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = widget
        window.minSize = NSSize(width: 200, height: 200)
        window.maxSize = NSSize(width: 200, height: 200)
        window.contentMinSize = NSSize(width: 200, height: 200)
        window.contentMaxSize = NSSize(width: 200, height: 200)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)

        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.reload()
        }
    }

    private func reload() {
        maybeRunDailyUpdate()
        let path = widgetJSONPath()
        let url = URL(fileURLWithPath: path)
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(WidgetPayload.self, from: data)
            widget.render(payload)
        } catch {
            widget.renderError("Waiting for data at \(path)")
        }
    }

    private func widgetJSONPath() -> String {
        return CommandLine.arguments.dropFirst().first
            ?? ProcessInfo.processInfo.environment["STOCK_SIGNAL_WIDGET_JSON"]
            ?? defaultWidgetPath()
    }

    private func projectRootPath() -> String {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.count >= 2 {
            return args[1]
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Documents/Stock_Update"
    }

    private func pythonPath() -> String {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.count >= 3 {
            return args[2]
        }
        return "/usr/bin/python3"
    }

    private func maybeRunDailyUpdate() {
        if isUpdating {
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        guard (2...6).contains(weekday), hour >= 9 else {
            return
        }

        let marker = URL(fileURLWithPath: projectRootPath())
            .appendingPathComponent("data/.last_widget_daily_update")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: now)
        if let markerText = try? String(contentsOf: marker, encoding: .utf8),
           markerText.trimmingCharacters(in: .whitespacesAndNewlines) == today {
            return
        }
        if payloadDate() == today {
            writeDailyMarker(today, to: marker)
            return
        }

        isUpdating = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.pythonPath())
            process.arguments = [
                "\(self.projectRootPath())/scripts/generate_report.py"
            ]
            process.currentDirectoryURL = URL(fileURLWithPath: self.projectRootPath())
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    self.writeDailyMarker(today, to: marker)
                }
            } catch {
                // Keep the widget alive; the next timer tick can retry.
            }
            DispatchQueue.main.async {
                self.isUpdating = false
                self.reload()
            }
        }
    }

    private func payloadDate() -> String? {
        let url = URL(fileURLWithPath: widgetJSONPath())
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(WidgetPayload.self, from: data) else {
            return nil
        }
        return payload.date
    }

    private func writeDailyMarker(_ value: String, to marker: URL) {
        let data = "\(value)\n".data(using: .utf8)
        FileManager.default.createFile(atPath: marker.path, contents: data)
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
