import UIKit
import FirebaseAuth

/// Capsule menu that slides in from the trailing edge and floats above other content.
final class Menu: UIView {
    private enum Constants {
        static let menuWidth: CGFloat = 280
        static let menuCornerRadius: CGFloat = 32
        static let ButtonRadius: CGFloat = 8
        static let toggleSize: CGFloat = 100
        static let animationDuration: TimeInterval = 0.35
        static let overlayAlpha: CGFloat = 0.35
        static let elevatedZPosition: CGFloat = 1_000
        static let TransparentBackground:CGFloat = 0.75
        static let highlightColor = UIColor(red: 0x4E/255.0, green: 0xE0/255.0, blue: 0x80/255.0, alpha: 1)
        static let defaultButtonColor = UIColor(red: 16/255.0, green: 18/255.0, blue: 24/255.0, alpha: 1)
        static let highlightedTextColor = UIColor(red: 16/255.0, green: 18/255.0, blue: 24/255.0, alpha: 1)
        static let defaultTextColor = UIColor.white
    }

    private(set) var isOpen = false
    weak var hostViewController: UIViewController?

    private let overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(Constants.overlayAlpha)
        view.alpha = 0
        view.isUserInteractionEnabled = true
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(Constants.TransparentBackground)
        view.layer.cornerRadius = Constants.menuCornerRadius
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.7
        view.layer.shadowRadius = 25
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let toggleButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.tintColor = Constants.defaultTextColor
        button.layer.cornerRadius = Constants.toggleSize / 2
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 1
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.7
        button.layer.shadowRadius = 25
        button.layer.shadowOffset = CGSize(width: 0, height: 14)
        button.setImage(UIImage(systemName: "line.3.horizontal"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let profileImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "person.fill"))
        imageView.contentMode = .scaleToFill
        imageView.tintColor = .label
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let NewsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("News", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = Constants.defaultButtonColor
        button.setTitleColor(Constants.defaultTextColor, for: .normal)
        button.layer.cornerRadius = Constants.ButtonRadius
        button.layer.shadowColor = UIColor.black.cgColor
        return button
    }()
    
