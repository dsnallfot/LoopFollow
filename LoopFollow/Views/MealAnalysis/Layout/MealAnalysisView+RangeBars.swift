import UIKit

extension MealAnalysisView {
    func setupRangeBars() {
        // BG rows
        // Configure inRangeRow and BG bars (now properties)
        inRangeRow.axis = .horizontal
        inRangeRow.spacing = 0
        inRangeRow.distribution = .fillProportionally
        inRangeRow.heightAnchor.constraint(equalToConstant: 30).isActive = true
        inRangeRow.layer.cornerRadius = 6
        inRangeRow.clipsToBounds = true

        // Configure belowBar
        belowBar.backgroundColor = UIColor(named: "LoopRed")
        belowBar.textColor = .white
        belowBar.font = .preferredFont(forTextStyle: .caption1).withTraits(traits: .traitBold)
        belowBar.textAlignment = .center
        belowBar.adjustsFontSizeToFitWidth = false
        belowBar.minimumScaleFactor = 0.5
        // Configure inBar
        inBar.backgroundColor = UIColor(named: "LoopGreen")
        inBar.textColor = .white
        inBar.font = .preferredFont(forTextStyle: .caption1).withTraits(traits: .traitBold)
        inBar.textAlignment = .center
        inBar.adjustsFontSizeToFitWidth = false
        inBar.minimumScaleFactor = 0.5
        // Configure aboveBar
        aboveBar.backgroundColor = .systemPurple
        aboveBar.textColor = .white
        aboveBar.font = .preferredFont(forTextStyle: .caption1).withTraits(traits: .traitBold)
        aboveBar.textAlignment = .center
        aboveBar.adjustsFontSizeToFitWidth = false
        aboveBar.minimumScaleFactor = 0.5
        // Add bars directly to inRangeRow
        inRangeRow.addArrangedSubview(belowBar)
        inRangeRow.addArrangedSubview(inBar)
        inRangeRow.addArrangedSubview(aboveBar)
        // Initial width constraints for bars (equal split, sum to 1.0)
        belowWidthConstraint = belowBar.widthAnchor.constraint(equalTo: inRangeRow.widthAnchor, multiplier: 0.33)
        inWidthConstraint    = inBar.widthAnchor   .constraint(equalTo: inRangeRow.widthAnchor, multiplier: 0.34)
        aboveWidthConstraint = aboveBar.widthAnchor.constraint(equalTo: inRangeRow.widthAnchor, multiplier: 0.33)
        [belowWidthConstraint, inWidthConstraint, aboveWidthConstraint].forEach { $0?.isActive = true }
        // Minimum width constraints (once)
        belowBar.widthAnchor.constraint(greaterThanOrEqualToConstant: 1).isActive = true
        inBar   .widthAnchor.constraint(greaterThanOrEqualToConstant: 1).isActive = true
        aboveBar.widthAnchor.constraint(greaterThanOrEqualToConstant: 1).isActive = true
    }
}
