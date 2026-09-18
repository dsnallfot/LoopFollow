import UIKit

extension TreatmentsTableView {
    // MARK: - UITableViewDataSource Methods
    
    func numberOfSections(in tableView: UITableView) -> Int {
        filteredDaySections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredDaySections[section].treatments.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section < filteredDaySections.count else { return nil }
        return dayTitle(for: filteredDaySections[section].date)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.tintColor = UIColor(red: 45/255.0, green: 66/255.0, blue: 86/255.0, alpha: 0.9)
        header.textLabel?.textColor = .white
        header.textLabel?.font = .boldSystemFont(ofSize: 14)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TreatmentCell", for: indexPath) as? Value1TableViewCell else {
            return UITableViewCell(style: .value1, reuseIdentifier: "TreatmentCell")
        }
        // Ensure cell is truly transparent (iOS 14+ uses backgroundConfiguration)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.backgroundView = nil
        cell.selectedBackgroundView = nil
        
        let treatment = treatment(for: indexPath)
        // Check if this override is pending upload
        var isPendingUpload = false
        if treatment.eventType == "Exercise" {
            let pending = NightscoutUtils.loadPendingUploadDocuments()
            if let notes = treatment.overrideNotes,
               pending.contains(where: { ($0["notes"] as? String) == notes }) {
                isPendingUpload = true
            }
        }
        
        // Determine display event type with special handling for Carb Correction.
        let displayEventType: String = {
            if treatment.eventType == "Carb Correction" {
                if let foodType = treatment.rawData["foodType"] as? String, !foodType.isEmpty {
                    return "Kh"
                } else {
                    return "Fett & Protein"
                }
            } else if treatment.eventType == "Site Change" {
                return "Poddbyte"
            } else if treatment.eventType == "Insulin Change" {
                return "Nytt insulin"
            } else if treatment.eventType == "Sensor Start" {
                return "Sensorbyte"
            } else {
                return treatment.eventType
            }
        }()
        
        // Statussymbol för måltider (Kh) baserat på BG ca 3h efter
        let mealStatusSymbol: String
        if displayEventType == "Kh" {
            mealStatusSymbol = statusSymbolForCarbMeal(at: treatment.timestamp)
        } else {
            mealStatusSymbol = ""
        }
        
