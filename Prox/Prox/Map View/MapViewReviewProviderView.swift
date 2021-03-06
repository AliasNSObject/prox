/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

private let viewHeight: CGFloat = 20

private let disabledAlpha: CGFloat = 0.4

protocol MapViewReviewProviderView {

    var scoreView: UIImageView { get }
    var reviewCountView: UILabel { get }

    /// The size, in pixels, of the review score asset.
    ///
    /// HACK: when we scale inside a UIImageView, the UIImageView keeps the size the of the original image
    /// (rather than taking the scaled image size) so, in this case, the view is too wide and has whitespace
    /// on either side of the image. For dev speed, we hardcode the asset sizes. A proper
    /// alternative would be to scale the image outside the image view and set the image view with
    /// the scaled image.
    var assetSize: CGSize { get }

    func provider(from place: Place) -> PlaceProvider?
    func image(forScore score: Float) -> UIImage?
}

extension MapViewReviewProviderView {
    func initViews(withParent parent: UIView) {
        scoreView.image = image(forScore: 5)
        scoreView.alpha = disabledAlpha
        scoreView.clipsToBounds = true
        scoreView.contentMode = .scaleAspectFit

        reviewCountView.text = Strings.mapView.noInfo
        reviewCountView.font = Fonts.mapViewFooterReviewCount
        reviewCountView.textColor = Colors.mapViewFooterReviewCount

        layoutViews(withParent: parent)
    }

    private func layoutViews(withParent parent: UIView) {
        for view in [scoreView, reviewCountView] as [UIView] {
            parent.addSubview(view)
        }

        parent.snp.makeConstraints { make in
            make.height.equalTo(viewHeight)
        }

        let scoreViewWidth = (viewHeight / assetSize.height) * assetSize.width
        scoreView.snp.makeConstraints { make in
            make.top.bottom.leading.equalToSuperview()
            make.width.equalTo(scoreViewWidth)
        }

        reviewCountView.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
        }
    }

    func update(for place: Place) {
        guard let provider = provider(from: place),
                let rating = provider.rating,
                provider.totalReviewCount > 0 else {
            scoreView.alpha = disabledAlpha
            scoreView.image = image(forScore: 0)
            reviewCountView.text = Strings.mapView.noInfo
            return
        }

        let reviewCount = provider.totalReviewCount
        scoreView.alpha = 1
        scoreView.image = image(forScore: rating)
        reviewCountView.text = String(format: Strings.mapView.numReviews, reviewCount, (reviewCount == 1) ? "" : "s")
    }
}
