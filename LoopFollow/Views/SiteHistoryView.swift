import SwiftUI

/// Shared by the pump and sensor logs; both tables use saved session history.
struct SiteHistoryView: View {
    @State private var filter: SiteHistoryFilter
    @State private var selectedSite: HealthLogSite?
    @State private var reloadID = UUID()
    @State private var isLoading = true
    @State private var sessionStatistics: SiteSessionStatistics?

    init(initialFilter: SiteHistoryFilter) {
        _filter = State(initialValue: initialFilter)
    }

    private var summary: SiteHistorySummary {
        SiteHistorySummary(pumps: sessionStatistics?.pumps ?? [], sensors: sessionStatistics?.sensors ?? [], filter: filter)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Visa sitebyten", selection: $filter) {
                        ForEach(SiteHistoryFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 8) {
                        HStack {
                            Text("Tryck på en site").font(.subheadline)
                            Spacer()
                            Button("Visa alla siter") { selectedSite = nil }
                                .font(.subheadline)
                                .disabled(selectedSite == nil)
                        }
                        SiteBodyDiagram(selectedSite: $selectedSite, summary: summary)
                            .frame(height: max(350, geometry.size.height * 0.66))
                        Text("Framifrån · kroppens höger och vänster")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Divider()
                    statistics
                    if filter != .all {
                        Divider()
                        sessionStatisticsSection
                    }

                }
                .padding()
            }
            .refreshable { reloadID = UUID() }
        }
        .background(ThemeBackground().ignoresSafeArea())
        .navigationTitle("Sitebyten")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reloadID) {
            isLoading = true
            await SiteSessionService.shared.refresh()
            guard !Task.isCancelled else { return }
            sessionStatistics = SiteSessionStatistics(pumps: Storage.shared.pumpChangeHistory,
                sensors: Storage.shared.sensorStartNotes, currentPumpMetric: SiteSessionService.shared.currentPumpMetric, now: Date())
            isLoading = false
        }
        .onReceive(NotificationCenter.default.publisher(for: SiteSessionService.didUpdate)) { _ in
            sessionStatistics = SiteSessionStatistics(pumps: Storage.shared.pumpChangeHistory,
                sensors: Storage.shared.sensorStartNotes, currentPumpMetric: SiteSessionService.shared.currentPumpMetric, now: Date())
        }
        .onReceive(NotificationCenter.default.publisher(for: NightscoutCache.treatmentsDidChange)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)) { _ in
                reloadID = UUID()
            }
    }

    private var statistics: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Siteloggar · \(filter.rawValue)").font(.headline)
                Spacer()
                if isLoading { ProgressView().accessibilityLabel("Läser siteloggar") }
            }
            SiteComparisonChart(bars: countBars, unit: "Antal", decimals: 0, isLoading: isLoading, selectedSite: selectedSite)
            VStack(spacing: 0) {
                if filter == .all {
                    countRow("Alla siteloggar", count: summary.entries.count)
                    Divider()
                }
                if filter != .sensor {
                    countRow("Pumpsiteloggar", count: summary.pumpCount)
                    Divider()
                }
                if filter != .pump {
                    countRow("Sensorsiteloggar", count: summary.sensorCount)
                    Divider()
                }
                countRow(selectedSite?.rawValue ?? "Välj en site i figuren",
                         count: selectedSite.map { summary.count(at: $0) })
            }
            .background(Color(.systemGray).opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            Text("Varje sparad pump eller sensor med angiven site räknas en gång, även manuellt valda siter. Antalen följer valt segment. Sista raden visar vald kroppsdel.")
                .font(.caption).foregroundStyle(.secondary)
            if !isLoading && summary.entries.isEmpty {
                Text("Inga siteloggar för \(filter.rawValue.lowercased()) med angiven site i den sparade historiken.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var countBars: [SiteComparisonBar] {
        var bars: [SiteComparisonBar]
        switch filter {
        case .all:
            bars = [.init(label: "Total", value: Double(summary.entries.count)),
                    .init(label: "Pumpar", value: Double(summary.pumpCount)),
                    .init(label: "Sensorer", value: Double(summary.sensorCount))]
        case .pump: bars = [.init(label: "Alla pumpar", value: Double(summary.pumpCount))]
        case .sensor: bars = [.init(label: "Alla sensorer", value: Double(summary.sensorCount))]
        }
        return bars + HealthLogSite.allCases.compactMap { site in
            let count = summary.count(at: site)
            return count > 0 ? SiteComparisonBar(site: site, value: Double(count)) : nil
        }
    }

    private func comparisonBars(_ value: (HealthLogSite?) -> Double?) -> [SiteComparisonBar] {
        var bars: [SiteComparisonBar] = []
        if let total = value(nil) {
            bars.append(.init(label: filter == .pump ? "Alla pumpar" : "Alla sensorer", value: total))
        }
        bars += HealthLogSite.allCases.compactMap { site in
            value(site).map { SiteComparisonBar(site: site, value: $0) }
        }
        return bars
    }

    private func duration(at site: HealthLogSite?) -> Double? {
        filter == .pump ? sessionStatistics?.pumpDurationHours(site: site) : sessionStatistics?.sensorDurationDays(site: site)
    }

    private func dailyMetrics(at site: HealthLogSite?) -> [SiteSessionMetric] {
        filter == .pump ? sessionStatistics?.pumpMetrics(site: site) ?? [] : sessionStatistics?.sensorMetrics(site: site) ?? []
    }

    private func compressionCounts(at site: HealthLogSite?) -> [Int] {
        sessionStatistics?.compressionLowCounts(site: site) ?? []
    }

    private var sessionStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            durationSection
            Divider()
            dailyMetricSection
            if filter == .sensor {
                Divider()
                compressionSection
            }
        }
    }

    private var durationSection: some View {
        let pump = filter == .pump
        return VStack(alignment: .leading, spacing: 10) {
            Text("Sessioner").font(.headline)
            SiteComparisonChart(bars: comparisonBars { duration(at: $0) },
                unit: pump ? "Timmar" : "Dagar", decimals: pump ? 0 : 1, isLoading: isLoading, selectedSite: selectedSite)
            VStack(spacing: 0) {
                metricRow("Medel sessionslängd (Alla)", value: duration(at: nil), unit: pump ? "h" : "dagar", decimals: pump ? 0 : 1)
                Divider()
                metricRow("\(selectedSite?.rawValue ?? "Vald site") sessionslängd",
                    value: selectedSite.flatMap { duration(at: $0) }, unit: pump ? "h" : "dagar", decimals: pump ? 0 : 1)
            }
            .background(Color(.systemGray).opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            Text("Medellängd för avslutade sessioner. Alla omfattar även sessioner utan angiven site. – betyder att underlag eller site-val saknas.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var dailyMetricSection: some View {
        let pump = filter == .pump
        let allMetrics = dailyMetrics(at: nil)
        let siteMetrics = selectedSite.map { dailyMetrics(at: $0) } ?? []
        return VStack(alignment: .leading, spacing: 10) {
            Text(pump ? "TDD" : "Sensorfel").font(.headline)
            SiteComparisonChart(bars: comparisonBars { SiteSessionAnalytics.dailyAverage(dailyMetrics(at: $0)) },
                unit: pump ? "E/dygn" : "Min/dag", decimals: pump ? 1 : 0, isLoading: isLoading, selectedSite: selectedSite)
            VStack(spacing: 0) {
                metricRow(pump ? "TDD (Alla)" : "Medel sensorfel/dag (Alla)",
                    value: SiteSessionAnalytics.dailyAverage(allMetrics), unit: pump ? "E" : "min", decimals: pump ? 1 : 0)
                Divider()
                metricRow("\(selectedSite?.rawValue ?? "Vald site") \(pump ? "TDD" : "sensorfel/dag")",
                    value: SiteSessionAnalytics.dailyAverage(siteMetrics), unit: pump ? "E" : "min", decimals: pump ? 1 : 0)
            }
            .background(Color(.systemGray).opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            Text("Tidsvägda dygnsmedelvärden: \(allMetrics.count) sessioner totalt, \(siteMetrics.count) för vald site.")
                .font(.caption).foregroundStyle(.secondary)
            Text(pump
                 ? "TDD = basal + bolus + SMB per 24 timmar. Pågående pump ingår preliminärt när underlag finns. Underlaget hämtas från den lokala statistikcachen."
                 : "Sensorfel gäller avslutade sessioner med verifierade feltider och täckning för hela sessionen. Äldre textsammanfattningar räknas inte som numeriskt underlag.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var compressionSection: some View {
        let allCounts = compressionCounts(at: nil)
        let siteCounts = selectedSite.map { compressionCounts(at: $0) } ?? []
        return VStack(alignment: .leading, spacing: 10) {
            Text("Compression lows").font(.headline)
            SiteComparisonChart(bars: comparisonBars { SiteSessionAnalytics.mean(compressionCounts(at: $0).map(Double.init)) },
                unit: "Antal/session", decimals: 1, isLoading: isLoading, selectedSite: selectedSite)
            VStack(spacing: 0) {
                metricRow("Comp. low (Alla)", value: allCounts.isEmpty ? nil : Double(allCounts.reduce(0, +)), unit: "st", decimals: 0)
                Divider()
                metricRow("Comp. low \(selectedSite?.rawValue ?? "Vald site")", value: siteCounts.isEmpty ? nil : Double(siteCounts.reduce(0, +)), unit: "st", decimals: 0)
                Divider()
                metricRow("Per session (Alla)", value: SiteSessionAnalytics.mean(allCounts.map(Double.init)), unit: "st", decimals: 1)
                Divider()
                metricRow("Per session (\(selectedSite?.rawValue ?? "Vald site"))", value: SiteSessionAnalytics.mean(siteCounts.map(Double.init)), unit: "st", decimals: 1)
            }
            .background(Color(.systemGray).opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            Text("Comp. low är misstänkta episoder, inte bekräftade sensorfel. Historisk återfyllning använder glukosmönstret utan IOB-kontroll; nya larmträffar använder även aktuellt IOB. Medelvärdet omfattar \(allCounts.count) observerade sessioner, varav \(siteCounts.count) på vald site. Pågående och delvis observerade sessioner ingår; äldre sessioner utan insamling ingår inte.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func metricRow(_ title: String, value: Double?, unit: String, decimals: Int) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Text(isLoading ? "–" : value.map { String(format: "%.*f %@", decimals, $0, unit) } ?? "–")
                .monospacedDigit().foregroundStyle(.secondary).fixedSize()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private func countRow(_ title: String, count: Int?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(isLoading ? "–" : count.map { "\($0) st" } ?? "–")
                .monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }
}

/// Category labels are independent of the selected body region: every chart compares all available sites.
private struct SiteComparisonBar: Identifiable {
    let label: String
    let value: Double
    var id: String { label }
    var site: HealthLogSite? { HealthLogSite(rawValue: label) }
    var shortLabel: String {
        label.replacingOccurrences(of: " (Höger)", with: "\nHöger")
            .replacingOccurrences(of: " (Vänster)", with: "\nVänster")
            .replacingOccurrences(of: "Alla ", with: "Alla\n")
    }

    init(label: String, value: Double) { self.label = label; self.value = value }
    init(site: HealthLogSite, value: Double) { self.init(label: site.rawValue, value: value) }
}

/// Lightweight SwiftUI chart, avoiding the app's legacy Charts module name collision with Swift Charts.
private struct SiteComparisonChart: View {
    let bars: [SiteComparisonBar]
    let unit: String
    let decimals: Int
    let isLoading: Bool
    let selectedSite: HealthLogSite?
    private let plotHeight: CGFloat = 200

    private var tickStep: Double {
        let raw = max(bars.map(\.value).max() ?? 0, 1) / 4
        let magnitude = pow(10, floor(log10(raw)))
        let normalized = raw / magnitude
        let step = (normalized <= 1 ? 1.0 : normalized <= 2 ? 2.0 : normalized <= 5 ? 5.0 : 10.0) * magnitude
        return decimals == 0 ? max(1, step) : step
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(unit).font(.caption).foregroundStyle(.secondary)
            if isLoading {
                ProgressView("Läser statistik…").frame(maxWidth: .infinity).frame(height: 240)
            } else if bars.isEmpty {
                Text("Inget beräkningsunderlag ännu")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).frame(height: 160)
            } else {
                GeometryReader { geometry in
                    let width = max(geometry.size.width - 52, CGFloat(bars.count) * 68)
                    HStack(alignment: .top, spacing: 8) {
                        ZStack(alignment: .trailing) {
                            ForEach(0...4, id: \.self) { tick in
                                Text(String(format: "%.*f", decimals == 0 ? 0 : (tickStep < 1 ? 1 : 0), Double(tick) * tickStep))
                                    .font(.caption2).monospacedDigit()
                                    .position(x: 22, y: plotHeight - CGFloat(tick) / 4 * plotHeight)
                            }
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: plotHeight)
                        .accessibilityHidden(true)

                        ScrollView(.horizontal) {
                            VStack(spacing: 0) {
                                ZStack(alignment: .bottom) {
                                    ForEach(0...4, id: \.self) { tick in
                                        Path { path in
                                            let y = plotHeight - CGFloat(tick) / 4 * plotHeight
                                            path.move(to: CGPoint(x: 0, y: y))
                                            path.addLine(to: CGPoint(x: width, y: y))
                                        }
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                                    }
                                    HStack(alignment: .bottom, spacing: 0) {
                                        ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(hue: 0.76, saturation: 0.72 - Double(index) * 0.045,
                                                            brightness: 0.65 + Double(index) * 0.04))
                                                .opacity(selectedSite == nil || bar.site == selectedSite ? 1 : 0.4)
                                                .frame(width: 30, height: max(2, CGFloat(bar.value / (tickStep * 4)) * plotHeight))
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(selectedSite != nil && bar.site == selectedSite ? Color.accentColor : .clear, lineWidth: 3)
                                                }
                                                .overlay(alignment: .top) {
                                                    Text(String(format: "%.*f", decimals, bar.value))
                                                        .font(.caption2).monospacedDigit().fixedSize()
                                                        .offset(y: -18)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .bottom)
                                                .accessibilityElement(children: .ignore)
                                                .accessibilityLabel(bar.label)
                                                .accessibilityAddTraits(selectedSite != nil && bar.site == selectedSite ? .isSelected : [])
                                                .accessibilityValue(String(format: "%.*f %@", decimals, bar.value, unit))
                                        }
                                    }
                                }
                                .frame(height: plotHeight)
                                HStack(alignment: .top, spacing: 0) {
                                    ForEach(bars) { bar in
                                        Text(bar.shortLabel).font(.caption2)
                                            .fontWeight(selectedSite != nil && bar.site == selectedSite ? .bold : .regular)
                                            .foregroundStyle(selectedSite != nil && bar.site == selectedSite ? Color.accentColor : .primary)
                                            .multilineTextAlignment(.center)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity)
                                            .accessibilityHidden(true)
                                    }
                                }
                                .padding(.top, 8)
                            }
                            .padding(.top, 20)
                            .frame(width: width)
                        }
                        .padding(.top, -20)
                    }
                }
                .frame(height: 264)
            }
        }
        .padding(.top, 12)
    }
}

private struct SiteBodyDiagram: View {
    @Binding var selectedSite: HealthLogSite?
    let summary: SiteHistorySummary

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 300, geometry.size.height / 600)
            ZStack {
                BodyOutline()
                    .fill(Color(.secondaryLabel).opacity(0.08))
                BodyOutline()
                    .stroke(Color(.secondaryLabel).opacity(0.65), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                // Anatomical right is on the viewer's left in a front view.
                ForEach(HealthLogSite.allCases) { site in
                    let region = region(for: site)
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedSite = selectedSite == site ? nil : site
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(selectedSite == site ? Color.accentColor.opacity(0.65) : Color.accentColor.opacity(0.13))
                            .overlay {
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.accentColor.opacity(selectedSite == site ? 1 : 0.45), lineWidth: selectedSite == site ? 2.5 : 1)
                            }
                            .overlay {
                                if selectedSite == site {
                                    Image(systemName: "checkmark").font(.headline).foregroundStyle(.primary)
                                }
                            }
                            .frame(width: region.width * scale, height: region.height * scale)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: region.midX * scale, y: region.midY * scale)
                    .accessibilityLabel(site.rawValue)
                    .accessibilityValue("\(summary.count(at: site)) siteloggar")
                    .accessibilityAddTraits(selectedSite == site ? .isSelected : [])
                    .accessibilityHint("Tryck för att välja eller avmarkera denna site")
                }
                Text("H").position(x: 35 * scale, y: 110 * scale)
                Text("V").position(x: 265 * scale, y: 110 * scale)
            }
            .font(.caption).foregroundStyle(.secondary)
            .frame(width: 300 * scale, height: 600 * scale)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    private func region(for site: HealthLogSite) -> CGRect {
        switch site {
        case .rightUpperArm: return CGRect(x: 67, y: 146, width: 27, height: 66)
        case .leftUpperArm: return CGRect(x: 206, y: 146, width: 27, height: 66)
        case .rightAbdomen: return CGRect(x: 115, y: 222, width: 30, height: 62)
        case .leftAbdomen: return CGRect(x: 155, y: 222, width: 30, height: 62)
        case .rightThigh: return CGRect(x: 106, y: 329, width: 32, height: 88)
        case .leftThigh: return CGRect(x: 162, y: 329, width: 32, height: 88)
        }
    }
}

/// A symmetric, scalable front silhouette, authored as vector geometry so hit areas stay aligned.
private struct BodyOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var half = Path()
        half.move(to: CGPoint(x: 150, y: 8))
        half.addCurve(to: CGPoint(x: 118, y: 50), control1: CGPoint(x: 126, y: 8), control2: CGPoint(x: 116, y: 25))
        half.addCurve(to: CGPoint(x: 132, y: 91), control1: CGPoint(x: 118, y: 74), control2: CGPoint(x: 122, y: 85))
        half.addLine(to: CGPoint(x: 132, y: 107))
        half.addCurve(to: CGPoint(x: 75, y: 132), control1: CGPoint(x: 112, y: 117), control2: CGPoint(x: 86, y: 116))
        half.addCurve(to: CGPoint(x: 62, y: 212), control1: CGPoint(x: 61, y: 153), control2: CGPoint(x: 66, y: 184))
        half.addCurve(to: CGPoint(x: 42, y: 302), control1: CGPoint(x: 58, y: 238), control2: CGPoint(x: 45, y: 271))
        half.addCurve(to: CGPoint(x: 27, y: 329), control1: CGPoint(x: 36, y: 311), control2: CGPoint(x: 28, y: 319))
        half.addQuadCurve(to: CGPoint(x: 40, y: 326), control: CGPoint(x: 24, y: 341))
        half.addLine(to: CGPoint(x: 34, y: 354))
        half.addQuadCurve(to: CGPoint(x: 53, y: 358), control: CGPoint(x: 35, y: 368))
        half.addCurve(to: CGPoint(x: 66, y: 313), control1: CGPoint(x: 60, y: 347), control2: CGPoint(x: 63, y: 328))
        half.addCurve(to: CGPoint(x: 87, y: 251), control1: CGPoint(x: 67, y: 295), control2: CGPoint(x: 83, y: 275))
        half.addLine(to: CGPoint(x: 99, y: 185))
        half.addCurve(to: CGPoint(x: 108, y: 267), control1: CGPoint(x: 104, y: 210), control2: CGPoint(x: 110, y: 240))
        half.addCurve(to: CGPoint(x: 99, y: 341), control1: CGPoint(x: 107, y: 289), control2: CGPoint(x: 98, y: 316))
        half.addCurve(to: CGPoint(x: 113, y: 442), control1: CGPoint(x: 98, y: 378), control2: CGPoint(x: 108, y: 418))
        half.addCurve(to: CGPoint(x: 111, y: 478), control1: CGPoint(x: 116, y: 454), control2: CGPoint(x: 109, y: 462))
        half.addCurve(to: CGPoint(x: 124, y: 551), control1: CGPoint(x: 108, y: 501), control2: CGPoint(x: 120, y: 534))
        half.addCurve(to: CGPoint(x: 108, y: 579), control1: CGPoint(x: 128, y: 562), control2: CGPoint(x: 114, y: 570))
        half.addQuadCurve(to: CGPoint(x: 145, y: 586), control: CGPoint(x: 99, y: 590))
        half.addCurve(to: CGPoint(x: 146, y: 501), control1: CGPoint(x: 151, y: 566), control2: CGPoint(x: 142, y: 530))
        half.addCurve(to: CGPoint(x: 145, y: 443), control1: CGPoint(x: 150, y: 477), control2: CGPoint(x: 143, y: 461))
        half.addLine(to: CGPoint(x: 150, y: 317))
        // Mirror the open half in reverse to make one continuous outline without a center seam.
        let left = UIBezierPath(cgPath: half.cgPath)
        let right = UIBezierPath(cgPath: half.cgPath)
        right.apply(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 300, ty: 0))
        right.reversing().cgPath.applyWithBlock { pointer in
            let element = pointer.pointee
            switch element.type {
            case .moveToPoint: break // Continue from the crotch instead of starting a second subpath.
            case .addLineToPoint: left.addLine(to: element.points[0])
            case .addQuadCurveToPoint: left.addQuadCurve(to: element.points[1], controlPoint: element.points[0])
            case .addCurveToPoint:
                left.addCurve(to: element.points[2], controlPoint1: element.points[0], controlPoint2: element.points[1])
            case .closeSubpath: break
            @unknown default: break
            }
        }
        left.close()
        return Path(left.cgPath).applying(CGAffineTransform(scaleX: rect.width / 300, y: rect.height / 600))
    }
}
