import UIKit
import Combine

extension ModernAlarmViewController {
    @objc func categoryChanged() {
        viewModel.selectedCategoryIndex = categorySegmentedControl.selectedSegmentIndex
        viewModel.selectedSubCategoryIndex = 0 // Reset till första valet i nya listan

        // Uppdatera titlarna i den andra segment-kontrollen
        subCategorySegmentedControl.removeAllSegments()
        let newOptions: [String]
        switch viewModel.selectedCategoryIndex {
        case 0: newOptions = viewModel.alertBGOptions
        case 1: newOptions = viewModel.alertExtraBGOptions
        case 2: newOptions = viewModel.alertSystemOptions
        case 3: newOptions = viewModel.alertHardwareOptions
        case 4: newOptions = viewModel.alertOtherOptions
        default: newOptions = []
        }

        for (index, title) in newOptions.enumerated() {
            subCategorySegmentedControl.insertSegment(withTitle: title, at: index, animated: false)
        }
        subCategorySegmentedControl.selectedSegmentIndex = 0

        viewModel.updateSnapshotData()
        applySnapshot()
    }

    @objc func subCategoryChanged() {
        viewModel.selectedSubCategoryIndex = subCategorySegmentedControl.selectedSegmentIndex
        viewModel.updateSnapshotData()
        applySnapshot()
    }
}
