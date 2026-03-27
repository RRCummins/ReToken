import Cocoa

final class OpenAICredentialsViewController: NSViewController {
    private let credentialsStore: OpenAICredentialsStore
    private let onSave: () -> Void

    private let adminKeyField = NSSecureTextField()
    private let organizationField = NSTextField()
    private let projectField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")

    init(
        credentialsStore: OpenAICredentialsStore,
        onSave: @escaping () -> Void
    ) {
        self.credentialsStore = credentialsStore
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureView()
        configureFields()
        layoutControls()
        populateFields()
    }

    private func configureView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    private func configureFields() {
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12, weight: .regular)
        statusLabel.maximumNumberOfLines = 0

        adminKeyField.placeholderString = "sk-admin-..."
        organizationField.placeholderString = "Optional organization ID"
        projectField.placeholderString = "Optional project ID"
    }

    private func layoutControls() {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false

        stackView.addArrangedSubview(labeledRow(label: "Admin Key", field: adminKeyField))
        stackView.addArrangedSubview(labeledRow(label: "Organization", field: organizationField))
        stackView.addArrangedSubview(labeledRow(label: "Project", field: projectField))
        stackView.addArrangedSubview(buttonRow())
        stackView.addArrangedSubview(statusLabel)

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 24)
        ])
    }

    private func populateFields() {
        guard let credentials = credentialsStore.loadCredentials() else {
            statusLabel.stringValue = "Stored credentials override environment variables when present."
            return
        }

        adminKeyField.stringValue = credentials.adminKey
        organizationField.stringValue = credentials.organizationID ?? ""
        projectField.stringValue = credentials.projectID ?? ""
        statusLabel.stringValue = "Loaded stored credentials from Keychain."
    }

    @objc
    private func saveCredentials(_ sender: Any?) {
        let trimmedAdminKey = adminKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAdminKey.isEmpty == false else {
            statusLabel.stringValue = "Admin key is required."
            statusLabel.textColor = .systemRed
            return
        }

        let credentials = OpenAICredentials(
            adminKey: trimmedAdminKey,
            organizationID: normalized(organizationField.stringValue),
            projectID: normalized(projectField.stringValue)
        )

        do {
            try credentialsStore.saveCredentials(credentials)
            statusLabel.stringValue = "Saved to Keychain. ReToken will use these for live OpenAI usage."
            statusLabel.textColor = .systemGreen
            onSave()
        } catch {
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = .systemRed
        }
    }

    @objc
    private func clearCredentials(_ sender: Any?) {
        do {
            try credentialsStore.clearCredentials()
            adminKeyField.stringValue = ""
            organizationField.stringValue = ""
            projectField.stringValue = ""
            statusLabel.stringValue = "Cleared stored credentials. Environment variables will be used if present."
            statusLabel.textColor = .systemOrange
            onSave()
        } catch {
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = .systemRed
        }
    }

    private func labeledRow(label: String, field: NSTextField) -> NSView {
        let titleLabel = NSTextField(labelWithString: label)
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)

        field.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])

        let stack = NSStackView(views: [titleLabel, field])
        stack.orientation = .vertical
        stack.spacing = 6
        return stack
    }

    private func buttonRow() -> NSView {
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveCredentials(_:)))
        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearCredentials(_:)))

        let stack = NSStackView(views: [saveButton, clearButton])
        stack.orientation = .horizontal
        stack.spacing = 10
        return stack
    }

    private func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
