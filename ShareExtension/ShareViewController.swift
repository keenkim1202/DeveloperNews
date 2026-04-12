import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupID = "group.keen-onit.DeveloperNews"
    private let pendingShareKey = "pendingSharedItems"

    private var sharedURL: String?

    private let containerView = UIView()
    private let titleField = UITextField()
    private let descriptionField = UITextField()
    private let urlLabel = UILabel()
    private let topicStack = UIStackView()
    private let saveButton = UIButton(type: .system)

    private let topicNames = ["web", "ios", "android", "backend", "ai", "security", "product"]
    private let topicLabels = ["Web", "iOS", "Android", "Backend", "AI", "Security", "Product"]
    private var selectedTopics: Set<String> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tap.delegate = self
        view.addGestureRecognizer(tap)

        setupUI()
        extractSharedContent()
    }

    private func setupUI() {
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        let headerLabel = UILabel()
        headerLabel.text = "DeveloperNews"
        headerLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        headerLabel.textAlignment = .center

        titleField.placeholder = "Title"
        titleField.font = .systemFont(ofSize: 15)
        titleField.borderStyle = .roundedRect

        descriptionField.placeholder = "Description (optional)"
        descriptionField.font = .systemFont(ofSize: 15)
        descriptionField.borderStyle = .roundedRect

        urlLabel.font = .systemFont(ofSize: 13)
        urlLabel.textColor = .secondaryLabel
        urlLabel.numberOfLines = 1
        urlLabel.lineBreakMode = .byTruncatingMiddle

        let topicLabel = UILabel()
        topicLabel.text = "Topics"
        topicLabel.font = .systemFont(ofSize: 13, weight: .medium)
        topicLabel.textColor = .secondaryLabel

        topicStack.axis = .horizontal
        topicStack.spacing = 6
        topicStack.distribution = .fillProportionally

        for (i, name) in topicLabels.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(name, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
            button.tag = i
            button.layer.cornerRadius = 12
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.separator.cgColor
            button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
            button.addTarget(self, action: #selector(topicTapped(_:)), for: .touchUpInside)
            topicStack.addArrangedSubview(button)
        }

        let topicScroll = UIScrollView()
        topicScroll.showsHorizontalScrollIndicator = false
        topicScroll.translatesAutoresizingMaskIntoConstraints = false
        topicScroll.addSubview(topicStack)
        topicStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topicStack.topAnchor.constraint(equalTo: topicScroll.topAnchor),
            topicStack.leadingAnchor.constraint(equalTo: topicScroll.leadingAnchor),
            topicStack.trailingAnchor.constraint(equalTo: topicScroll.trailingAnchor),
            topicStack.bottomAnchor.constraint(equalTo: topicScroll.bottomAnchor),
            topicStack.heightAnchor.constraint(equalTo: topicScroll.heightAnchor),
        ])

        saveButton.setTitle("Save", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.backgroundColor = .systemPurple
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 12
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15)
        cancelButton.setTitleColor(.secondaryLabel, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [headerLabel, titleField, descriptionField, urlLabel, topicLabel, topicScroll, saveButton, cancelButton])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stack)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),

            saveButton.heightAnchor.constraint(equalToConstant: 50),
            topicScroll.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    private func extractSharedContent() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }

        let group = DispatchGroup()

        for item in items {
            if let subject = item.attributedContentText?.string, !subject.isEmpty {
                titleField.text = subject
            }

            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
                        if let url = data as? URL {
                            self?.sharedURL = url.absoluteString
                        }
                        else if let urlData = data as? Data, let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                            self?.sharedURL = url.absoluteString
                        }
                        group.leave()
                    }
                }
                else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
                        if let text = data as? String, URL(string: text) != nil, text.hasPrefix("http") {
                            self?.sharedURL = text
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.urlLabel.text = self.sharedURL ?? ""
            if self.titleField.text?.isEmpty ?? true {
                self.titleField.text = self.sharedURL
            }
        }
    }

    @objc private func topicTapped(_ sender: UIButton) {
        let topic = topicNames[sender.tag]
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
            sender.backgroundColor = .clear
            sender.layer.borderColor = UIColor.separator.cgColor
        }
        else {
            selectedTopics.insert(topic)
            sender.backgroundColor = .systemPurple.withAlphaComponent(0.15)
            sender.layer.borderColor = UIColor.systemPurple.cgColor
        }
    }

    @objc private func saveTapped() {
        guard let url = sharedURL else {
            close()
            return
        }

        let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? url
        let description = descriptionField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let defaults = UserDefaults(suiteName: appGroupID)
        var pending = defaults?.array(forKey: pendingShareKey) as? [[String: String]] ?? []
        pending.append([
            "url": url,
            "title": title.isEmpty ? url : title,
            "description": description,
            "topics": Array(selectedTopics).joined(separator: ","),
        ])
        defaults?.set(pending, forKey: pendingShareKey)

        saveButton.setTitle("✓ Saved", for: .normal)
        saveButton.isEnabled = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.close()
        }
    }

    @objc private func cancelTapped() {
        close()
    }

    @objc private func backgroundTapped() {
        view.endEditing(true)
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

extension ShareViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.view == view
    }
}
