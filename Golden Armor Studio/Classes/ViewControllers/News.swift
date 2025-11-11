import UIKit

@objcMembers
final class News: UIViewController {

    @IBOutlet weak var MainView: UIView?
    @IBOutlet weak var ProfileImage: UIImageView?

    private let menuView = Menu()

    private let headerStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let emptyStateLabel = UILabel()

    private var articles: [NewsArticleSummary] = [] {
        didSet { updateEmptyState() }
    }

    private var hostingView: UIView? { MainView ?? view }
    private var isLoading = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        fetchArticles()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let host = hostingView {
            Videoplayer.updateLayout(for: host)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let host = hostingView {
            Videoplayer.stopVideo(in: host)
        }
    }

    private func configureViews() {
        guard let hostView = hostingView else {
            assertionFailure("[NewsVC] Missing host view for menu/video configuration.")
            return
        }

        if hostView !== view {
            let intrinsicSizingConstraints = hostView.constraints.filter {
                $0.firstItem === hostView &&
                $0.secondItem == nil &&
                ($0.firstAttribute == .height || $0.firstAttribute == .width)
            }
            NSLayoutConstraint.deactivate(intrinsicSizingConstraints)

            hostView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostView.topAnchor.constraint(equalTo: view.topAnchor),
                hostView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                hostView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            view.layoutIfNeeded()
        }

        Videoplayer.playVideo(resourcePath: "Videos/website background - discord.mov", in: hostView)

        configureHeaderStack()
        configureTableView(in: hostView)
        configureLoadingIndicators(in: hostView)

        menuView.attach(to: hostView)
    }

    private func configureHeaderStack() {
        headerStack.axis = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 6
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.text = "Studio News"

        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = UIColor(white: 0.9, alpha: 1)
        subtitleLabel.numberOfLines = 2
        subtitleLabel.text = "Announcements, dev logs, and updates from Golden Armor Studio."

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)

        hostingView?.addSubview(headerStack)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: hostingView!.safeAreaLayoutGuide.topAnchor, constant: 28),
            headerStack.leadingAnchor.constraint(equalTo: hostingView!.leadingAnchor, constant: 24),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: hostingView!.trailingAnchor, constant: -24)
        ])
    }

    private func configureTableView(in hostView: UIView) {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 24, right: 0)
        tableView.estimatedRowHeight = 280
        tableView.rowHeight = UITableView.automaticDimension
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "NewsCard", bundle: nil), forCellReuseIdentifier: "NewsCardCell")

        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        hostView.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 24),
            tableView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.bottomAnchor)
        ])

        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.textColor = UIColor(white: 0.9, alpha: 1)
        emptyStateLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.text = "No studio news yet. Check back soon!"
        emptyStateLabel.isHidden = true
        hostView.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: hostView.centerYAnchor)
        ])
    }

    private func configureLoadingIndicators(in hostView: UIView) {
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        hostView.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: hostView.centerYAnchor)
        ])
    }

    @objc
    private func handleRefresh() {
        fetchArticles(showLoader: false)
    }

    private func updateEmptyState() {
        emptyStateLabel.isHidden = !articles.isEmpty || isLoading
    }

    private func fetchArticles(showLoader: Bool = true) {
        guard !isLoading else { return }
        isLoading = true
        updateEmptyState()
        if showLoader {
            loadingIndicator.startAnimating()
        }

        NewsService.shared.fetchPublishedNews { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            self.loadingIndicator.stopAnimating()
            self.refreshControl.endRefreshing()

            switch result {
            case .success(let articles):
                self.articles = articles
                self.tableView.reloadData()
            case .failure(let error):
                self.showError(message: error.localizedDescription)
            }
            self.updateEmptyState()
        }
    }

    private func showError(message: String) {
        let alert = UIAlertController(title: "Unable to Load News", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default))
        present(alert, animated: true)
    }
}

extension News: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        articles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let article = articles[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "NewsCardCell", for: indexPath) as? NewsCardCell else {
            return UITableViewCell()
        }
        cell.configure(with: article)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let article = articles[indexPath.row]
        let detail = NewsDetailViewController(article: article)
        if let navigationController {
            navigationController.pushViewController(detail, animated: true)
        } else {
            detail.modalPresentationStyle = .fullScreen
            present(detail, animated: true)
        }
    }
}
