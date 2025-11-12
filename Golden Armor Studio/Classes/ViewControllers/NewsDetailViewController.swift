import UIKit
import QuartzCore
import WebKit
import FirebaseAuth

final class NewsDetailViewController: UIViewController {
    private let article: NewsArticleSummary

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private weak var heroImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var publishedLabel: UILabel!
    @IBOutlet private weak var webContainerView: UIView!
    @IBOutlet private weak var webContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var likeButton: UIButton!
    @IBOutlet private weak var likesCountLabel: UILabel!
    @IBOutlet private weak var commentsCountLabel: UILabel!
    @IBOutlet private weak var commentsIconImageView: UIImageView!
    @IBOutlet private weak var commentsContainerView: UIView!
    @IBOutlet private weak var commentInputBackgroundView: UIView!
    @IBOutlet private weak var commentsHeaderLabel: UILabel!
    @IBOutlet private weak var commentsStack: UIStackView!
    @IBOutlet private weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var commentComposerContainer: UIView!
    @IBOutlet private weak var commentSignInLabel: UILabel!
    @IBOutlet private weak var commentTextField: UITextField!
    @IBOutlet private weak var commentSendButton: UIButton!
    @IBOutlet private weak var commentAvatarImageView: UIImageView!

    private let webView = WKWebView(frame: .zero)

    private var comments: [NewsComment] = []
    private var isLiked = false {
        didSet { updateLikeButtonAppearance() }
    }
    private var likesCount: Int = 0 {
        didSet { updateEngagementLabels() }
    }
    private var engagementCommentsCount: Int = 0 {
        didSet {
            updateEngagementLabels()
            updateCommentsHeader()
        }
    }
    private var authListener: AuthStateDidChangeListenerHandle?
    private let accentGreen = UIColor(red: 0.33, green: 0.77, blue: 0.47, alpha: 1)
    private let accentPink = UIColor(red: 0.97, green: 0.35, blue: 0.66, alpha: 1)
    private let neutralIconColor = UIColor(white: 0.75, alpha: 1)
    private var commentsGradientLayer: CAGradientLayer?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(article: NewsArticleSummary) {
        self.article = article
        super.init(nibName: "NewsDetail", bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
        configureViewStyling()
        configureWebView()
        setupCommentComposer()
        renderArticleSummary()
        fetchArticleDetail()
        fetchComments()
        fetchEngagement()
    }

    deinit {
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        commentTextField.resignFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyCommentsContainerGradient()
    }

    private func configureNavigation() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = "Article"
    }

