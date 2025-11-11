
import UIKit

@objcMembers
final class News: UIViewController {

    private let titleLabel = UILabel()
    @IBOutlet weak var MainView: UIView?
    @IBOutlet weak var ProfileImage: UIImageView?
    private let menuView = Menu()

    private var hostingView: UIView? { MainView ?? view }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("[NewsVC] viewDidLoad")
        configureViews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("[NewsVC] viewDidLayoutSubviews")
        if let host = hostingView {
            print("[NewsVC] Hosting view frame after layout: \(host.frame)")
            print("[NewsVC] View frame: \(view.frame)")
            Videoplayer.updateLayout(for: host)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("[NewsVC] viewDidDisappear")
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
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }

        Videoplayer.playVideo(resourcePath: "Videos/website background - discord.mov", in: hostView)
        menuView.attach(to: hostView)
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
}
