import UIKit

extension MealAnalysisView {
    func setupNavigationBar() {
        // ← / → dag-hopp (tap) + vecka-hopp (long-press)
        let prevBtn = UIBarButtonItem(image: UIImage(systemName: "chevron.left"),
                                      style: .plain,
                                      target: self,
                                      action: #selector(previousDayTapped))
        let nextBtn = UIBarButtonItem(image: UIImage(systemName: "chevron.right"),
                                      style: .plain,
                                      target: self,
                                      action: #selector(nextDayTapped))
        
        let doneButton = UIBarButtonItem(
            title: "Klar",
            style: .plain,
            target: self,
            action: #selector(dismissSelf)
        )
        
        let enteredByBtn = UIBarButtonItem(image: UIImage(systemName: "person"),
                                      style: .plain,
                                      target: self,
                                      action: #selector(enteredByButtonTapped))

        // Attach long-press to perform week jumps.
        // (Requires the bar button items' underlying views, so we add gestures after the nav bar has laid out.)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if let prevView = prevBtn.value(forKey: "view") as? UIView {
                prevView.isUserInteractionEnabled = true
                let lp = UILongPressGestureRecognizer(target: self, action: #selector(self.previousButtonLongPressed(_:)))
                lp.minimumPressDuration = 0.45
                prevView.addGestureRecognizer(lp)
            }

            if let nextView = nextBtn.value(forKey: "view") as? UIView {
                nextView.isUserInteractionEnabled = true
                let lp = UILongPressGestureRecognizer(target: self, action: #selector(self.nextButtonLongPressed(_:)))
                lp.minimumPressDuration = 0.45
                nextView.addGestureRecognizer(lp)
            }
        }
        if showsDoneButton {
            navigationItem.rightBarButtonItems = [doneButton, nextBtn, prevBtn, enteredByBtn]
        } else {
            navigationItem.rightBarButtonItems = [nextBtn, prevBtn, enteredByBtn]
        }
    }

    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Day/Week navigation
    @objc private func previousDayTapped() {
        shiftWindow(byDays: -1)
    }

    @objc private func nextDayTapped() {
        shiftWindow(byDays: 1)
    }

    @objc private func previousWeekTapped() {
        shiftWindow(byDays: -7)
    }

    @objc private func nextWeekTapped() {
        shiftWindow(byDays: 7)
    }

    @objc private func previousButtonLongPressed(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began else { return }
        previousWeekTapped()
    }

    @objc private func nextButtonLongPressed(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began else { return }
        nextWeekTapped()
    }
    
    private func shiftWindow(byDays days: Int) {
        guard days != 0 else { return }
        let calendar = Calendar.current
        
        endPicker.maximumDate = max(endPicker.maximumDate ?? Date(), Date())

        let span = endTime.timeIntervalSince(startTime)   // nuvarande fönsterbredd
        let oneDay = TimeInterval(86_400 * days)

        var newStart = startTime.addingTimeInterval(oneDay)
        var newEnd   = endTime  .addingTimeInterval(oneDay)

        // Respektera minDate genom att clampa, inte avbryta
        if let minDate = startPicker.minimumDate, newStart < minDate {
            newStart = minDate
            newEnd = minDate.addingTimeInterval(span)
        }

        // Respektera maxDate genom att clampa, inte avbryta
        if let maxDate = endPicker.maximumDate, newEnd > maxDate {
            newEnd = maxDate

            let isApproxOneDay = span >= 23 * 3600 && span <= 25 * 3600
            let todayStart = calendar.startOfDay(for: maxDate)

            if days > 0 && isApproxOneDay {
                // 24h-liknande fönster som kliver in i "idag"
                if let minDate = startPicker.minimumDate, todayStart < minDate {
                    // Fallback om 00:00 idag hamnar före minDate
                    newStart = maxDate.addingTimeInterval(-span)
                } else {
                    // Visa 00:00 → nu
                    newStart = todayStart
                }

                // NEW:
                // Om vi kom från ett 24h-fönster och idag inte har fulla 24h ännu,
                // och fönstret nu är 00:00 → nu, så representera det som "Dag" i UI.
                let startsAtMidnightToday =
                    calendar.isDate(newStart, inSameDayAs: maxDate) &&
                    calendar.component(.hour, from: newStart) == 0 &&
                    calendar.component(.minute, from: newStart) == 0 &&
                    calendar.component(.second, from: newStart) == 0

                if calendar.isDateInToday(maxDate),
                   startsAtMidnightToday,
                   let currentTitle = durationControl.titleForSegment(at: durationControl.selectedSegmentIndex),
                   currentTitle == "24h" {
                    if let dagIndex = (0..<durationControl.numberOfSegments)
                        .first(where: { durationControl.titleForSegment(at: $0) == "Dag" }) {
                        durationControl.selectedSegmentIndex = dagIndex
                    }
                }

            } else {
                // Övriga fall (t.ex. 1–12h, Ⓢ): behåll newStart (samma klockslag) och bara clamp:a slutet till nu.
                // newStart lämnas orörd här.

                // Men om det valda tidsfönstret inte får plats (dvs vi visar mindre än span)
                // och vi hade en tim-presets vald (1h–12h, 24h), justera UI.
                let actualSpan = newEnd.timeIntervalSince(newStart)
                if actualSpan + 0.5 < span,
                   (0...5).contains(durationControl.selectedSegmentIndex) {

                    let startsAtMidnightToday =
                        calendar.isDate(newStart, inSameDayAs: maxDate) &&
                        calendar.component(.hour, from: newStart) == 0 &&
                        calendar.component(.minute, from: newStart) == 0 &&
                        calendar.component(.second, from: newStart) == 0

                    if calendar.isDateInToday(maxDate), startsAtMidnightToday {
                        // NEW:
                        // Vi står på idag, startar 00:00, men preset-spannet får inte plats.
                        // Detta ska visas som "Dag" istället för "☆".
                        if let dagIndex = (0..<durationControl.numberOfSegments)
                            .first(where: { durationControl.titleForSegment(at: $0) == "Dag" }) {
                            durationControl.selectedSegmentIndex = dagIndex
                        }
                    } else {
                        // Gammalt beteende: fall tillbaka till fri-läget "☆"
                        durationControl.selectedSegmentIndex = freeSegmentIndex
                    }
                }
            }
        }

        // Om spannet av någon anledning blivit negativt eller konstigt: bail
        guard newEnd > newStart else { return }

        startTime = newStart
        endTime   = newEnd
        startPicker.date = newStart
        endPicker.date   = newEnd

        updateTotals()
        updateBGLabels()
    }
}
