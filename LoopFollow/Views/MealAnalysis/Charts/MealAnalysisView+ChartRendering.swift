import UIKit
import Charts

extension MealAnalysisView {
    func refreshBGChart() {
        let pts = bgEntries
            .filter { $0.date >= startTime && $0.date <= endTime }
            .sorted { $0.date < $1.date }
        let entries = pts.map {
            ChartDataEntry(x: $0.date.timeIntervalSince(startTime)/3600.0,
                           y: $0.mmol)
        }
        // Main BG line dataset broken on gaps > 9 min
        let segmentGap: TimeInterval = 9 * 60  // seconds
        var segments: [[ChartDataEntry]] = []
        var currentSegment: [ChartDataEntry] = []
        var lastX: Double? = nil

        for entry in entries {
            if let last = lastX, (entry.x - last) * 3600.0 > segmentGap {
                if !currentSegment.isEmpty {
                    segments.append(currentSegment)
                }
                currentSegment = []
            }
            currentSegment.append(entry)
            lastX = entry.x
        }
        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }

        let lineDataSets = segments.map { segEntries -> LineChartDataSet in
            let ds = LineChartDataSet(entries: segEntries, label: "")
            ds.colors = segEntries.map { setBGColorForMmol($0.y) }
            ds.lineWidth = 1.5
            ds.drawCirclesEnabled = false
            ds.drawValuesEnabled = false
            ds.mode = .linear
            ds.highlightColor = .clear
            ds.highlightLineWidth = 0
            return ds
        }

        // ▸ Blue dots for Bolus at y = 22 mmol
        let bolusEntries = events.filter {
            $0.eventType == "Bolus" && $0.date >= startTime && $0.date <= endTime
        }.map { event in
            ChartDataEntry(
                x: event.date.timeIntervalSince(startTime) / 3600.0,
                y: 20.0,
                data: String(format: "Bolus: %.2f E", event.amount)
            )
        }
        let bolusDots = ScatterChartDataSet(entries: bolusEntries, label: "")
        bolusDots.setColor(NSUIColor.systemBlue.withAlphaComponent(0.9))
        bolusDots.setScatterShape(.circle)
        bolusDots.scatterShapeSize = 8
        bolusDots.drawValuesEnabled = false
        bolusDots.highlightEnabled = true
        bolusDots.highlightColor = .clear
        bolusDots.highlightLineWidth = 0
        
        // ▸ Blue triangles for SMB at y = 22 mmol
        let smbEntries = events.filter {
            $0.eventType == "SMB" && $0.date >= startTime && $0.date <= endTime
        }.map { event in
            ChartDataEntry(
                x: event.date.timeIntervalSince(startTime) / 3600.0,
                y: 22.0,
                data: String(format: "SMB: %.2f E", event.amount)
            )
        }
        let smbDots = ScatterChartDataSet(entries: smbEntries, label: "")
        smbDots.setColor(NSUIColor.systemBlue.withAlphaComponent(0.9))
        smbDots.setScatterShape(.triangleFlipped)
        smbDots.scatterShapeSize = 8
        smbDots.drawValuesEnabled = false
        smbDots.highlightEnabled = true
        smbDots.highlightColor = .clear
        smbDots.highlightLineWidth = 0

        // ▸ Triangles for Carb Correction:
        //   • Teal for Dextro (foodType innehåller 🍬)
        //   • Orange for “real” carbs (icke-tom foodType utan 🍬)
        //   • Brown for fat/protein equivalents (tom foodType)
        let carbCorrections = events.filter {
            $0.eventType == "Carb Correction" &&
            $0.date >= startTime && $0.date <= endTime
        }

        // Dextro: foodType innehåller 🍬
        let dextroEntries = carbCorrections
            .filter { ($0.foodType ?? "").contains("🍬") }
            .map { event in
                ChartDataEntry(
                    x: event.date.timeIntervalSince(startTime) / 3600.0,
                    y: 2.0,
                    data: String(format: "Dextro: %.0f g", event.amount)
                )
            }
        let dextroDots = ScatterChartDataSet(entries: dextroEntries, label: "")
        dextroDots.setColor(.white)
        dextroDots.setScatterShape(.triangle)
        dextroDots.scatterShapeSize = 8
        dextroDots.drawValuesEnabled = false
        dextroDots.highlightEnabled = true
        dextroDots.highlightColor = .clear
        dextroDots.highlightLineWidth = 0