    private let BecomeASupporterButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Become a Supporter", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = Constants.defaultButtonColor
        button.setTitleColor(Constants.defaultTextColor, for: .normal)
        button.layer.cornerRadius = Constants.ButtonRadius
        button.layer.shadowColor = UIColor.black.cgColor
        return button
    }()

    private let profileButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Profile", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = Constants.defaultButtonColor
        button.setTitleColor(Constants.defaultTextColor, for: .normal)
        button.layer.cornerRadius = Constants.ButtonRadius
        button.layer.shadowColor = UIColor.black.cgColor
        return button
    }()

    private let SettingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Settings", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = Constants.defaultButtonColor
        button.setTitleColor(Constants.defaultTextColor, for: .normal)
        button.layer.cornerRadius = Constants.ButtonRadius
        button.layer.shadowColor = UIColor.black.cgColor
        return button
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.textColor = Constants.defaultTextColor
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    

    private var containerTrailingConstraint: NSLayoutConstraint!
    private var profileImageTask: URLSessionDataTask?
    private var authListenerToken: UUID?
    private var orderedMenuButtons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func attach(to view: UIView) {
  
        let hostView = view

        translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: hostView.topAnchor),
            leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
        ])

        hostView.layoutIfNeeded()
        updateShadowPath()
        updateMenuContent(for: AuthSession.shared.currentUser)
        updateCurrentViewHighlight()

        authListenerToken = AuthSession.shared.addListener { [weak self] user in
            DispatchQueue.main.async {
                self?.updateMenuContent(for: user)
            }
        }
    }

    @objc
    private func toggleMenu() {
        setOpen(!isOpen, animated: true)
    }

    func setOpen(_ open: Bool, animated: Bool) {
        guard open != isOpen else { return }
        isOpen = open

        if open {
            overlayView.isHidden = false
        }

        containerTrailingConstraint.constant = open ? 0 : Constants.menuWidth

        let animations = {
            self.overlayView.alpha = open ? 1 : 0
            self.layoutIfNeeded()
        }

        let completion: (Bool) -> Void = { _ in
            if !open {
                self.overlayView.isHidden = true
            }
        }

        if animated {
            UIView.animate(withDuration: Constants.animationDuration,
                           delay: 0,
                           options: [.curveEaseInOut, .beginFromCurrentState],
                           animations: animations,
                           completion: completion)
        } else {
            animations()
            completion(true)
        }

        if open {
            nameLabel.alpha = 0
            UIView.animate(withDuration: 0.35, delay: 0.5, options: [.curveEaseInOut], animations: {
                self.nameLabel.alpha = 1
            }, completion: nil)

            for (index, button) in orderedMenuButtons.enumerated() {
                button.layer.removeAllAnimations()
                UIView.animate(withDuration: 0.3,
                               delay: 0.1 + (0.1 * Double(index)),
                               options: [.curveEaseOut],
                               animations: {
                    button.alpha = 1
                    button.transform = .identity
                }, completion: nil)
            }
        } else {
            nameLabel.layer.removeAllAnimations()
            nameLabel.alpha = 0

            for button in orderedMenuButtons {
                button.layer.removeAllAnimations()
                button.alpha = 0
                button.transform = CGAffineTransform(translationX: 40, y: 0)
            }
        }
    }

    @objc
    private func overlayTapped() {
        setOpen(false, animated: true)
    }

    @objc
    private func showProfile() {
        guard let viewController = hostViewController else { return }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let newsVC = storyboard.instantiateViewController(withIdentifier: "News") as? News else { return }
        newsVC.modalPresentationStyle = .fullScreen
        viewController.present(newsVC, animated: false)
    }

    private func setup() {
        isUserInteractionEnabled = true
        clipsToBounds = false
        layer.zPosition = Constants.elevatedZPosition

        addSubview(overlayView)
        addSubview(containerView)
        addSubview(toggleButton)

        overlayView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        overlayView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        overlayView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        overlayView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        containerTrailingConstraint = containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: Constants.menuWidth)
        NSLayoutConstraint.activate([
            containerTrailingConstraint,
            containerView.widthAnchor.constraint(equalToConstant: Constants.menuWidth),
            containerView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            containerView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        overlayView.isUserInteractionEnabled = true
        let overlayTap = UITapGestureRecognizer(target: self, action: #selector(overlayTapped))
        overlayView.addGestureRecognizer(overlayTap)

        toggleButton.addTarget(self, action: #selector(toggleMenu), for: .touchUpInside)
        NSLayoutConstraint.activate([
            toggleButton.widthAnchor.constraint(equalToConstant: Constants.toggleSize),
            toggleButton.heightAnchor.constraint(equalToConstant: Constants.toggleSize),
            toggleButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
            toggleButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -48)
        ])

        toggleButton.addSubview(profileImageView)
        NSLayoutConstraint.activate([
            profileImageView.widthAnchor.constraint(equalToConstant: Constants.toggleSize),
            profileImageView.heightAnchor.constraint(equalToConstant: Constants.toggleSize),
            profileImageView.centerXAnchor.constraint(equalTo: toggleButton.centerXAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: toggleButton.centerYAnchor)
        ])
        
        orderedMenuButtons = [NewsButton, BecomeASupporterButton, profileButton, SettingsButton]

        var previousBottomAnchor: NSLayoutYAxisAnchor = containerView.topAnchor

        for (index, button) in orderedMenuButtons.enumerated() {
            button.alpha = 0
            button.transform = CGAffineTransform(translationX: 40, y: 0)

            containerView.addSubview(button)
            button.addTarget(self, action: #selector(showProfile), for: .touchUpInside)

            let topPadding: CGFloat = index == 0 ? 40 : 16
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                button.widthAnchor.constraint(equalTo: containerView.widthAnchor, constant: -80),
                button.topAnchor.constraint(equalTo: previousBottomAnchor, constant: topPadding)
            ])

            previousBottomAnchor = button.bottomAnchor
        }

        containerView.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            nameLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor, constant: -50),
            nameLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -50)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateShadowPath()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !isOpen {
            let convertedPoint = convert(point, to: toggleButton)
            if let toggleView = toggleButton.hitTest(convertedPoint, with: event) {
                return toggleView
            }
            return nil
        }
        return super.hitTest(point, with: event)
    }

    private func updateShadowPath() {
        containerView.layer.shadowPath = UIBezierPath(roundedRect: containerView.bounds,
                                                      byRoundingCorners: [.topLeft, .bottomLeft],
                                                      cornerRadii: CGSize(width: Constants.menuCornerRadius,
                                                                           height: Constants.menuCornerRadius)).cgPath
        profileImageView.layer.cornerRadius = profileImageView.bounds.width / 2
    }

    private func updateMenuContent(for user: User?) {
        updateNameLabel(with: user)
        loadProfileImage(for: user)
    }

    private func updateNameLabel(with user: User?) {
        let fallback = user?.email ?? "Signed In"
        nameLabel.text = user?.displayName ?? fallback
    }

    private func loadProfileImage(for user: User?) {
        profileImageTask?.cancel()

        guard let url = user?.photoURL else {
            profileImageView.image = UIImage(systemName: "person.fill")
            profileImageView.tintColor = .label
            return
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        profileImageTask = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }

            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return
            }

            guard error == nil, let data, let image = UIImage(data: data) else { return }

            DispatchQueue.main.async {
                self.profileImageView.image = image
                self.profileImageView.tintColor = nil
                self.updateCurrentViewHighlight()
            }
        }
        profileImageTask?.resume()
    }

    deinit {
        if let token = authListenerToken {
            AuthSession.shared.removeListener(token)
        }
    }

    private func updateCurrentViewHighlight() {
        let currentName = currentViewName()
        for button in menuButtons {
            let matches = button.currentTitle == currentName
            button.backgroundColor = matches ? Constants.highlightColor : Constants.defaultButtonColor
            button.setTitleColor(matches ? Constants.highlightedTextColor : Constants.defaultTextColor, for: .normal)
        }
    }

    private var menuButtons: [UIButton] {
        [NewsButton, BecomeASupporterButton, profileButton, SettingsButton]
    }

    private func currentViewName() -> String? {
        if let title = hostViewController?.title, !title.isEmpty {
            return title
        }
        guard let controller = hostViewController else { return nil }
        return String(describing: type(of: controller))
    }
}
