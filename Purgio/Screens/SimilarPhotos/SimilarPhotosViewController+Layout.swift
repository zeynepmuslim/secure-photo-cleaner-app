//
//  SimilarPhotosViewController+Layout.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static func confirmAll(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("similarPhotos.confirmAll", comment: "Confirm every unconfirmed set, e.g. 'Confirm all · 6 sets'"),
            count)
    }
}

// MARK: - List layout, bottom row and bin slot

extension SimilarPhotosViewController {

    // MARK: Setup

    func setupListConstraint() {
        let content = GeneralConstants.EdgePadding.content

        // The list's sides follow the safe area and the rail; its cards span its width
        let listEdges = DuoEdgeConstraints(
            item: collectionView, in: view, standardLeading: content, standardTrailing: content)
        collectionEdges = listEdges

        let rowEdges = DuoEdgeConstraints(
            item: bottomRowContainer, in: view,
            standardLeading: content, standardTrailing: content,
            standardBottom: GeneralConstants.Spacer.buttonBottom)
        bottomRowEdges = rowEdges

        let rowHeight = bottomRowContainer.heightAnchor.constraint(
            equalToConstant: GeneralConstants.ButtonSize.large)
        bottomRowHeightConstraint = rowHeight
        let slotWidth = binSlotView.widthAnchor.constraint(
            equalToConstant: FloatingBinButton.slotWidth(forCount: binSlotCount))
        binSlotWidthConstraint = slotWidth

        NSLayoutConstraint.activate(listEdges.initialConstraints + rowEdges.initialConstraints + [
            rowHeight,
            slotWidth,
            bottomRowStack.topAnchor.constraint(equalTo: bottomRowContainer.topAnchor),
            bottomRowStack.trailingAnchor.constraint(equalTo: bottomRowContainer.trailingAnchor),
            bottomRowStack.bottomAnchor.constraint(equalTo: bottomRowContainer.bottomAnchor),

            // Upright only: the raised half, as wide as the list
            raisedContainer.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Layout.listTopInset),
            raisedContainer.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor),
            raisedContainer.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),

            summaryCardView.topAnchor.constraint(equalTo: raisedContainer.topAnchor),
            summaryCardView.leadingAnchor.constraint(equalTo: raisedContainer.leadingAnchor),
            summaryCardView.trailingAnchor.constraint(equalTo: raisedContainer.trailingAnchor),
            raisedSummaryView.topAnchor.constraint(
                equalTo: summaryCardView.topAnchor, constant: GeneralConstants.EdgePadding.cardInner),
            raisedSummaryView.leadingAnchor.constraint(
                equalTo: summaryCardView.leadingAnchor, constant: GeneralConstants.EdgePadding.cardInner),
            raisedSummaryView.trailingAnchor.constraint(
                equalTo: summaryCardView.trailingAnchor, constant: -GeneralConstants.EdgePadding.cardInner),
            raisedSummaryView.bottomAnchor.constraint(
                equalTo: summaryCardView.bottomAnchor, constant: -GeneralConstants.EdgePadding.cardInner),