        // Orange för vanliga kolhydrater: foodType är icke-tom och innehåller INTE 🍬
        let orangeEntries = carbCorrections
            .filter {
                let ft = $0.foodType ?? ""
                return !ft.isEmpty && !ft.contains("🍬")
            }
            .map { event in
                ChartDataEntry(
                    x: event.date.timeIntervalSince(startTime) / 3600.0,
                    y: 2.0,
                    data: String(format: "Kolhydrater: %.0f g", event.amount)
                )
            }
        let orangeDots = ScatterChartDataSet(entries: orangeEntries, label: "")
        orangeDots.setColor(.systemOrange.withAlphaComponent(0.9))
        orangeDots.setScatterShape(.triangle)
        orangeDots.scatterShapeSize = 8
        orangeDots.drawValuesEnabled = false
        orangeDots.highlightEnabled = true
        orangeDots.highlightColor = .clear
        orangeDots.highlightLineWidth = 0

        // Brown för fett/protein-ekvivalenter (tom foodType)
        let brownEntries = carbCorrections
            .filter { ($0.foodType ?? "").isEmpty }
            .map { event in
                ChartDataEntry(
                    x: event.date.timeIntervalSince(startTime) / 3600.0,
                    y: 2.0,
                    data: String(format: "FPU Kh: %.0f g", event.amount)
                )
            }
        let brownDots = ScatterChartDataSet(entries: brownEntries, label: "")
        brownDots.setColor(.brown.withAlphaComponent(0.8))
        brownDots.setScatterShape(.triangle)
        brownDots.scatterShapeSize = 7
        brownDots.drawValuesEnabled = false
        brownDots.highlightEnabled = true
        brownDots.highlightColor = .clear
        brownDots.highlightLineWidth = 0

        // ▸ Red circles for BG Check events at their glucose level
        let bgCheckEvents = events.filter {
            $0.eventType == "BG Check" && $0.date >= startTime && $0.date <= endTime
        }
        //print("DEBUG ▸ BG Check events: count = \(bgCheckEvents.count)")
        //for evt in bgCheckEvents {
            //let x = evt.date.timeIntervalSince(startTime) / 3600.0
            //let y = evt.amount
            //print("DEBUG ▸ BG Check event: date = \(evt.date), x = \(x), y = \(y)")
        //}
        let bgCheckEntries = bgCheckEvents.map { event in
            ChartDataEntry(
                x: event.date.timeIntervalSince(startTime) / 3600.0,
                y: event.amount,
                data: String(format: "Fingerstick: %.1f mmol", event.amount)
            )
        }
        let bgCheckDots = ScatterChartDataSet(entries: bgCheckEntries, label: "")
        bgCheckDots.setColor(.systemRed)
        bgCheckDots.setScatterShape(.circle)
        bgCheckDots.scatterShapeSize = 7
        bgCheckDots.drawValuesEnabled = false
        bgCheckDots.highlightEnabled = true
        bgCheckDots.highlightColor = .clear
        bgCheckDots.highlightLineWidth = 0
        
        // ▸ Gray circles for Pump changes events at their glucose level
        let siteChangeEvents = events.filter {
            $0.eventType == "Site Change" && $0.date >= startTime && $0.date <= endTime
        }

        let siteChangeEntries = siteChangeEvents.map { event in
            ChartDataEntry(
                x: event.date.timeIntervalSince(startTime) / 3600.0,
                y: 2.0,
                data: String("Poddbyte")
            )
        }
        let siteChangeDots = ScatterChartDataSet(entries: siteChangeEntries, label: "")
        siteChangeDots.setColor(.systemTeal.withAlphaComponent(0.75))
        siteChangeDots.setScatterShape(.circle)
        siteChangeDots.scatterShapeSize = 9
        siteChangeDots.drawValuesEnabled = false
        siteChangeDots.highlightEnabled = true
        siteChangeDots.highlightColor = .clear
        siteChangeDots.highlightLineWidth = 0

