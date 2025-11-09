import UIKit

/// UIView subclass that exposes a configurable corner radius in Interface Builder.
@IBDesignable
final class RoundedCornerView: UIView {

    /// Corner radius applied to the view's layer.
    @IBInspectable
    var cornerRadius: CGFloat = 12 {
        didSet { updateCornerRadius() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCornerRadius()
    }

    private func updateCornerRadius() {
        layer.cornerRadius = max(0, cornerRadius)
        layer.masksToBounds = true
        if #available(iOS 13.0, *) {
            layer.cornerCurve = .continuous
        }
    }
}