        // Handle different treatment types.
        if treatment.eventType == "BG Check" {
            if let glucose = treatment.rawData["glucose"] as? Double,
               let units = treatment.rawData["units"] as? String {
                let mmol = units.lowercased().contains("mmol") ? glucose : glucose / 18.0
                cell.textLabel?.text = "Fingerstick • \(String(format: "%.1f", mmol)) mmol/L"
            } else {
                cell.textLabel?.text = displayEventType
            }
            cell.accessoryType = .none
            
        } else if treatment.eventType == "Temporary Override" ||
                    treatment.eventType == "Exercise" ||
                    treatment.eventType == "Override" {
            var baseText: String
            if let notes = treatment.overrideNotes {
                let preview = previewOverrideText(for: notes)
                if let duration = treatment.overrideDuration {
                    baseText = duration > 1439 ? "\(preview) • Tillsvidare" : "\(preview) • \(Int(duration)) m"
                } else {
                    baseText = preview
                }
            } else {
                baseText = displayEventType
            }

            if isPendingUpload {
                // Orange cloud/arrow symbol for pending upload
                let symbol = "🔂 "
                cell.textLabel?.text = symbol + baseText
            } else {
                cell.textLabel?.text = baseText
            }

            cell.accessoryType = .none
            
        } else if treatment.eventType == "Carb Correction" {
            // For Carb Correction, we display the amount and a processed foodType (if available).
            let mainText = treatment.amount != nil ? "\(displayEventType) • \(treatment.amount!)" : displayEventType
            if let foodType = treatment.rawData["foodType"] as? String, !foodType.isEmpty {
                let cleanedFoodType = foodType.replacingOccurrences(of: "\u{FE0F}", with: "")
                let preview = previewCarbsText(for: cleanedFoodType)
                cell.textLabel?.text = mainText + " • " + preview
                cell.textLabel?.font = .systemFont(ofSize: 17)
                cell.textLabel?.numberOfLines = 0
            } else {
                cell.textLabel?.text = mainText
            }
            cell.accessoryType = .none
            
        } else if treatment.eventType == "Note" || treatment.eventType == "Announcement" {
            if let note = treatment.rawData["notes"] as? String {
                // Create regex patterns for the replacements.
                let resumePattern = "PumpResume"
                let suspendPattern = "PumpSuspend"
                let warningPattern = "⚠️ "
                let urgentPattern = "⛔️ "
                var modifiedNote = note

                // Replace "PumpResume" with "Pump startades".
                if let resumeRegex = try? NSRegularExpression(pattern: resumePattern, options: []) {
                    let range = NSRange(location: 0, length: modifiedNote.utf16.count)
                    modifiedNote = resumeRegex.stringByReplacingMatches(in: modifiedNote, options: [], range: range, withTemplate: "Pump startades")
                }
                // Replace "PumpSuspend" with "Pump pausades".
                if let suspendRegex = try? NSRegularExpression(pattern: suspendPattern, options: []) {
                    let range = NSRange(location: 0, length: modifiedNote.utf16.count)
                    modifiedNote = suspendRegex.stringByReplacingMatches(in: modifiedNote, options: [], range: range, withTemplate: "Pump pausades")
                }
                
                // Replace "⚠️ " with "".
                if let warningRegex = try? NSRegularExpression(pattern: warningPattern, options: []) {
                    let range = NSRange(location: 0, length: modifiedNote.utf16.count)
                    modifiedNote = warningRegex.stringByReplacingMatches(in: modifiedNote, options: [], range: range, withTemplate: "")
                }
                
                // Replace "⛔️ " with "".
                if let urgentRegex = try? NSRegularExpression(pattern: urgentPattern, options: []) {
                    let range = NSRange(location: 0, length: modifiedNote.utf16.count)
                    modifiedNote = urgentRegex.stringByReplacingMatches(in: modifiedNote, options: [], range: range, withTemplate: "")
                }

                let preview = previewNoteText(for: modifiedNote)
                cell.textLabel?.text = preview
            } else {
                cell.textLabel?.text = displayEventType
            }
            
        } else if treatment.eventType == "Temp Basal" {
            if let duration = treatment.tempBasalDuration, let amount = treatment.amount {
                cell.textLabel?.text = "\(treatment.eventType) • \(amount) • \(Int(duration)) m"
            } else {
                cell.textLabel?.text = treatment.eventType
            }
            cell.accessoryType = .none
            
        } else {
            // For all other treatments.
            if treatment.eventType == "Bolus" {
                let mainText = treatment.amount != nil ? "\(displayEventType) • \(treatment.amount!)" : displayEventType
                cell.textLabel?.text = mainText
                cell.accessoryType = .none
            } else {
                // Default display for any other event.
                if let amount = treatment.amount {
                    cell.textLabel?.text = "\(displayEventType) • \(amount)"
                } else {
                    cell.textLabel?.text = displayEventType
                }
                cell.accessoryType = .none
            }
        }
        
