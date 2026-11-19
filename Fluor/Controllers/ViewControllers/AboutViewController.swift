//
//  AboutViewController.swift
// 
//  Fluor
//
//  MIT License
//
//  Copyright (c) 2020 Pierre Tacchi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import AppKit

final class AboutViewController: NSViewController {
    private let versionLabel = NSTextField(labelWithString: "")
    private let credit = NSTextField(labelWithString: "")
    private lazy var github = NSButton(title: "", target: self, action: #selector(goToGithub(_:)))

    override func loadView() {
        let name = NSTextField(labelWithString: "Fluor4me")
        name.font = .systemFont(ofSize: 24, weight: .semibold)
        credit.textColor = .secondaryLabelColor

        let mark = NSImage(named: "GitHubMark")
        mark?.size = NSSize(width: 28, height: 28)
        mark?.isTemplate = true
        github.image = mark
        github.imagePosition = .imageOnly
        github.isBordered = false

        let icon = NSImageView(image: NSApp.applicationIconImage ?? NSImage())
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let stack = NSStackView(views: [icon, name, versionLabel, credit, github])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        let view = NSView()
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        self.view = view
        refreshLanguage()
    }

    /// Update the version, credit and accessible link name.
    func refreshLanguage() {
        guard isViewLoaded else { return }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        versionLabel.stringValue = String(format: AppLanguage.text("Version %@"), version)
        credit.stringValue = AppLanguage.text("Copyright (c) 2016 Pierre Tacchi")
        github.setAccessibilityLabel(AppLanguage.text("Fluor4me on GitHub"))
    }

    /// Open the project's GitHub page from Settings.
    @objc private func goToGithub(_ sender: Any) {
        guard let address = Bundle.main.object(forInfoDictionaryKey: "FLGithubURL") as? String,
              let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }
}