        // ▸ Squares for Temp Basal actual deliveries (0.05 U pulses) at y = 23 mmol
        // Pulse interval = 180 / rate seconds. Counter resets on each rate change.
        let tempBasals = events
            .filter { $0.eventType == "Temp Basal" }
            .sorted { $0.date < $1.date }
        //#if DEBUG
        //print("Chart  ▸ TempBasal events in window:")
        //tempBasals.forEach {
        //print("Chart  ▸   event \($0.date)  rate \($0.amount) U/h")
        //}
        //#endif

        var basalEntries: [ChartDataEntry] = []

        // Carry‑over aware pulse simulation for scatter dots
        var residual = 0.0
        for (idx, evt) in tempBasals.enumerated() {
            let segmentStart = max(evt.date, startTime)
            let segmentEnd: Date = {
                if idx + 1 < tempBasals.count {
                    return min(tempBasals[idx + 1].date, endTime)
                } else {
                    return endTime
                }
            }()
            guard segmentStart < segmentEnd else { continue }
            let rate = evt.amount
            //#if DEBUG
            //print("Chart  ▸ TempBasal  rate=\(rate) U/h  segmentStart=\(segmentStart)  segmentEnd=\(segmentEnd)  residualIn=\(residual)")
            //#endif
            guard rate > 0 else {
                if !carryOverUndeliveredBasals { residual = 0 }
                continue
            }

            let ratePerSec = rate / 3600.0
            var t = segmentStart
            var accum = carryOverUndeliveredBasals ? residual : 0.0

            while true {
                let remaining = 0.05 - accum
                let dt = remaining / ratePerSec
                if t.addingTimeInterval(dt) > segmentEnd {        // no more pulses
                    accum += ratePerSec * segmentEnd.timeIntervalSince(t)
                    t = segmentEnd
                    break
                }
                t = t.addingTimeInterval(dt)
                if t >= startTime {
                    basalEntries.append(
                        ChartDataEntry(
                            x: t.timeIntervalSince(startTime) / 3600.0,
                            y: 23.0,
                            data: String(format: "Temp basal: %.2f E/h", rate)
                        )
                    )
                    //#if DEBUG
                    //print("Chart  ▸   pulse at \(t)")
                    //#endif
                }
                accum = 0.0
            }
            residual = carryOverUndeliveredBasals ? accum : 0.0
        }

        let basalSquares = ScatterChartDataSet(entries: basalEntries, label: "")
        basalSquares.setColor(NSUIColor.systemBlue.withAlphaComponent(0.45))
        basalSquares.setScatterShape(.square)
        basalSquares.scatterShapeSize = 6
        basalSquares.drawValuesEnabled = false
        basalSquares.highlightColor = .clear
        basalSquares.highlightLineWidth = 0

        // Combine
        let combined = CombinedChartData()
        combined.lineData   = LineChartData(dataSets: lineDataSets)
        combined.scatterData = ScatterChartData(
            dataSets: [bolusDots, smbDots, orangeDots, dextroDots, brownDots, bgCheckDots, siteChangeDots, basalSquares]
        )
        bgChartView.data = combined

        // X range & labels
        let hrs = max(endTime.timeIntervalSince(startTime)/3600.0, 0.1)
        let x = bgChartView.xAxis
        x.axisMinimum = 0
        x.axisMaximum = hrs

        if hrs <= 6 {
            // 0–6 h: one label per hour
            x.granularity = 1
            x.labelCount = Int(hrs.rounded(.up)) + 1
        } else if hrs <= 24 {
            // 6–24 h: one label every 3 hours
            x.granularity = 3
            x.labelCount = Int((hrs / 3).rounded(.up)) + 1
        } else if hrs <= 3 * 24 {
            // 1–3 dygn: en label var 12:e timme, fortfarande HH:mm
            x.granularity = 12
            x.labelCount = Int((hrs / 12).rounded(.up)) + 1
        } else if hrs <= 7 * 24 {
            // 3–7 dygn: en label per kalenderdag (dd/MM)
            x.granularity = 24
            x.labelCount = Int((hrs / 24).rounded(.up)) + 1
        } else {
            // >7 dygn (upp till ~90 dagar): jämnt fördelade datumetiketter (dd/MM)
            let days = hrs / 24.0
            let targetLabels = 8.0
            let stepDays = max(1.0, ceil(days / targetLabels))
            x.granularity = stepDays * 24.0
            x.labelCount = Int(ceil(days / stepDays)) + 1
        }

        bgChartView.notifyDataSetChanged()
    }
}
