import UIKit

final class NewsCardCell: UITableViewCell {
    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var coverImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var summaryLabel: UILabel!
    @IBOutlet private weak var publishedLabel: UILabel!
    @IBOutlet private weak var likesLabel: UILabel!
    @IBOutlet private weak var commentsLabel: UILabel!

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        configureAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        coverImageView.image = UIImage(named: "Placeholder")
        titleLabel.text = nil
        summaryLabel.text = nil
        likesLabel.text = "—"
        commentsLabel.text = "—"
        publishedLabel.text = nil
    }

    private func configureAppearance() {
        containerView.layer.cornerRadius = 22
        containerView.layer.masksToBounds = true
        containerView.backgroundColor = UIColor(named: "NewsCardBackground") ?? UIColor(red: 18/255, green: 19/255, blue: 24/255, alpha: 0.85)
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.backgroundColor = UIColor(red: 20/255, green: 22/255, blue: 30/255, alpha: 1)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        summaryLabel.textColor = UIColor(white: 0.85, alpha: 1)
        summaryLabel.font = UIFont.systemFont(ofSize: 15)
        summaryLabel.numberOfLines = 3
        publishedLabel.textColor = UIColor(white: 0.7, alpha: 1)
        publishedLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        likesLabel.textColor = UIColor(white: 0.9, alpha: 1)
        commentsLabel.textColor = UIColor(white: 0.9, alpha: 1)
    }

    func configure(with article: NewsArticleSummary) {
        titleLabel.text = article.title
        summaryLabel.text = article.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let publishedDate = article.publishedAt?.date {
            publishedLabel.text = "Published " + dateFormatter.string(from: publishedDate)
        } else {
            publishedLabel.text = nil
        }
        likesLabel.text = formattedCount(article.likesCount)
        commentsLabel.text = formattedCount(article.commentsCount)

        ImageLoader.shared.loadImage(from: article.heroImageURL) { [weak self] image in
            guard let self else { return }
            self.coverImageView.image = image ?? UIImage(named: "Placeholder")
        }
    }

    private func formattedCount(_ value: Int?) -> String {
        guard let value else { return "0" }
        switch value {
        case 1_000_000...:
            return String(format: "%.1fM", Double(value) / 1_000_000)
        case 10_000...:
            return String(format: "%.1fk", Double(value) / 1_000)
        default:
            return "\(value)"
        }
    }
}
