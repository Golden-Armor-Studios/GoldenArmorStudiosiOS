
import UIKit

@objcMembers
final class News: UIViewController {

    private let backgroundVideoView = UIView()
    private let titleLabel = UILabel()
    @IBOutlet weak var MainView: UIView?
    @IBOutlet weak var ProfileImage: UIImageView?
    private let menuView = Menu()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("[NewsVC] viewDidLoad")
        menuView.attach(to: self)
        configureViews()
        Videoplayer.playVideo(resourcePath: "Videos/website background - discord.mov", in: backgroundVideoView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("[NewsVC] viewDidLayoutSubviews")
        Videoplayer.updateLayout(for: backgroundVideoView)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("[NewsVC] viewDidDisappear")
        Videoplayer.stopVideo(in: backgroundVideoView)
    }

    private func configureViews() {

        backgroundVideoView.translatesAutoresizingMaskIntoConstraints = false
        backgroundVideoView.isUserInteractionEnabled = false
        view.insertSubview(backgroundVideoView, at: 0)
        NSLayoutConstraint.activate([
            backgroundVideoView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundVideoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundVideoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundVideoView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
    }
}