    private func configureViewStyling() {
        view.backgroundColor = UIColor(red: 6/255, green: 7/255, blue: 12/255, alpha: 1)
        scrollView.alwaysBounceVertical = true
        contentStack.spacing = 18

        heroImageView.contentMode = .scaleAspectFill
        heroImageView.clipsToBounds = true
        heroImageView.layer.cornerRadius = 22
        heroImageView.backgroundColor = UIColor(red: 0.08, green: 0.1, blue: 0.18, alpha: 1)

        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0

        publishedLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        publishedLabel.textColor = UIColor(white: 0.7, alpha: 1)
        publishedLabel.numberOfLines = 1

        likeButton.layer.cornerRadius = 22
        likeButton.layer.masksToBounds = true
        likeButton.backgroundColor = UIColor.white.withAlphaComponent(0.08)

        likesCountLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        likesCountLabel.textColor = UIColor(white: 0.9, alpha: 1)
        commentsCountLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        commentsCountLabel.textColor = UIColor(white: 0.9, alpha: 1)
        commentsIconImageView.image = icon(named: "Chat", fallbackSystemName: "text.bubble")?.withRenderingMode(.alwaysTemplate)
        commentsIconImageView.tintColor = UIColor(white: 0.75, alpha: 1)
        updateLikeButtonAppearance()
        updateEngagementLabels()

        commentsContainerView.layer.cornerRadius = 28
        commentsContainerView.layer.masksToBounds = true
        commentsContainerView.layer.borderWidth = 1
        commentsContainerView.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        commentsContainerView.backgroundColor = UIColor(red: 12/255, green: 16/255, blue: 27/255, alpha: 0.95)

        commentComposerContainer.layer.cornerRadius = 0
        commentComposerContainer.layer.masksToBounds = false
        commentComposerContainer.backgroundColor = .clear

        commentInputBackgroundView.layer.cornerRadius = 22
        commentInputBackgroundView.layer.borderWidth = 1
        commentInputBackgroundView.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        commentInputBackgroundView.backgroundColor = UIColor(red: 18/255, green: 20/255, blue: 32/255, alpha: 0.9)
        commentInputBackgroundView.layer.masksToBounds = true

        commentAvatarImageView.layer.cornerRadius = 20
        commentAvatarImageView.clipsToBounds = true
        commentAvatarImageView.contentMode = .scaleAspectFill
        commentAvatarImageView.layer.borderWidth = 1
        commentAvatarImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        commentAvatarImageView.image = UIImage(named: "Placeholder")

        commentTextField.textColor = .white
        commentTextField.backgroundColor = .clear
        commentTextField.borderStyle = .none
        commentTextField.delegate = self
        commentTextField.addTarget(self, action: #selector(commentTextDidChange(_:)), for: .editingChanged)
        commentTextField.isHidden = true
        commentTextField.attributedPlaceholder = NSAttributedString(string: "Share your thoughts...",
                                                                    attributes: [.foregroundColor: UIColor(white: 0.6, alpha: 1)])

        commentSendButton.layer.cornerRadius = 18
        commentSendButton.layer.masksToBounds = true
        commentSendButton.backgroundColor = accentGreen
        commentSendButton.setTitleColor(.white, for: .normal)
        commentSendButton.setTitle("Post Comment", for: .normal)
        commentSendButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        commentSendButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        commentSendButton.setContentHuggingPriority(.required, for: .horizontal)
        commentSignInLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        commentSignInLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        updateCommentSendButtonState(isEnabled: false)
        commentSendButton.isHidden = true
        commentSignInLabel.numberOfLines = 0
        commentSignInLabel.attributedText = signInAttributedString()

        webContainerView.backgroundColor = .clear
        webContainerView.layer.cornerRadius = 18
        webContainerView.layer.masksToBounds = true
        webContainerHeightConstraint.constant = 250
        webContainerView.isHidden = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webContainerView.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: webContainerView.topAnchor),
            webView.leadingAnchor.constraint(equalTo: webContainerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: webContainerView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: webContainerView.bottomAnchor)
        ])

        commentsHeaderLabel.text = "Comments"
        commentsHeaderLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        commentsHeaderLabel.textColor = .white
        commentsHeaderLabel.isHidden = true

        commentsStack.axis = .vertical
        commentsStack.spacing = 18
        loadingIndicator.hidesWhenStopped = true
    }

    private func configureWebView() {
        webView.navigationDelegate = self
    }

    private func setupCommentComposer() {
        updateCommentComposer(for: Auth.auth().currentUser)
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.updateCommentComposer(for: user)
        }
        commentTextDidChange(commentTextField)
    }

    private func renderArticleSummary() {
        titleLabel.text = article.title
        if let date = article.publishedAt?.date {
            publishedLabel.text = "Published " + dateFormatter.string(from: date)
        } else {
            publishedLabel.text = nil
        }
        likesCount = article.likesCount ?? 0
        engagementCommentsCount = article.commentsCount ?? 0
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
                self.commentTextDidChange(self.commentTextField)
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
                self.engagementCommentsCount = max(self.engagementCommentsCount, comments.count)
            case .failure:
                break
            }
        }
    }

    private func apply(detail: NewsArticleDetail) {
        if let coverURL = detail.coverImage?.downloadUrl ?? detail.coverImage?.url,
           let url = URL(string: coverURL) {
            ImageLoader.shared.loadImage(from: url) { [weak self] image in
                self?.heroImageView.image = image ?? UIImage(named: "Placeholder")
            }
        }

        if let html = detail.contentHtml, !html.isEmpty {
            webContainerView.isHidden = false
            webContainerHeightConstraint.constant = 250
            webView.loadHTMLString(styled(html: html), baseURL: nil)
        } else if let legacy = detail.legacyContent, !legacy.isEmpty {
            webContainerView.isHidden = false
            webContainerHeightConstraint.constant = 250
            webView.loadHTMLString(styled(html: legacy), baseURL: nil)
        } else {
            webContainerHeightConstraint.constant = 0
            webContainerView.isHidden = true
        }

        if let likeTotal = detail.likesCount {
            likesCount = likeTotal
        }
    }

    private func renderComments() {
        commentsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, comment) in comments.enumerated() {
            let commentView = makeCommentView(for: comment, index: index)
            commentsStack.addArrangedSubview(commentView)
        }
        engagementCommentsCount = max(engagementCommentsCount, comments.count)
        updateCommentsHeader()
    }

    private func makeCommentView(for comment: NewsComment, index: Int) -> UIView {
        let rowContainer = UIView()
        rowContainer.translatesAutoresizingMaskIntoConstraints = false

        let avatarSize: CGFloat = 48
        let avatarImageView = UIImageView()
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.layer.cornerRadius = avatarSize / 2
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        avatarImageView.image = UIImage(named: "Placeholder")
        if let avatar = comment.avatarUrl, let url = URL(string: avatar) {
            ImageLoader.shared.loadImage(from: url) { image in
                avatarImageView.image = image ?? UIImage(named: "Placeholder")
            }
        }
        NSLayoutConstraint.activate([
            avatarImageView.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: avatarSize)
        ])

        let bubbleView = UIView()
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.backgroundColor = UIColor(red: 18/255, green: 20/255, blue: 30/255, alpha: 0.85)
        bubbleView.layer.cornerRadius = 18
        bubbleView.layer.masksToBounds = true
        bubbleView.layer.borderColor = UIColor.white.withAlphaComponent(0.04).cgColor
        bubbleView.layer.borderWidth = 1

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
        let flagImageName = comment.flaggedByCurrentUser == true ? "Flag-Filled" : "Flag"
        flagButton.setImage(UIImage(named: flagImageName), for: .normal)
        flagButton.tintColor = comment.flaggedByCurrentUser == true ? UIColor.systemOrange : UIColor(white: 0.7, alpha: 1)
        flagButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        flagButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        flagButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        flagButton.tag = index
        flagButton.addTarget(self, action: #selector(flagButtonTapped(_:)), for: .touchUpInside)
        flagButton.accessibilityLabel = comment.flaggedByCurrentUser == true ? "Remove flag" : "Flag comment"
        flagButton.backgroundColor = comment.flaggedByCurrentUser == true ? UIColor.systemOrange.withAlphaComponent(0.15) : UIColor.white.withAlphaComponent(0.05)
        flagButton.layer.cornerRadius = 16

        let commentLikeButton = UIButton(type: .system)
        let likeCount = comment.likesCount ?? 0
        let liked = comment.likedByCurrentUser == true
        let commentHeartName = liked ? "Heart-Filled" : "Heart"
        commentLikeButton.setImage(UIImage(named: commentHeartName), for: .normal)
        commentLikeButton.setTitle("\(likeCount)", for: .normal)
        commentLikeButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        commentLikeButton.tintColor = liked ? .white : UIColor(white: 0.9, alpha: 1)
        commentLikeButton.setTitleColor(liked ? .white : UIColor(white: 0.9, alpha: 1), for: .normal)
        commentLikeButton.tag = index
        commentLikeButton.addTarget(self, action: #selector(commentLikeButtonTapped(_:)), for: .touchUpInside)
        commentLikeButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        commentLikeButton.accessibilityLabel = liked ? "Unlike comment" : "Like comment"
        commentLikeButton.backgroundColor = liked ? accentGreen : UIColor.white.withAlphaComponent(0.08)
        commentLikeButton.layer.cornerRadius = 16
        commentLikeButton.layer.masksToBounds = true
        commentLikeButton.semanticContentAttribute = .forceLeftToRight
        commentLikeButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 0)
        commentLikeButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let topStack = UIStackView(arrangedSubviews: [nameLabel, spacer, commentLikeButton, flagButton])
        topStack.translatesAutoresizingMaskIntoConstraints = false
        topStack.axis = .horizontal
        topStack.alignment = .center
        topStack.distribution = .fill

        let metaStack = UIStackView(arrangedSubviews: [timestampLabel])
        metaStack.axis = .horizontal
        metaStack.alignment = .leading
        metaStack.translatesAutoresizingMaskIntoConstraints = false

        let vertical = UIStackView(arrangedSubviews: [topStack, metaStack, messageLabel])
        vertical.axis = .vertical
        vertical.spacing = 8
        vertical.translatesAutoresizingMaskIntoConstraints = false

        bubbleView.addSubview(vertical)
        NSLayoutConstraint.activate([
            vertical.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 16),
            vertical.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            vertical.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            vertical.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -16)
        ])

        let rowStack = UIStackView(arrangedSubviews: [avatarImageView, bubbleView])
        rowStack.axis = .horizontal
        rowStack.alignment = .top
        rowStack.spacing = 16
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        rowContainer.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: rowContainer.topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor)
        ])

        return rowContainer
    }

    @objc
    private func flagButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard comments.indices.contains(index) else { return }
        guard Auth.auth().currentUser != nil else {
            presentAuthRequiredAlert(message: "You need to be signed in to report comments.")
            return
        }
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

    @objc
    private func commentLikeButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard comments.indices.contains(index) else { return }
        guard Auth.auth().currentUser != nil else {
            presentAuthRequiredAlert(message: "You need to be signed in to like comments.")
            return
        }
        let comment = comments[index]
        NewsService.shared.toggleCommentLike(newsID: article.id, commentID: comment.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                self.comments[index].likedByCurrentUser = response.liked
                self.comments[index].likesCount = response.likesCount
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

    private func updateCommentComposer(for user: User?) {
        if let user {
            commentTextField.isHidden = false
            commentSendButton.isHidden = false
            commentTextField.isEnabled = true
            commentTextField.attributedPlaceholder = NSAttributedString(string: "Share your thoughts...",
                                                                        attributes: [.foregroundColor: UIColor(white: 0.6, alpha: 1)])
            commentSignInLabel.attributedText = nil
            let displayName = user.displayName?.isEmpty == false ? user.displayName! : "Golden Armor fan"
            commentSignInLabel.text = "Posting as \(displayName)"
            commentSignInLabel.textColor = UIColor(white: 0.85, alpha: 1)
            commentInputBackgroundView.alpha = 1
            if let photoURL = user.photoURL {
                ImageLoader.shared.loadImage(from: photoURL) { [weak self] image in
                    self?.commentAvatarImageView.image = image ?? UIImage(named: "Placeholder")
                }
            } else {
                commentAvatarImageView.image = UIImage(named: "Placeholder")
            }
        } else {
            commentTextField.text = ""
            commentTextDidChange(commentTextField)
            commentTextField.isEnabled = false
            commentTextField.isHidden = true
            commentSendButton.isHidden = true
            commentTextField.attributedPlaceholder = nil
            commentSignInLabel.attributedText = signInAttributedString()
            commentAvatarImageView.image = UIImage(named: "Placeholder")
            commentInputBackgroundView.alpha = 0.5
        }
        let trimmed = commentTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateCommentSendButtonState(isEnabled: Auth.auth().currentUser != nil && !trimmed.isEmpty)
    }

    private func signInAttributedString() -> NSAttributedString {
        let baseText = "Sign in to join the discussion."
        let mutable = NSMutableAttributedString(string: baseText,
                                                attributes: [.foregroundColor: UIColor(white: 0.75, alpha: 1),
                                                             .font: UIFont.systemFont(ofSize: 14, weight: .semibold)])
        if let range = baseText.range(of: "Sign in") {
            let nsRange = NSRange(range, in: baseText)
            mutable.addAttributes([.foregroundColor: UIColor(red: 0.33, green: 0.77, blue: 0.47, alpha: 1)],
                                  range: nsRange)
        }
        return mutable
    }

    private func updateCommentSendButtonState(isEnabled: Bool) {
        commentSendButton.isEnabled = isEnabled
        commentSendButton.alpha = isEnabled ? 1 : 0.4
        commentSendButton.backgroundColor = isEnabled ? accentGreen : accentGreen.withAlphaComponent(0.4)
    }

    private func updateEngagementLabels() {
        likesCountLabel.text = "\(likesCount)"

        let commentTotal = max(engagementCommentsCount, comments.count)
        commentsCountLabel.text = "\(commentTotal)"

        let hasComments = commentTotal > 0
        let commentColor = hasComments ? UIColor(white: 0.9, alpha: 1) : neutralIconColor
        commentsCountLabel.textColor = commentColor
        commentsIconImageView.tintColor = commentColor
    }

    private func updateCommentsHeader() {
        let total = max(engagementCommentsCount, comments.count)
        commentsHeaderLabel.isHidden = total == 0
        commentsHeaderLabel.text = total == 0 ? "Comments" : "Comments (\(total))"
    }

    private func icon(named name: String, fallbackSystemName systemName: String) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }
        return UIImage(systemName: systemName)
    }

    private func applyCommentsContainerGradient() {
        guard commentsContainerView.bounds.width > 0 else { return }
        let gradient = commentsGradientLayer ?? CAGradientLayer()
        gradient.colors = [
            UIColor(red: 10/255, green: 17/255, blue: 32/255, alpha: 0.95).cgColor,
            UIColor(red: 8/255, green: 12/255, blue: 24/255, alpha: 0.95).cgColor
        ]
        gradient.locations = [0.0, 1.0]
        gradient.frame = commentsContainerView.bounds
        gradient.cornerRadius = commentsContainerView.layer.cornerRadius
        if gradient.superlayer == nil {
            commentsContainerView.layer.insertSublayer(gradient, at: 0)
        }
        commentsGradientLayer = gradient
    }

    private func fetchEngagement() {
        guard Auth.auth().currentUser != nil else {
            return
        }
        NewsService.shared.fetchEngagement(for: article.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let engagement):
                self.isLiked = engagement.liked
                self.likesCount = engagement.likesCount
                if let commentTotal = engagement.commentsCount {
                    self.engagementCommentsCount = commentTotal
                }
            case .failure:
                break
            }
        }
    }

    @IBAction private func likeButtonTapped(_ sender: UIButton) {
        guard Auth.auth().currentUser != nil else {
            presentAuthRequiredAlert(message: "You need to be signed in to like this article.")
            return
        }
        NewsService.shared.toggleLike(newsID: article.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                self.isLiked = response.liked
                self.likesCount = response.likesCount
            case .failure(let error):
                self.presentError(message: error.localizedDescription)
            }
        }
    }

    @IBAction private func sendCommentTapped(_ sender: UIButton) {
        submitComment()
    }

    private func presentAuthRequiredAlert(message: String = "You need to be signed in to perform this action.") {
        let alert = UIAlertController(title: "Sign In Required", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc
    private func commentTextDidChange(_ textField: UITextField) {
        let trimmed = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasText = !trimmed.isEmpty
        let borderColor = hasText ? accentGreen.withAlphaComponent(0.55).cgColor : UIColor.white.withAlphaComponent(0.06).cgColor
        commentInputBackgroundView.layer.borderColor = borderColor
        updateCommentSendButtonState(isEnabled: !trimmed.isEmpty)
    }

    private func submitComment() {
        guard Auth.auth().currentUser != nil else {
            presentAuthRequiredAlert(message: "You need to be signed in to comment.")
            return
        }
        let trimmed = commentTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        updateCommentSendButtonState(isEnabled: false)
        commentSendButton.isEnabled = false
        NewsService.shared.addComment(newsID: article.id, message: trimmed) { [weak self] result in
            guard let self else { return }
            self.commentSendButton.isEnabled = true
            switch result {
            case .success(let response):
                self.commentTextField.text = ""
                self.commentTextDidChange(self.commentTextField)
                var updatedComments = self.comments
                updatedComments.insert(response.comment, at: 0)
                self.comments = updatedComments
                self.engagementCommentsCount = response.commentsCount
                self.renderComments()
                self.scrollToFirstComment()
            case .failure(let error):
                self.presentError(message: error.localizedDescription)
            }
        }
    }

    private func scrollToFirstComment() {
        view.layoutIfNeeded()
        guard let firstCommentView = commentsStack.arrangedSubviews.first else { return }
        let targetRect = scrollView.convert(firstCommentView.frame, from: commentsStack)
        scrollView.scrollRectToVisible(targetRect.insetBy(dx: 0, dy: -20), animated: true)
    }

    private func updateLikeButtonAppearance() {
        let imageName = isLiked ? "Heart-Filled" : "Heart"
        likeButton.setImage(UIImage(named: imageName), for: .normal)
        likeButton.tintColor = isLiked ? UIColor.systemPink : UIColor(white: 0.95, alpha: 1)
        likeButton.backgroundColor = isLiked ? UIColor.systemPink.withAlphaComponent(0.18) : UIColor.white.withAlphaComponent(0.08)
        likeButton.semanticContentAttribute = .forceLeftToRight
        likeButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        likeButton.accessibilityLabel = isLiked ? "Unlike article" : "Like article"
        likesCountLabel.textColor = isLiked ? accentPink : UIColor(white: 0.9, alpha: 1)
    }

    private func styled(html: String) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyContent: String
        if trimmed.range(of: "<body", options: .caseInsensitive) != nil {
            bodyContent = trimmed
        } else {
            bodyContent = "<div class=\"content\">\(trimmed)</div>"
        }

        return """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                :root { color-scheme: dark; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Helvetica, Arial, sans-serif;
                    color: #F5F6FA;
                    background: transparent;
                    font-size: 16px;
                    line-height: 1.6;
                    margin: 0;
                    padding: 0;
                    -webkit-text-size-adjust: 100%;
                }
                p { margin: 0 0 16px 0; }
                img, video {
                    max-width: 100%;
                    height: auto;
                    border-radius: 12px;
                }
                a { color: #54E0FF; }
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 24px;
                    margin-bottom: 12px;
                    line-height: 1.2;
                }
                ul, ol { padding-left: 20px; margin-bottom: 16px; }
                blockquote {
                    margin: 16px 0;
                    padding-left: 16px;
                    border-left: 3px solid rgba(255,255,255,0.2);
                    color: rgba(245,246,250,0.85);
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin-bottom: 16px;
                }
                table th, table td {
                    border: 1px solid rgba(255,255,255,0.1);
                    padding: 8px;
                }
            </style>
        </head>
        <body>\(bodyContent)</body>
        </html>
        """
    }
}

extension NewsDetailViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           navigationAction.navigationType == .linkActivated {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.readyState", completionHandler: { [weak self] _, _ in
            guard let self else { return }
            webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { height, _ in
                if let height = height as? CGFloat {
                    let adjustedHeight = height + 16
                    self.webContainerHeightConstraint.constant = adjustedHeight
                    UIView.animate(withDuration: 0.2) {
                        self.view.layoutIfNeeded()
                    }
                }
            })
        })
    }
}

extension NewsDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitComment()
        return false
    }
}
