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

                    statistics
                    if filter != .all { sessionStatisticsSection }

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
            VStack(spacing: 0) {
                countRow("Alla siteloggar", count: summary.entries.count)
                Divider()
                countRow("Pumpsiteloggar", count: summary.pumpCount)
                Divider()
                countRow("Sensorsiteloggar", count: summary.sensorCount)
                Divider()
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

    private var sessionStatisticsSection: some View {
        let pump = filter == .pump
        let allMetrics = pump ? sessionStatistics?.pumpMetrics(site: nil) ?? [] : sessionStatistics?.sensorMetrics(site: nil) ?? []
        let siteMetrics = selectedSite.map { site in
            pump ? sessionStatistics?.pumpMetrics(site: site) ?? [] : sessionStatistics?.sensorMetrics(site: site) ?? []
        } ?? []
        let allDuration = pump ? sessionStatistics?.pumpDurationHours(site: nil) : sessionStatistics?.sensorDurationDays(site: nil)
        let siteDuration = selectedSite.flatMap { site in
            pump ? sessionStatistics?.pumpDurationHours(site: site) : sessionStatistics?.sensorDurationDays(site: site)
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Sessionsstatistik").font(.headline)
            VStack(spacing: 0) {
                metricRow("Medel sessionslängd (Alla)", value: allDuration, unit: pump ? "h" : "dagar", decimals: pump ? 0 : 1)
                Divider()
                metricRow(pump ? "TDD (Alla)" : "Medel sensorfel/dag (Alla)",
                          value: SiteSessionAnalytics.dailyAverage(allMetrics), unit: pump ? "E" : "min", decimals: pump ? 1 : 0)
                Divider()
                metricRow("\(selectedSite?.rawValue ?? "Vald site") sessionslängd", value: siteDuration,
                          unit: pump ? "h" : "dagar", decimals: pump ? 0 : 1)
                Divider()
                metricRow("\(selectedSite?.rawValue ?? "Vald site") \(pump ? "TDD" : "sensorfel/dag")",
                          value: SiteSessionAnalytics.dailyAverage(siteMetrics), unit: pump ? "E" : "min", decimals: pump ? 1 : 0)
            }
            .background(Color(.systemGray).opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            Text("Sessionslängd gäller avslutade sessioner i sparad historik, även de utan site. Dygnsvärden är tidsvägda och kräver tillgängligt underlag. – betyder att underlag eller site-val saknas.")
                .font(.caption).foregroundStyle(.secondary)
            Text("\(pump ? "TDD" : "Sensorfel"): \(allMetrics.count) sessioner totalt, \(siteMetrics.count) för vald site.")
                .font(.caption).foregroundStyle(.secondary)
            if pump {
                Text("TDD = basal + bolus/SMB per 24 timmar. Pågående pump ingår preliminärt när underlag finns. Underlaget hämtas från den lokala statistikcachen.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Sensorfel gäller avslutade sessioner med verifierade feltider och täckning för hela sessionen. Äldre textsammanfattningar räknas inte som numeriskt underlag.")
                    .font(.caption).foregroundStyle(.secondary)
            }
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
