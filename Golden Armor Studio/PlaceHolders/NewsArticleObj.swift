import UIKit

@IBDesignable
final class NewsArticleObj: NSObject {

    @IBOutlet weak var label: UILabel?

    @IBInspectable var title: String = "Placeholder" {
        didSet { updateTitle() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        updateTitle()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        updateTitle()
    }

    private func updateTitle() {
        label?.text = title
    }
}

