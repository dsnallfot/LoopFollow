import UIKit

extension MealAnalysisView {
    func setupAnalysisLayout() {
        let startGroup = UIStackView(arrangedSubviews: [startTimeLabel, startPicker])
        startGroup.axis = .horizontal
        startGroup.alignment = .center
        startGroup.spacing = 8
        startGroup.setContentHuggingPriority(.required, for: .horizontal)

        let endGroup = UIStackView(arrangedSubviews: [endTimeLabel, endPicker])
        endGroup.axis = .horizontal
        endGroup.alignment = .center
        endGroup.spacing = 8
        endGroup.setContentHuggingPriority(.required, for: .horizontal)

        let timeRow = UIStackView(arrangedSubviews: [startGroup, endGroup])
        timeRow.axis = .vertical
        timeRow.alignment = .fill
        timeRow.spacing = 8

        let carbsRow = makeRow(
            iconName: "arrowtriangle.up.circle",
            iconColor: UIColor.systemOrange.withAlphaComponent(1.0),
            text: "Kolhydrater Totalt",
            valueLabel: carbsValueLabel,
            boldText: true
        )

        let fpuRow = makeRow(
            iconName: "arrowtriangle.up.circle",
            iconColor: UIColor.brown.withAlphaComponent(0.8),
            text: "varav Kolhydratsekvivalenter (FPU)",
            valueLabel: fpuValueLabel,
            secondary: true
        )
        
        let realCrRow = makeRow(
            iconName: "divide",
            iconColor: UIColor.label.withAlphaComponent(1.0),
            text: "Verklig Insulinkvot (CR)",
            valueLabel: realCRValueLabel,
            boldText: true
        )
        
        let autoPercentageRow = makeRow(
            iconName: "chart.pie",
            iconColor: UIColor.label.withAlphaComponent(0.5),
            text: "Manuell vs auto insulin",
            valueLabel: manualVsAutomatedLabel,
            secondary: true
        )
        
        // Additional stats rows below chart
        let insulinStack = UIStackView(arrangedSubviews: [
            makeRow(iconName: "circle.fill",
                    iconColor: .systemBlue,
                    text: "Måltidsinsulin Netto",
                    valueLabel: insulinTotalValueLabel,
                    boldText: true),
            makeRow(iconName: "record.circle",
                    iconColor: UIColor.systemBlue.withAlphaComponent(1.0),
                    text: "varav Manuell Bolus",
                    valueLabel: bolusValueLabel,
                    secondary: true),
            makeRow(iconName: "arrowtriangle.down.circle",
                    iconColor: UIColor.systemBlue.withAlphaComponent(1.0),
                    text: "varav SMB",
                    valueLabel: smbValueLabel,
                    secondary: true),
            makeRow(iconName: "stop.circle",
                    iconColor: UIColor.systemBlue.withAlphaComponent(0.45),
                    text: "varav Temp Basal",
                    valueLabel: basalValueLabel,
                    secondary: true),
            makeRow(iconName: "calendar",
                    iconColor: UIColor.systemBlue.withAlphaComponent(0.45),
                    text: "minus Profilbasal",
                    valueLabel: profileBasalValueLabel,
                    secondary: true)
        ])
        insulinStack.axis = .vertical
        insulinStack.spacing = 5

        let rowsStack = UIStackView(arrangedSubviews: [
            carbsRow,
            fpuRow,
            makeDivider(),
            insulinStack,
            makeDivider(),
            realCrRow,
            autoPercentageRow
        ])
        rowsStack.axis = .vertical
        rowsStack.spacing = 5
        rowsStack.setCustomSpacing(5, after: carbsRow) // extra space before fpuRow

        // Additional stats rows below chart
        let statsStackBelow = UIStackView(arrangedSubviews: [
            makeStatRow(textLabel: changeBGTitleLabel,
                        text: "Glukosförändring under vald tid",
                        valueLabel: changeBGValueLabel,
                        unit: " mmol/L")
        ])
        statsStackBelow.axis = .vertical
        statsStackBelow.spacing = 5

        let mainStack = UIStackView(arrangedSubviews: [
            timeRow,
            durationControl,
            inRangeRow,
            rowsStack,
            bgChartView,
            statsStackBelow
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 5
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        // chart config & height
        setupBGChart()
        bgChartView.translatesAutoresizingMaskIntoConstraints = false
        bgChartView.heightAnchor.constraint(equalToConstant: 170).isActive = true

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8), // reduced padding
            mainStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
        mainStack.setCustomSpacing(8, after: timeRow)          // extra gap before duration
        mainStack.setCustomSpacing(12, after: durationControl)  // small gap before in-range bar
        mainStack.setCustomSpacing(12, after: inRangeRow)      // clear separation before totals
        mainStack.setCustomSpacing(10, after: rowsStack)       // clear separation
        mainStack.setCustomSpacing(12, after: bgChartView)     // extra gap before stats
    }
}
