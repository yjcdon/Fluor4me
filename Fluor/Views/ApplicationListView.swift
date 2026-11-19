import AppKit

final class ApplicationListView: NSView {
    let searchField = NSSearchField()
    let tableView = NSTableView()
    let countLabel = NSTextField(labelWithString: "")

    /// Build the searchable list and keep the count alongside its controls.
    init(controls: [NSView]) {
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 480))

        searchField.sendsSearchStringImmediately = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Application"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.rowHeight = 54
        tableView.gridStyleMask = .solidHorizontalGridLineMask

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView

        countLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        countLabel.textColor = .secondaryLabelColor
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: controls + [spacer, countLabel])
        footer.alignment = .centerY

        let stack = NSStackView(views: [searchField, scrollView, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            searchField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Change the search and count labels while keeping the list's current contents and selection.
    func refreshLanguage(countFormat: String, items: NSArrayController) {
        searchField.placeholderString = AppLanguage.text("Search")
        let binding = NSBindingName("displayPatternValue1")
        if countLabel.infoForBinding(binding) != nil { countLabel.unbind(binding) }
        countLabel.bind(binding, to: items, withKeyPath: "arrangedObjects.@count", options: [
            .displayPattern: AppLanguage.text(countFormat)
        ])
        tableView.enumerateAvailableRowViews { row, _ in
            (row.view(atColumn: 0) as? RuleCellView)?.refreshLanguage()
        }
    }
}