        // Format the timestamp as HH:mm och visa den i en separat trailing-view
        // tillsammans med status-symbolen så att symbolerna kan alignas lodrätt.
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "sv_SE")
        timeFormatter.dateFormat = "HH:mm"
        let timeString = timeFormatter.string(from: treatment.timestamp)

        // Använd monospaced digits för att alla tider ska ta samma horisontella utrymme.
        let baseFontSize = cell.detailTextLabel?.font.pointSize
            ?? UIFont.preferredFont(forTextStyle: .subheadline).pointSize
        let timeFont = UIFont.monospacedDigitSystemFont(ofSize: baseFontSize, weight: .regular)
        let statusFont = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)

        // Mått för den lilla "kolumnen" med status-emoji + tid.
        let timeWidth: CGFloat = 50      // räcker för "00:00"
        let symbolWidth: CGFloat = 13    // lagom för en emoji
        let spacing: CGFloat = 2
        let height: CGFloat = timeFont.lineHeight

        let containerWidth = symbolWidth + spacing + timeWidth
        let containerHeight = height
        let trailingTag = 9991

        // Ta bort eventuell tidigare trailing-view (återanvända celler)
        if let old = cell.contentView.viewWithTag(trailingTag) {
            old.removeFromSuperview()
        }

        let container = UIView(frame: .zero)
        container.tag = trailingTag
        container.backgroundColor = .clear

        let statusLabel = UILabel(frame: CGRect(x: 0, y: 0, width: symbolWidth, height: containerHeight))
        statusLabel.text = mealStatusSymbol
        statusLabel.font = statusFont
        statusLabel.textAlignment = .right
        statusLabel.textColor = .label
        statusLabel.backgroundColor = .clear

        let timeLabel = UILabel(frame: CGRect(x: symbolWidth + spacing, y: 0, width: timeWidth, height: containerHeight))
        timeLabel.text = timeString
        timeLabel.font = timeFont
        timeLabel.textAlignment = .right
        timeLabel.textColor = .secondaryLabel
        timeLabel.backgroundColor = .clear

        container.addSubview(statusLabel)
        container.addSubview(timeLabel)

        // Positionera containern längst till höger i cellens contentView
        let contentBounds = cell.contentView.bounds
        let originX = contentBounds.width - containerWidth - tableView.separatorInset.right
        let originY = (contentBounds.height - containerHeight) / 2.0
        container.frame = CGRect(x: originX, y: originY, width: containerWidth, height: containerHeight)
        container.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleBottomMargin]

        cell.contentView.addSubview(container)
        cell.detailTextLabel?.text = nil
        
        // Determine symbol and color.
        let symbolInfo: (name: String, color: UIColor) = {
            if treatment.eventType == "Carb Correction" {
                let foodType = treatment.rawData["foodType"] as? String
                return symbolForEventType(treatment.eventType, foodType: foodType)
            } else if treatment.eventType == "Note" || treatment.eventType == "Announcement" {
                let fullNote = treatment.rawData["notes"] as? String
                return symbolForEventType(treatment.eventType, fullNote: fullNote)
            } else {
                return symbolForEventType(treatment.eventType)
            }
        }()
        if let image = UIImage(systemName: symbolInfo.name) {
            cell.imageView?.image = image
            cell.imageView?.tintColor = symbolInfo.color
        }
        
        cell.selectionStyle = .default
        // Subtle selection highlight that still shows the gradient
        let selected = UIView()
        selected.backgroundColor = UIColor.label.withAlphaComponent(0.2)
        selected.layer.cornerRadius = 10
        selected.layer.masksToBounds = true
        cell.selectedBackgroundView = selected
        
        // Check for duplicates: only count duplicates that have the same timestamp and event type (excluding "Note").
        let duplicateCount = filteredTreatments.filter {
            $0.timestamp == treatment.timestamp &&
            $0.eventType == treatment.eventType &&
            $0.eventType != "Note"
        }.count
        
        if treatment.eventType == "Exercise", let duration = treatment.overrideDuration {
            let exerciseEndTime = treatment.timestamp.addingTimeInterval(duration * 60)
            if Date() < exerciseEndTime {
                cell.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.3)
                cell.contentView.backgroundColor = cell.backgroundColor
            } else {
                cell.backgroundColor = (duplicateCount > 1)
                    ? UIColor.systemRed.withAlphaComponent(0.3)
                    : UIColor.clear
                cell.contentView.backgroundColor = cell.backgroundColor
            }
        } else if treatment.eventType == "Temp Basal" {
            let cal = Calendar.current

            // Only highlight the newest Temp Basal when we're viewing "today".
            if cal.isDate(selectedDate, inSameDayAs: Date()) {
                // Find the newest Temp Basal that occurred today (rolling window may include yesterday).
                let newestTempBasalToday = treatments
                    .filter { $0.eventType == "Temp Basal" && cal.isDate($0.timestamp, inSameDayAs: Date()) }
                    .max(by: { $0.timestamp < $1.timestamp })

                if let newest = newestTempBasalToday,
                   treatment.timestamp == newest.timestamp {
                    cell.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.25)
                    cell.contentView.backgroundColor = cell.backgroundColor
                } else {
                    cell.backgroundColor = (duplicateCount > 1)
                        ? UIColor.systemRed.withAlphaComponent(0.3)
                        : UIColor.clear
                    cell.contentView.backgroundColor = cell.backgroundColor
                }
            } else {
                // Not viewing today: never apply the blue "newest" highlight.
                cell.backgroundColor = (duplicateCount > 1)
                    ? UIColor.systemRed.withAlphaComponent(0.3)
                    : UIColor.clear
                cell.contentView.backgroundColor = cell.backgroundColor
            }
        } else {
            cell.backgroundColor = (duplicateCount > 1 && treatment.eventType != "Note")
                ? UIColor.systemRed.withAlphaComponent(0.3)
                : UIColor.clear
            cell.contentView.backgroundColor = cell.backgroundColor
        }

        
        return cell
    }
}
