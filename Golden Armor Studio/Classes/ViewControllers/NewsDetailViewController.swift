import UIKit
import WebKit

final class NewsDetailViewController: UIViewController {
    private let article: NewsArticleSummary

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let heroImageView = UIImageView()
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let publishedLabel = UILabel()
    private let webView = WKWebView(frame: .zero)
    private let commentsHeaderLabel = UILabel()
    private let commentsStack = UIStackView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    private var webViewHeightConstraint: NSLayoutConstraint?
    private var comments: [NewsComment] = []

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(article: NewsArticleSummary) {
        self.article = article
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 6/255, green: 7/255, blue: 12/255, alpha: 1)
        configureNavigation()
        configureLayout()
        configureWebView()
        renderArticleSummary()
        fetchArticleDetail()
        fetchComments()
    }

    private func configureNavigation() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = "Article"
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32)
        ])

        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        heroImageView.contentMode = .scaleAspectFill
        heroImageView.clipsToBounds = true
        heroImageView.layer.cornerRadius = 22
        heroImageView.backgroundColor = UIColor(red: 0.08, green: 0.1, blue: 0.18, alpha: 1)
        contentStack.addArrangedSubview(heroImageView)

        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        contentStack.addArrangedSubview(titleLabel)

        summaryLabel.font = UIFont.systemFont(ofSize: 16)
        summaryLabel.textColor = UIColor(white: 0.9, alpha: 1)
        summaryLabel.numberOfLines = 0
        contentStack.addArrangedSubview(summaryLabel)

        publishedLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        publishedLabel.textColor = UIColor(white: 0.7, alpha: 1)
        publishedLabel.numberOfLines = 1
        contentStack.addArrangedSubview(publishedLabel)

        webView.backgroundColor = UIColor(red: 12/255, green: 14/255, blue: 20/255, alpha: 0.95)
        webView.scrollView.isScrollEnabled = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.layer.cornerRadius = 18
        webView.layer.masksToBounds = true
        contentStack.addArrangedSubview(webView)
        webViewHeightConstraint = webView.heightAnchor.constraint(equalToConstant: 100)
        webViewHeightConstraint?.isActive = true

        commentsHeaderLabel.text = "Comments"
        commentsHeaderLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        commentsHeaderLabel.textColor = .white
        commentsHeaderLabel.isHidden = true
        contentStack.addArrangedSubview(commentsHeaderLabel)

        commentsStack.axis = .vertical
        commentsStack.spacing = 12
        commentsStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(commentsStack)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func configureWebView() {
        webView.navigationDelegate = self
    }

    private func renderArticleSummary() {
        titleLabel.text = article.title
        summaryLabel.text = article.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = article.publishedAt?.date {
            publishedLabel.text = "Published " + dateFormatter.string(from: date)
        } else {
            publishedLabel.text = nil
        }
        ImageLoader.shared.loadImage(from: article.heroImageURL) { [weak self] image in
            self?.heroImageView.image = image ?? UIImage(named: "Placeholder")
        }
    }

    private func fetchArticleDetail() {
        loadingIndicator.startAnimating()
        NewsService.shared.fetchArticleDetail(id: article.id) { [weak self] result in
            guard let self else { return }
            self.loadingIndicator.stopAnimating()
            switch result {
            case .success(let detail):
                self.apply(detail: detail)
            case .failure(let error):
                self.presentError(message: error.localizedDescription)
            }
        }
    }

    private func fetchComments() {
        NewsService.shared.fetchComments(for: article.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let comments):
                self.comments = comments
                self.renderComments()
            case .failure:
                break
            }
        }
    }

    private func apply(detail: NewsArticleDetail) {
        if detail.summary?.isEmpty == false {
            summaryLabel.text = detail.summary
        }
        if let coverURL = detail.coverImage?.downloadUrl ?? detail.coverImage?.url,
           let url = URL(string: coverURL) {
            ImageLoader.shared.loadImage(from: url) { [weak self] image in
                self?.heroImageView.image = image ?? UIImage(named: "Placeholder")
            }
        }

        if let html = detail.contentHtml, !html.isEmpty {
            webView.loadHTMLString(html, baseURL: nil)
        } else if let legacy = detail.legacyContent, !legacy.isEmpty {
            let wrapped = """
            <html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body style="font-family: -apple-system; color: #F5F6FA; background: #0B0D13;">
            \(legacy)</body></html>
            """
            webView.loadHTMLString(wrapped, baseURL: nil)
        } else {
            webViewHeightConstraint?.constant = 0
            webView.isHidden = true
        }
    }

    private func renderComments() {
        commentsHeaderLabel.isHidden = comments.isEmpty
        commentsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, comment) in comments.enumerated() {
            let commentView = makeCommentView(for: comment, index: index)
            commentsStack.addArrangedSubview(commentView)
        }
    }

    private func makeCommentView(for comment: NewsComment, index: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(red: 18/255, green: 20/255, blue: 30/255, alpha: 0.85)
        container.layer.cornerRadius = 16
        container.layer.masksToBounds = true

        let nameLabel = UILabel()
        nameLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.text = comment.displayName

        let timestampLabel = UILabel()
        timestampLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        timestampLabel.textColor = UIColor(white: 0.7, alpha: 1)
        if let date = comment.createdAt?.date {
            timestampLabel.text = dateFormatter.string(from: date)
        } else {
            timestampLabel.text = ""
        }

        let messageLabel = UILabel()
        messageLabel.font = UIFont.systemFont(ofSize: 15)
        messageLabel.textColor = UIColor(white: 0.92, alpha: 1)
        messageLabel.numberOfLines = 0
        messageLabel.text = comment.message

        let flagButton = UIButton(type: .system)
        flagButton.setTitle(comment.flaggedByCurrentUser == true ? "Flagged" : "Flag", for: .normal)
        flagButton.setTitleColor(comment.flaggedByCurrentUser == true ? .systemOrange : .systemRed, for: .normal)
        flagButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        flagButton.tag = index
        flagButton.addTarget(self, action: #selector(flagButtonTapped(_:)), for: .touchUpInside)

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let topStack = UIStackView(arrangedSubviews: [nameLabel, spacer, flagButton])
        topStack.translatesAutoresizingMaskIntoConstraints = false
        topStack.axis = .horizontal
        topStack.alignment = .center

        let metaStack = UIStackView(arrangedSubviews: [timestampLabel])
        metaStack.axis = .horizontal
        metaStack.alignment = .leading
        metaStack.translatesAutoresizingMaskIntoConstraints = false

        let vertical = UIStackView(arrangedSubviews: [topStack, metaStack, messageLabel])
        vertical.axis = .vertical
        vertical.spacing = 8
        vertical.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(vertical)
        NSLayoutConstraint.activate([
            vertical.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            vertical.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            vertical.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            vertical.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])

        return container
    }

    @objc
    private func flagButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard comments.indices.contains(index) else { return }
        let comment = comments[index]
        let title = comment.flaggedByCurrentUser == true ? "Remove Flag?" : "Flag Comment?"
        let message = comment.flaggedByCurrentUser == true ? "Remove your flag from this comment?" : "Mark this comment as inappropriate?"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Confirm", style: .destructive, handler: { [weak self] _ in
            self?.toggleFlag(for: index)
        }))
        present(alert, animated: true)
    }

    private func toggleFlag(for index: Int) {
        let comment = comments[index]
        NewsService.shared.toggleFlag(newsID: article.id, commentID: comment.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                self.comments[index].flaggedByCurrentUser = response.flagged
                self.renderComments()
            case .failure(let error):
                self.presentError(message: error.localizedDescription)
            }
        }
    }

    private func presentError(message: String) {
        let alert = UIAlertController(title: "Something went wrong", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension NewsDetailViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.readyState", completionHandler: { [weak self] _, _ in
            guard let self else { return }
            webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { height, _ in
                if let height = height as? CGFloat {
                    self.webViewHeightConstraint?.constant = height + 32
                    self.view.layoutIfNeeded()
                }
            })
        })
    }
}
