import UIKit

extension TreatmentsTableView: UISearchBarDelegate {
    func setupCategorySearch() {
        categorySearchBar.translatesAutoresizingMaskIntoConstraints = false
        categorySearchBar.searchBarStyle = .minimal
        categorySearchBar.showsCancelButton = false
        categorySearchBar.placeholder = "Sök behandlingar eller text i noteringar"
        categorySearchBar.delegate = self
        categorySearchBar.returnKeyType = .search
        categorySearchBar.autocorrectionType = .no
        categorySearchBar.autocapitalizationType = .none
        categorySearchBar.searchTextField.accessibilityLabel = "Sök behandlingstyp eller text i noteringar i cachad historik"
        let keyboardToolbar = UIToolbar()
        keyboardToolbar.sizeToFit()
        let dismissKeyboard = UIBarButtonItem(
            image: UIImage(systemName: "keyboard.chevron.compact.down.fill"),
            style: .plain, target: self, action: #selector(dismissSearchKeyboard))
        dismissKeyboard.accessibilityLabel = "Dölj tangentbord"
        keyboardToolbar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                                 dismissKeyboard]
        categorySearchBar.searchTextField.inputAccessoryView = keyboardToolbar
        view.addSubview(categorySearchBar)

        searchStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        searchStatusLabel.font = .preferredFont(forTextStyle: .caption1)
        searchStatusLabel.adjustsFontForContentSizeCategory = true
        searchStatusLabel.textColor = .secondaryLabel
        searchStatusLabel.numberOfLines = 0
        view.addSubview(searchStatusLabel)
        NotificationCenter.default.addObserver(self, selector: #selector(categorySearchCacheChanged),
            name: NightscoutCache.treatmentsDidChange, object: nil)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let query = (searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !TreatmentCategory.normalize(query).isEmpty else { clearCategorySearch(); return }
        if !isCategorySearchActive {
            searchReturnPosition = (tableView.contentOffset, selectedDate, segmentedControl.selectedSegmentIndex)
        }
        searchQuery = query
        datePicker.isEnabled = false
        searchBar.resignFirstResponder()
        runCategorySearch()
    }

    @objc private func dismissSearchKeyboard() {
        // Keep both the draft text and the currently displayed result unchanged.
        categorySearchBar.resignFirstResponder()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty { clearCategorySearch() }
    }

    func clearCategorySearch() {
        searchGeneration &+= 1
        searchWork?.cancel()
        searchPageWork?.cancel()
        searchRefreshWork?.cancel()
        searchQuery = nil
        searchMatches = []
        searchSections = []
        searchDuplicateCounts = [:]
        searchDisplayedCount = 0
        isLoadingSearchPage = false
        categorySearchBar.text = nil
        categorySearchBar.resignFirstResponder()
        searchStatusLabel.text = nil
        tableView.tableFooterView = nil
        datePicker.isEnabled = true
        if let position = searchReturnPosition {
            selectedDate = position.date
            datePicker.setDate(position.date, animated: false)
            segmentedControl.selectedSegmentIndex = position.segment
            tableView.reloadData()
            view.layoutIfNeeded()
            restoreSearchContentOffset(position.offset)
        }
        searchReturnPosition = nil
        updateDuplicateIndicator()
    }

    func runCategorySearch(preservingPosition: Bool = false) {
        guard let query = searchQuery else { return }
        searchRefreshWork?.cancel()
        searchWork?.cancel()
        searchPageWork?.cancel()
        searchGeneration &+= 1
        let generation = searchGeneration
        let limit = preservingPosition ? max(100, searchDisplayedCount) : 100
        isLoadingSearchPage = true
        searchStatusLabel.text = "Söker i cachad historik…"
        if !preservingPosition {
            searchSections = []
            searchMatches = []
            searchDisplayedCount = 0
            searchDuplicateCounts = [:]
            tableView.tableFooterView = nil
            tableView.reloadData()
        }
        searchWork = searchStore.search(query: query, segment: segmentedControl.selectedSegmentIndex,
            autoTypes: autoTypes, manualTypes: manualTypes, scope: ObservableUserDefaults.shared.url.value) { [weak self] result in
            guard let self, self.searchGeneration == generation, self.isCategorySearchActive else { return }
            self.searchMatches = result.records
            self.searchUnavailableDays = result.unavailableDays
            self.searchDayCount = result.dayCount
            self.prepareSearchPage(from: 0, limit: limit, generation: generation, replacing: true,
                                   preservingPosition: preservingPosition)
        }
    }

    private func prepareSearchPage(from start: Int, limit: Int, generation: UInt64,
                                   replacing: Bool, preservingPosition: Bool = false) {
        let end = min(start + limit, searchMatches.count)
        let records = Array(searchMatches[start..<end])
        isLoadingSearchPage = true
        searchPageWork = searchStore.preparePage(records) { [weak self] page in
            guard let self, self.searchGeneration == generation, self.isCategorySearchActive else { return }
            let offset = self.tableView.contentOffset
            if replacing { self.searchSections = [] }
            for treatment in page.treatments {
                let day = Calendar.current.startOfDay(for: treatment.timestamp)
                if self.searchSections.last?.date == day {
                    self.searchSections[self.searchSections.count - 1].treatments.append(treatment)
                } else {
                    self.searchSections.append(TreatmentDaySection(date: day, treatments: [treatment]))
                }
            }
            for (day, points) in page.glucose {
                self.storeBGPoints(points.map { BGPoint(date: Date(timeIntervalSince1970: $0.date),
                    mmol: Double($0.sgv) / 18.0182) }, for: day)
            }
            self.searchDisplayedCount = end
            self.isLoadingSearchPage = false
            self.searchDuplicateCounts = [:]
            for treatment in self.searchSections.flatMap({ $0.treatments }) where treatment.eventType != "Note" {
                self.searchDuplicateCounts[TreatmentDuplicateKey(timestamp: treatment.timestamp,
                    eventType: treatment.eventType), default: 0] += 1
            }
            self.updateSearchStatus()
            self.tableView.reloadData()
            self.tableView.layoutIfNeeded()
            if replacing && !preservingPosition {
                self.tableView.setContentOffset(CGPoint(x: 0, y: -self.tableView.adjustedContentInset.top), animated: false)
            } else {
                self.restoreSearchContentOffset(offset)
            }
            self.updateDuplicateIndicator()
        }
    }

    private func restoreSearchContentOffset(_ offset: CGPoint) {
        let minY = -tableView.adjustedContentInset.top
        let maxY = max(minY, tableView.contentSize.height - tableView.bounds.height + tableView.adjustedContentInset.bottom)
        tableView.setContentOffset(CGPoint(x: offset.x, y: min(maxY, max(minY, offset.y))), animated: false)
    }

    private func updateSearchStatus() {
        let segment = segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex) ?? "Alla"
        let count = searchMatches.count
        var text = "\(count) träffar • \(segment) • Cachad historik, \(searchDayCount) dagar"
        if searchUnavailableDays > 0 {
            text += "\nCache saknas eller kunde inte läsas för \(searchUnavailableDays) dagar."
        }
        if count == 0 && segmentedControl.selectedSegmentIndex != 0 {
            text += "\nProva segmentet Alla."
        }
        searchStatusLabel.text = text
        if searchDisplayedCount < count {
            let footer = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 44))
            footer.font = .preferredFont(forTextStyle: .footnote)
            footer.textColor = .secondaryLabel
            footer.textAlignment = .center
            footer.text = "Visar \(searchDisplayedCount) av \(count) • Scrolla för fler"
            tableView.tableFooterView = footer
        } else {
            tableView.tableFooterView = nil
        }
    }

    func maybeLoadNextSearchPage() {
        guard !isLoadingSearchPage, searchDisplayedCount < searchMatches.count,
              let last = tableView.indexPathsForVisibleRows?.max(),
              last.section == searchSections.count - 1,
              last.row >= searchSections[last.section].treatments.count - 5 else { return }
        prepareSearchPage(from: searchDisplayedCount, limit: 100, generation: searchGeneration, replacing: false)
    }

    @objc private func categorySearchCacheChanged() {
        scheduleCategorySearchRefresh()
    }

    func scheduleCategorySearchRefresh() {
        guard isCategorySearchActive else { return }
        // Invalidate in-flight results immediately; coalesce batches of day writes.
        searchGeneration &+= 1
        searchWork?.cancel()
        searchPageWork?.cancel()
        searchRefreshWork?.cancel()
        isLoadingSearchPage = true
        let work = DispatchWorkItem { [weak self] in self?.runCategorySearch(preservingPosition: true) }
        searchRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}