            spotlightCardView.topAnchor.constraint(
                equalTo: summaryCardView.bottomAnchor, constant: Layout.cardSpacing),
            spotlightCardView.leadingAnchor.constraint(equalTo: raisedContainer.leadingAnchor),
            spotlightCardView.trailingAnchor.constraint(equalTo: raisedContainer.trailingAnchor),
            spotlightCardView.bottomAnchor.constraint(equalTo: raisedContainer.bottomAnchor)
        ])

        // Every layout: the list runs to the bottom edge and scrolls under the bottom row; its
        // content inset rests the last card above the row (updateListInsets)
        NSLayoutConstraint.activate([
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // The blur covers the row's area and a short band above it, down to the bottom edge
            listBottomBlurView.topAnchor.constraint(
                equalTo: bottomRowContainer.topAnchor,
                constant: -(Layout.listToBottomRow + Layout.blurBandHeight)),
            listBottomBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listBottomBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listBottomBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let fullWidthRow = { [unowned self] in
            self.bottomRowStack.leadingAnchor.constraint(equalTo: self.bottomRowContainer.leadingAnchor)
        }

        singleConstraints = [
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            fullWidthRow()
        ]

        // The fold's positions are physical, measured from the view's leading edge like the
        // other fold splits
        let rowStart = bottomRowStack.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        bottomRowStartConstraint = rowStart
        sidewaysConstraints = [
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            rowStart
        ]

        let raisedBottom = raisedContainer.bottomAnchor.constraint(equalTo: view.topAnchor)
        let baseTop = collectionView.topAnchor.constraint(equalTo: view.topAnchor)
        raisedBottomConstraint = raisedBottom
        baseTopConstraint = baseTop
        uprightConstraints = [raisedBottom, baseTop, fullWidthRow()]

        NSLayoutConstraint.activate(singleConstraints)
    }

    func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) {
            [weak self] collectionView, indexPath, item in
            switch item {
            case .summary:
                let cell =
                    collectionView.dequeueReusableCell(
                        withReuseIdentifier: SimilarSummaryCell.reuseIdentifier, for: indexPath)
                    as! SimilarSummaryCell
                self?.configureSummary(cell.summaryView)
                return cell
            case .set(let signature):
                let cell =
                    collectionView.dequeueReusableCell(
                        withReuseIdentifier: SimilarSetCell.reuseIdentifier, for: indexPath)
                    as! SimilarSetCell
                if let self, let index = self.indexBySignature[signature] {
                    self.configureCard(cell.cardView, forSetAt: index)
                }
                return cell
            }
        }
    }

    // MARK: Compositional layout

    func makeListLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            self?.listSection(at: sectionIndex)
        }
    }

    private func listSection(at sectionIndex: Int) -> NSCollectionLayoutSection? {
        guard let sections = dataSource?.snapshot().sectionIdentifiers, sectionIndex < sections.count
        else { return nil }
        let metrics = listMetrics
        let splitsColumns =
            metrics.layout == .sideways && metrics.firstColumnWidth > 0 && metrics.secondColumnWidth > 0

        switch sections[sectionIndex] {
        case .summary:
            // Sideways the summary spans the first column only
            let width: NSCollectionLayoutDimension =
                splitsColumns ? .absolute(metrics.firstColumnWidth) : .fractionalWidth(1)
            let height = NSCollectionLayoutDimension.estimated(Layout.estimatedSummaryHeight)
            let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: width, heightDimension: height))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: height), subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(
                top: Layout.listTopInset, leading: 0, bottom: metrics.spacing, trailing: 0)
            return section

        case .sets:
            let height = NSCollectionLayoutDimension.estimated(Layout.estimatedCardHeight)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: height)
            let group: NSCollectionLayoutGroup
            if splitsColumns {
                // Pairs, one set on each side of the fold; each row is top-aligned
                let first = NSCollectionLayoutItem(
                    layoutSize: .init(widthDimension: .absolute(metrics.firstColumnWidth), heightDimension: height))
                let second = NSCollectionLayoutItem(
                    layoutSize: .init(widthDimension: .absolute(metrics.secondColumnWidth), heightDimension: height))
                group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [first, second])
                group.interItemSpacing = .fixed(metrics.columnGap)
            } else {
                let item = NSCollectionLayoutItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: height))
                group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            }
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = metrics.spacing
            // The list's content inset keeps the last card above the bottom row
            section.contentInsets = NSDirectionalEdgeInsets(
                top: metrics.layout == .upright ? Layout.listTopInset : 0,
                leading: 0, bottom: 0, trailing: 0)
            return section
        }
    }

    /// Stores what the layout is built from and rebuilds it when that changed.
    func setListMetrics(_ metrics: ListMetrics) {
        guard metrics != listMetrics else { return }
        listMetrics = metrics
        collectionView.collectionViewLayout.invalidateLayout()
    }

    // MARK: Snapshot

    /// The list's items for the current layout: the summary line (not upright, where the raised
    /// half has the summary card) and every set but the spotlight's.
    func applySnapshot(animated: Bool = false, reloading: Bool = false) {
        guard let dataSource else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        if splitLayout != .upright {
            snapshot.appendSections([.summary])
            snapshot.appendItems([.summary], toSection: .summary)
        }
        snapshot.appendSections([.sets])
        let hidden = splitLayout == .upright ? spotlightIndex : nil
        snapshot.appendItems(
            similarGroups.indices.filter { $0 != hidden }.map { .set(signatures[$0]) }, toSection: .sets)

        if reloading {
            dataSource.applySnapshotUsingReloadData(snapshot)
        } else {
            dataSource.apply(snapshot, animatingDifferences: animated)
        }
    }

    // MARK: Cards

    func configureCard(_ card: SimilarSetCardView, forSetAt index: Int) {
        guard index < similarGroups.count else { return }
        let group = similarGroups[index]
        let signature = signatures[index]
        card.configure(
            index: index, signature: signature, assets: group.assets,
            bestAssetId: group.bestAsset?.localIdentifier,
            states: setStates[index] ?? [:],
            sizes: sizesBySignature[signature],
            isConfirmed: processedGroupIndexes.contains(index))
        card.onConfirm = { [weak self] in self?.confirmSet(at: index) }
        card.onUndo = { [weak self] in self?.undoSet(at: index) }
        card.onStatesChange = { [weak self] states in
            self?.setStates[index] = states
            self?.refreshSummary()
        }
        card.onInteraction = { [weak self, weak card] in self?.exitStoreModeOnAllCards(except: card) }
    }

    /// The card showing a set right now: the spotlight, a visible cell, or nil.
    func visibleCard(forSetAt index: Int) -> SimilarSetCardView? {
        guard index < signatures.count else { return nil }
        if splitLayout == .upright, spotlightIndex == index, !spotlightCardView.isHidden {
            return spotlightCardView
        }
        guard let indexPath = dataSource?.indexPath(for: .set(signatures[index])) else { return nil }
        return (collectionView.cellForItem(at: indexPath) as? SimilarSetCell)?.cardView
    }

    private var visibleCards: [SimilarSetCardView] {
        var cards = collectionView.visibleCells.compactMap { ($0 as? SimilarSetCell)?.cardView }
        if !spotlightCardView.isHidden { cards.append(spotlightCardView) }
        return cards
    }

    /// One store mode at a time.
    func exitStoreModeOnAllCards(except card: SimilarSetCardView?) {
        guard isViewLoaded else { return }
        for visible in visibleCards where visible !== card {
            visible.exitStoreModeIfNeeded()
        }
    }

    func refreshVisibleCardSizes() {
        for card in visibleCards {
            guard let signature = card.signature else { continue }
            card.updateSizes(sizesBySignature[signature])
        }
    }

    // MARK: Summary and bottom row

    /// The size of the photos marked delete in sets not yet confirmed; nil until sizes are in.
    private var bytesToFree: Int64? {
        var total: Int64 = 0
        for index in unconfirmedIndices {
            guard let sizes = sizesBySignature[signatures[index]] else { return nil }
            for (assetId, state) in setStates[index] ?? [:] where state == .delete {
                total += sizes[assetId] ?? 0
            }
        }
        return total
    }

    func configureSummary(_ summaryView: SimilarSummaryView) {
        summaryView.configure(
            setsToCheck: unconfirmedIndices.count, done: processedGroupIndexes.count, bytesToFree: bytesToFree)
    }

    /// The summary line (or card) and "Confirm all", after a mark, a confirm or an undo.
    func refreshSummary() {
        configureSummary(raisedSummaryView)
        if let indexPath = dataSource?.indexPath(for: .summary),
           let cell = collectionView.cellForItem(at: indexPath) as? SimilarSummaryCell {
            configureSummary(cell.summaryView)
        }
        applyConfirmAllButton()
    }

    /// An ink pill; the colors are resolved for the current appearance, because the glass
    /// doesn't keep a dynamic title color legible (as the month hub's Continue pill).
    func applyConfirmAllButton() {
        let count = unconfirmedIndices.count
        confirmAllButton.configure(
            title: Strings.confirmAll(count),
            style: .prominent,
            backgroundColor: UIColor.label.resolvedColor(with: traitCollection),
            foregroundColor: UIColor.systemBackground.resolvedColor(with: traitCollection),
            fontSize: 16,
            fontWeight: .bold)
        confirmAllButton.titleLabel?.adjustsFontSizeToFitWidth = true
        confirmAllButton.isEnabled = count > 0
    }

    func applyAppearanceColors() {
        applyConfirmAllButton()
    }

    // MARK: Short column

    /// iPhone SE and the Duo's cover display: tighter gaps and 50pt bottom-row buttons, from
    /// the view's own height.
    func updateShortColumn() {
        let isShort = view.bounds.height > 0 && view.bounds.height <= Layout.shortColumnHeight
        guard isShort != isShortColumn else { return }
        isShortColumn = isShort
        bottomRowHeightConstraint?.constant =
            isShort ? GeneralConstants.ButtonSize.mediumLarge : GeneralConstants.ButtonSize.large
        bottomRowStack.spacing = isShort ? Layout.compactCardSpacing : Layout.cardSpacing
    }

    /// The list runs to the bottom edge under the bottom row: its content ends above the row.
    func updateListInsets() {
        defer { updateBottomBlur() }
        let rowTop = bottomRowContainer.frame.minY - Layout.listToBottomRow
        let bottomInset = max(0, collectionView.frame.maxY - rowTop - collectionView.safeAreaInsets.bottom)
        guard collectionView.contentInset.bottom != bottomInset else { return }
        collectionView.contentInset.bottom = bottomInset
        collectionView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    /// The blur shows only while cards are under it, so the list's end rests clear.
    func updateBottomBlur() {
        let visibleBottom = collectionView.contentOffset.y + collectionView.bounds.height
            - collectionView.adjustedContentInset.bottom
        listBottomBlurView.setContentOverlap(collectionView.contentSize.height - visibleBottom)
    }

    // MARK: Bin slot

    /// The bin shows its count and opens this month's bin; it sits in the bottom row's slot.
    func configureGlobalBinButton() {
        binController?.configureBinButton(
            mode: .count(DeleteBinStore.shared.count),
            monthKey: monthKey,
            monthTitle: monthTitle,
            tapHandler: nil)
        binController?.showBinButton()
        binSlotCount = DeleteBinStore.shared.count
        updateBinSlotWidth()
    }

    func updateBinSlotWidth() {
        let width = FloatingBinButton.slotWidth(forCount: binSlotCount)
        guard let constraint = binSlotWidthConstraint, constraint.constant != width else { return }
        constraint.constant = width
        view.setNeedsLayout()
    }

    /// Hands the bottom row's slot to the global bin whenever it moves.
    func updateBinSlot() {
        guard !listContentView.isHidden, !isShowingEmptyState, binSlotView.window != nil,
              navigationController?.topViewController === self
        else { return }
        let slot = binSlotView.convert(binSlotView.bounds, to: nil)
        guard slot.width > 0, slot.height > 0, slot != lastSentBinSlot else { return }
        lastSentBinSlot = slot
        binController?.setBinButtonPlacement(.slot(slot, matchesHeight: true))
    }
}
