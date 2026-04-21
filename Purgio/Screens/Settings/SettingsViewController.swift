//
//  SettingsViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import SwiftUI
import UIKit

// MARK: - Strings
private enum Strings {
    static let navTitle = NSLocalizedString("settings.navTitle", comment: "Settings navigation title")

    static let yourImpact = NSLocalizedString("settings.yourImpact", comment: "Your impact section header")
    static let storageAnalysis = NSLocalizedString("settings.storageAnalysis", comment: "Storage analysis section header")
    static let photoManagement = NSLocalizedString("settings.photoManagement", comment: "Photo management section header")
    static let features = NSLocalizedString("settings.features", comment: "Features section header")
    static let transparencySafety = NSLocalizedString("settings.transparencySafety", comment: "Transparency & safety section header")
    static let about = NSLocalizedString("settings.about", comment: "About section header")
    static let version = NSLocalizedString("settings.version", comment: "App version label")
    static let madeBy = NSLocalizedString("settings.madeBy", comment: "Made by credit")

    static let internetTitle = NSLocalizedString("settings.internetTitle", comment: "Internet access toggle title")
    static let internetSubtitle = NSLocalizedString("settings.internetSubtitle", comment: "Internet access toggle subtitle")
    static let skipICloudTitle = NSLocalizedString("settings.skipICloudTitle", comment: "Skip iCloud photos toggle title")
    static let skipICloudSubtitle = NSLocalizedString("settings.skipICloudSubtitle", comment: "Skip iCloud photos toggle subtitle")
    static let remindersTitle = NSLocalizedString("settings.remindersTitle", comment: "Reminders section title")

    static let privacyTitle = NSLocalizedString("settings.privacyTitle", comment: "Privacy first info title")
    static let privacyText = NSLocalizedString("settings.privacyText", comment: "Privacy first explanation")
    static let storeTitle = NSLocalizedString("settings.storeTitle", comment: "Store feature info title")
    static let storeText = NSLocalizedString("settings.storeText", comment: "Store feature explanation")
    static let transparencyTitle = NSLocalizedString("settings.transparencyTitle", comment: "Transparency info title")
    static let transparencyText = NSLocalizedString("settings.transparencyText", comment: "Transparency explanation")
    static let viewSourceCode = NSLocalizedString("settings.viewSourceCode", comment: "View source code button")

    static let internetOnMessage = NSLocalizedString("settings.internetOnMessage", comment: "Internet enabled toast")
    static let internetOffMessage = NSLocalizedString("settings.internetOffMessage", comment: "Internet disabled toast")
    static let skipICloudOnMessage = NSLocalizedString("settings.skipICloudOnMessage", comment: "Skip iCloud enabled toast")
    static let skipICloudOffMessage = NSLocalizedString("settings.skipICloudOffMessage", comment: "Skip iCloud disabled toast")

    static let notificationsDisabled = NSLocalizedString("settings.notificationsDisabled", comment: "Notifications disabled alert title")
    static let notificationsDeniedMessage = NSLocalizedString("settings.notificationsDeniedMessage", comment: "Notifications denied message")
    static let ok = CommonStrings.ok

    static let schedule = NSLocalizedString("settings.schedule", comment: "Schedule label")
    static let daily = NSLocalizedString("settings.daily", comment: "Daily frequency option")
    static let weekly = NSLocalizedString("settings.weekly", comment: "Weekly frequency option")
    static let monthly = NSLocalizedString("settings.monthly", comment: "Monthly frequency option")

    static let support = NSLocalizedString("settings.support", comment: "Support section header")
    static let supportTitle = NSLocalizedString("settings.supportTitle", comment: "Support project title")
    static let supportText = NSLocalizedString("settings.supportText", comment: "Support project description")
    static let supportButton = NSLocalizedString("settings.supportButton", comment: "Support on Patreon button")

    static let languageTitle = NSLocalizedString("settings.languageTitle", comment: "App language title")
    static let languageSubtitle = NSLocalizedString("settings.languageSubtitle", comment: "Available languages subtitle")
    static let languageButton = NSLocalizedString("settings.languageButton", comment: "Change language in settings button")
}

final class SettingsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let statsSectionLabel = UILabel()
    private let impactStatsView = ImpactStatsView()

    private let storageSectionLabel = UILabel()
    private let storageAnalysisView = StorageAnalysisView()

    private let photoSectionLabel = UILabel()
    private let internetToggleContainer = UIView()
    private let internetLabelsStack = UIStackView()
    private let internetTitleLabel = UILabel()
    private let internetSubtitleLabel = UILabel()
    private let internetSwitch = UISwitch()
    private let skipICloudToggleContainer = UIView()
    private let skipICloudLabelsStack = UIStackView()
    private let skipICloudTitleLabel = UILabel()
    private let skipICloudSubtitleLabel = UILabel()
    private let skipICloudSwitch = UISwitch()
    private let remindersToggleContainer = UIView()
    private let remindersContentStack = UIStackView()
    private let remindersTopRow = UIView()
    private let remindersTitleLabel = UILabel()
    private let remindersSwitch = UISwitch()
    private let scheduleRow = UIView()
    private let scheduleSeparator = UIView()
    private let scheduleTitleLabel = UILabel()
    private let scheduleButton = UIButton(type: .system)

    private let privacyCard = SettingsInfoCardView()
    private let storeSectionLabel = UILabel()
    private let storeCard = SettingsInfoCardView()
    private let transparencySectionLabel = UILabel()
    private let transparencyCard = SettingsInfoCardView()
    private let supportSectionLabel = UILabel()
    private let supportCard = SettingsInfoCardView()
    private let languageCard = SettingsInfoCardView()

    private let aboutSectionLabel = UILabel()
    private let madeByLabel = UILabel()
    private let versionLabel = UILabel()

    private let settingsStore = SettingsStore.shared
    private let statsStore = StatsStore.shared
    private let storedStore = WillBeStoredStore.shared
    private let storageManager = StorageAnalysisManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground
        title = Strings.navTitle

        let tipJarButton = UIBarButtonItem(
            image: UIImage(systemName: "heart.fill"),
            style: .plain,
            target: self,
            action: #selector(tipJarBarButtonTapped)
        )
        tipJarButton.tintColor = .tipJarRed100
        tipJarButton.accessibilityLabel = Strings.supportTitle
        navigationItem.rightBarButtonItem = tipJarButton

        setupUI()
        setupConstraint()
        setupNotifications()
        updateInternetToggleState()
        updateSkipICloudToggleState()
        updateRemindersToggleState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        impactStatsView.update(stats: statsStore, storedCount: storedStore.count)
        storageAnalysisView.update(with: storageManager.currentState)
        updateInternetToggleState()
        updateSkipICloudToggleState()
        updateRemindersToggleState()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        updateButtonIcons()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageAnalysisStateChanged),
            name: .storageAnalysisDidStart,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageAnalysisStateChanged),
            name: .storageAnalysisDidFetchBasicInfo,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageAnalysisStateChanged),
            name: .storageAnalysisDidComplete,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageAnalysisStateChanged),
            name: .storageAnalysisDidFail,
            object: nil
        )
    }

    @objc private func storageAnalysisStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.storageAnalysisView.update(with: self.storageManager.currentState)
        }
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .mainBackground
        view.addSubview(scrollView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 24
        scrollView.addSubview(contentStack)

        statsSectionLabel.text = Strings.yourImpact
        statsSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        statsSectionLabel.textColor = .systemGray
        contentStack.addArrangedSubview(statsSectionLabel)

        contentStack.addArrangedSubview(impactStatsView)

        storageSectionLabel.text = Strings.storageAnalysis
        storageSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        storageSectionLabel.textColor = .systemGray
        contentStack.addArrangedSubview(storageSectionLabel)

        storageAnalysisView.translatesAutoresizingMaskIntoConstraints = false
        storageAnalysisView.onRefreshTapped = { [weak self] in
            HapticFeedbackManager.shared.impact(intensity: .light)
            self?.storageManager.startAnalysis()
        }
        storageAnalysisView.update(with: storageManager.currentState)
        contentStack.addArrangedSubview(storageAnalysisView)

        photoSectionLabel.text = Strings.photoManagement
        photoSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        photoSectionLabel.textColor = .systemGray
        contentStack.addArrangedSubview(photoSectionLabel)

        internetToggleContainer.backgroundColor = .cardBackground
        internetToggleContainer.layer.cornerRadius = 14
        internetToggleContainer.layer.borderWidth = 0
        internetToggleContainer.layer.borderColor = UIColor.separator.cgColor
        internetToggleContainer.translatesAutoresizingMaskIntoConstraints = false

        internetLabelsStack.axis = .vertical
        internetLabelsStack.spacing = 4
        internetLabelsStack.translatesAutoresizingMaskIntoConstraints = false

        internetTitleLabel.text = Strings.internetTitle
        internetTitleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        internetTitleLabel.textColor = .label
        internetLabelsStack.addArrangedSubview(internetTitleLabel)

        internetSubtitleLabel.text = Strings.internetSubtitle
        internetSubtitleLabel.font = .systemFont(ofSize: 14)
        internetSubtitleLabel.textColor = .systemGray
        internetSubtitleLabel.numberOfLines = 0
        internetLabelsStack.addArrangedSubview(internetSubtitleLabel)

        internetSwitch.translatesAutoresizingMaskIntoConstraints = false
        internetSwitch.addTarget(self, action: #selector(internetSwitchChanged), for: .valueChanged)

        internetToggleContainer.addSubview(internetLabelsStack)
        internetToggleContainer.addSubview(internetSwitch)
        contentStack.addArrangedSubview(internetToggleContainer)

        skipICloudToggleContainer.backgroundColor = .cardBackground
        skipICloudToggleContainer.layer.cornerRadius = 14
        skipICloudToggleContainer.layer.borderWidth = 0
        skipICloudToggleContainer.layer.borderColor = UIColor.separator.cgColor
        skipICloudToggleContainer.translatesAutoresizingMaskIntoConstraints = false

        skipICloudLabelsStack.axis = .vertical
        skipICloudLabelsStack.spacing = 4
        skipICloudLabelsStack.translatesAutoresizingMaskIntoConstraints = false

        skipICloudTitleLabel.text = Strings.skipICloudTitle
        skipICloudTitleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        skipICloudTitleLabel.textColor = .label
        skipICloudLabelsStack.addArrangedSubview(skipICloudTitleLabel)

        skipICloudSubtitleLabel.text = Strings.skipICloudSubtitle
        skipICloudSubtitleLabel.font = .systemFont(ofSize: 14)
        skipICloudSubtitleLabel.textColor = .systemGray
        skipICloudSubtitleLabel.numberOfLines = 0
        skipICloudLabelsStack.addArrangedSubview(skipICloudSubtitleLabel)

        skipICloudSwitch.translatesAutoresizingMaskIntoConstraints = false
        skipICloudSwitch.addTarget(self, action: #selector(skipICloudSwitchChanged), for: .valueChanged)

        skipICloudToggleContainer.addSubview(skipICloudLabelsStack)
        skipICloudToggleContainer.addSubview(skipICloudSwitch)
        contentStack.addArrangedSubview(skipICloudToggleContainer)

        remindersToggleContainer.backgroundColor = .cardBackground
        remindersToggleContainer.layer.cornerRadius = 14
        remindersToggleContainer.layer.borderWidth = 0
        remindersToggleContainer.layer.borderColor = UIColor.separator.cgColor
        remindersToggleContainer.clipsToBounds = true
        remindersToggleContainer.translatesAutoresizingMaskIntoConstraints = false

        remindersContentStack.axis = .vertical
        remindersContentStack.spacing = 0
        remindersContentStack.translatesAutoresizingMaskIntoConstraints = false

        remindersTopRow.translatesAutoresizingMaskIntoConstraints = false

        remindersTitleLabel.text = Strings.remindersTitle
        remindersTitleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        remindersTitleLabel.textColor = .label
        remindersTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        remindersSwitch.translatesAutoresizingMaskIntoConstraints = false
        remindersSwitch.addTarget(self, action: #selector(remindersSwitchChanged), for: .valueChanged)

        remindersTopRow.addSubview(remindersTitleLabel)
        remindersTopRow.addSubview(remindersSwitch)

        scheduleSeparator.backgroundColor = .separator
        scheduleSeparator.translatesAutoresizingMaskIntoConstraints = false

        scheduleRow.translatesAutoresizingMaskIntoConstraints = false
        scheduleRow.isHidden = !settingsStore.remindersEnabled
        scheduleRow.alpha = settingsStore.remindersEnabled ? 1 : 0

        scheduleTitleLabel.text = Strings.schedule
        scheduleTitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        scheduleTitleLabel.textColor = .secondaryLabel
        scheduleTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        scheduleButton.translatesAutoresizingMaskIntoConstraints = false
        scheduleButton.showsMenuAsPrimaryAction = true
        scheduleButton.contentHorizontalAlignment = .trailing
        updateScheduleMenu()

        scheduleRow.addSubview(scheduleSeparator)
        scheduleRow.addSubview(scheduleTitleLabel)
        scheduleRow.addSubview(scheduleButton)

        remindersContentStack.addArrangedSubview(remindersTopRow)
        remindersContentStack.addArrangedSubview(scheduleRow)
        remindersToggleContainer.addSubview(remindersContentStack)

        privacyCard.configure(with: SettingsInfoCardConfig(
            iconName: "lock.shield", iconColor: .systemBlue,
            title: Strings.privacyTitle, subtitle: Strings.privacyText
        ))

        storeCard.configure(with: SettingsInfoCardConfig(
            iconName: "archivebox.fill", iconColor: ThemeManager.Colors.statusYellow,
            title: Strings.storeTitle, subtitle: Strings.storeText
        ))
        storeCard.onCardTapped = { [weak self] in
            HapticFeedbackManager.shared.impact(intensity: .light)
            let tutorial = StoreTutorialSheetViewController()
            self?.present(tutorial, animated: true)
        }

        transparencyCard.configure(with: SettingsInfoCardConfig(
            iconName: "checkmark.shield.fill", iconColor: .systemGreen,
            title: Strings.transparencyTitle, subtitle: Strings.transparencyText,
            themeColor: .systemGreen,
            buttonTitle: Strings.viewSourceCode, buttonImageName: "GitHub_Invertocat"
        ))
        transparencyCard.onButtonTapped = {
            if let url = URL(string: "https://github.com/zeynepmuslim/secure-photo-cleaner-app") {
                UIApplication.shared.open(url)
                HapticFeedbackManager.shared.impact(intensity: .light)
            }
        }

        supportCard.configure(with: SettingsInfoCardConfig(
            iconName: "heart.fill", iconColor: .tipJarRed100,
            title: Strings.supportTitle, subtitle: Strings.supportText,
            themeColor: .tipJarRed100,
            buttonTitle: Strings.supportButton, buttonIconName: "sparkles"
        ))
        supportCard.onButtonTapped = { [weak self] in
            self?.tipJarBarButtonTapped()
        }

        languageCard.configure(with: SettingsInfoCardConfig(
            iconName: "globe", iconColor: .systemBlue,
            title: Strings.languageTitle, subtitle: Strings.languageSubtitle,
            themeColor: .systemBlue,
            buttonTitle: Strings.languageButton, buttonIconName: "gear"
        ))
        languageCard.onButtonTapped = {
            HapticFeedbackManager.shared.impact(intensity: .light)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }

        storeSectionLabel.text = Strings.features
        storeSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        storeSectionLabel.textColor = .systemGray
        contentStack.addArrangedSubview(storeSectionLabel)

        contentStack.addArrangedSubview(remindersToggleContainer)

        contentStack.addArrangedSubview(languageCard)

        contentStack.addArrangedSubview(storeCard)

        transparencySectionLabel.text = Strings.transparencySafety
        transparencySectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        transparencySectionLabel.textColor = .systemGray
        contentStack.addArrangedSubview(transparencySectionLabel)

        contentStack.addArrangedSubview(privacyCard)

        contentStack.addArrangedSubview(transparencyCard)

        supportSectionLabel.text = Strings.support
        supportSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        supportSectionLabel.textColor = .systemGray
        contentStack.addArrangedSubview(supportSectionLabel)

        contentStack.addArrangedSubview(supportCard)

        aboutSectionLabel.text = Strings.about
        aboutSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        aboutSectionLabel.textColor = .systemGray
        contentStack.addArrangedSubview(aboutSectionLabel)
        contentStack.setCustomSpacing(12, after: aboutSectionLabel)

        versionLabel.text = "\(Strings.version) 1.0"
        versionLabel.font = .systemFont(ofSize: 15, weight: .bold)
        versionLabel.textColor = .systemGray2
        contentStack.addArrangedSubview(versionLabel)
        contentStack.setCustomSpacing(4, after: versionLabel)

        madeByLabel.text = Strings.madeBy
        madeByLabel.font = .systemFont(ofSize: 13)
        madeByLabel.textColor = .systemGray2
        contentStack.addArrangedSubview(madeByLabel)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),

            internetToggleContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 70),

            internetLabelsStack.topAnchor.constraint(equalTo: internetToggleContainer.topAnchor, constant: 16),
            internetLabelsStack.leadingAnchor.constraint(equalTo: internetToggleContainer.leadingAnchor, constant: 18),
            internetLabelsStack.bottomAnchor.constraint(equalTo: internetToggleContainer.bottomAnchor, constant: -16),
            internetLabelsStack.trailingAnchor.constraint(equalTo: internetSwitch.leadingAnchor, constant: -16),

            internetSwitch.centerYAnchor.constraint(equalTo: internetToggleContainer.centerYAnchor),
            internetSwitch.trailingAnchor.constraint(equalTo: internetToggleContainer.trailingAnchor, constant: -18),

            skipICloudToggleContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 70),

            skipICloudLabelsStack.topAnchor.constraint(equalTo: skipICloudToggleContainer.topAnchor, constant: 16),
            skipICloudLabelsStack.leadingAnchor.constraint(
                equalTo: skipICloudToggleContainer.leadingAnchor, constant: 18),
            skipICloudLabelsStack.bottomAnchor.constraint(
                equalTo: skipICloudToggleContainer.bottomAnchor, constant: -16),
            skipICloudLabelsStack.trailingAnchor.constraint(equalTo: skipICloudSwitch.leadingAnchor, constant: -16),

            skipICloudSwitch.centerYAnchor.constraint(equalTo: skipICloudToggleContainer.centerYAnchor),
            skipICloudSwitch.trailingAnchor.constraint(
                equalTo: skipICloudToggleContainer.trailingAnchor, constant: -18),

            remindersContentStack.topAnchor.constraint(equalTo: remindersToggleContainer.topAnchor),
            remindersContentStack.leadingAnchor.constraint(equalTo: remindersToggleContainer.leadingAnchor),
            remindersContentStack.trailingAnchor.constraint(equalTo: remindersToggleContainer.trailingAnchor),
            remindersContentStack.bottomAnchor.constraint(equalTo: remindersToggleContainer.bottomAnchor),

            remindersTitleLabel.topAnchor.constraint(equalTo: remindersTopRow.topAnchor, constant: 16),
            remindersTitleLabel.leadingAnchor.constraint(equalTo: remindersTopRow.leadingAnchor, constant: 18),
            remindersTitleLabel.bottomAnchor.constraint(equalTo: remindersTopRow.bottomAnchor, constant: -16),
            remindersTitleLabel.trailingAnchor.constraint(equalTo: remindersSwitch.leadingAnchor, constant: -16),

            remindersSwitch.centerYAnchor.constraint(equalTo: remindersTopRow.centerYAnchor),
            remindersSwitch.trailingAnchor.constraint(equalTo: remindersTopRow.trailingAnchor, constant: -18),

            scheduleSeparator.topAnchor.constraint(equalTo: scheduleRow.topAnchor),
            scheduleSeparator.leadingAnchor.constraint(equalTo: scheduleRow.leadingAnchor, constant: 18),
            scheduleSeparator.trailingAnchor.constraint(equalTo: scheduleRow.trailingAnchor, constant: -18),
            scheduleSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            scheduleTitleLabel.topAnchor.constraint(equalTo: scheduleSeparator.bottomAnchor, constant: 12),
            scheduleTitleLabel.leadingAnchor.constraint(equalTo: scheduleRow.leadingAnchor, constant: 18),
            scheduleTitleLabel.bottomAnchor.constraint(equalTo: scheduleRow.bottomAnchor, constant: -12),

            scheduleButton.centerYAnchor.constraint(equalTo: scheduleTitleLabel.centerYAnchor),
            scheduleButton.trailingAnchor.constraint(equalTo: scheduleRow.trailingAnchor, constant: -18),
            scheduleButton.leadingAnchor.constraint(
                greaterThanOrEqualTo: scheduleTitleLabel.trailingAnchor, constant: 12),

        ])
    }

    func scrollToInternetToggle() {
        let targetY = internetToggleContainer.convert(.zero, to: scrollView).y
        let topInset = scrollView.adjustedContentInset.top
        let maxOffsetY = scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
        let offsetY = min(max(targetY - topInset - 16, 0), max(maxOffsetY, 0))
        scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.highlightInternetToggle()
        }
    }

    private func highlightInternetToggle() {
        HapticFeedbackManager.shared.impact(intensity: .medium)

        let originalColor = internetToggleContainer.backgroundColor
        let originalBorderWidth = internetToggleContainer.layer.borderWidth
        let originalBorderColor = internetToggleContainer.layer.borderColor

        UIView.animate(withDuration: 0.3, animations: {
            self.internetToggleContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
            self.internetToggleContainer.layer.borderWidth = 2
            self.internetToggleContainer.layer.borderColor = UIColor.systemBlue.cgColor
        }) { _ in
            UIView.animate(withDuration: 0.8, delay: 0.6) {
                self.internetToggleContainer.backgroundColor = originalColor
                self.internetToggleContainer.layer.borderWidth = originalBorderWidth
                self.internetToggleContainer.layer.borderColor = originalBorderColor
            }
        }
    }

    @objc private func internetSwitchChanged() {
        settingsStore.allowInternetAccess = internetSwitch.isOn
        HapticFeedbackManager.shared.impact(intensity: .medium)
        updateSkipICloudVisibility()
    }

    @objc private func skipICloudSwitchChanged() {
        settingsStore.skipICloudPhotos = skipICloudSwitch.isOn
        HapticFeedbackManager.shared.impact(intensity: .medium)
    }

    @objc private func tipJarBarButtonTapped() {
        HapticFeedbackManager.shared.impact(intensity: .light)
        let tipJar = TipJarViewController()
        tipJar.onRestoredInternet = { [weak self] in
            self?.showInternetRestoredConfirmation()
        }
        present(tipJar, animated: true)
    }

    @objc private func remindersSwitchChanged() {
        let isOn = remindersSwitch.isOn

        if isOn {
            ReminderNotificationService.shared.requestAuthorization { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    self.settingsStore.remindersEnabled = true
                    ReminderNotificationService.shared.scheduleReminders()
                } else {
                    self.settingsStore.remindersEnabled = false
                    self.remindersSwitch.isOn = false
                    self.showRemindersDeniedAlert()
                }

                self.updateSchedulePickerVisibility()
            }
        } else {
            settingsStore.remindersEnabled = false
            ReminderNotificationService.shared.syncScheduleIfNeeded()

            updateSchedulePickerVisibility()
        }

        HapticFeedbackManager.shared.impact(intensity: .medium)
    }

    private func updateButtonIcons() {
        transparencyCard.refreshButtonIcon()
    }

    private func updateInternetToggleState() {
        let isOn = settingsStore.allowInternetAccess
        if internetSwitch.isOn != isOn { internetSwitch.isOn = isOn }

        internetSwitch.onTintColor = .systemGreen

        updateSkipICloudVisibility()
    }

    private func updateSkipICloudToggleState() {
        let isOn = settingsStore.skipICloudPhotos
        if skipICloudSwitch.isOn != isOn { skipICloudSwitch.isOn = isOn }

        skipICloudSwitch.onTintColor = .systemGreen

        updateSkipICloudVisibility()
    }

    private func updateSkipICloudVisibility() {
        let shouldShow = !settingsStore.allowInternetAccess
        let shouldHide = !shouldShow
        guard skipICloudToggleContainer.isHidden != shouldHide else { return }
        UIView.animate(withDuration: 0.3) {
            self.skipICloudToggleContainer.isHidden = shouldHide
            self.skipICloudToggleContainer.alpha = shouldHide ? 0 : 1
            self.view.layoutIfNeeded()
        }
    }

    private func updateRemindersToggleState() {
        let isOn = settingsStore.remindersEnabled
        if remindersSwitch.isOn != isOn { remindersSwitch.isOn = isOn }

        remindersSwitch.onTintColor = .systemGreen

        updateSchedulePickerVisibility()
        updateScheduleMenu()
    }

    private func showRemindersDeniedAlert() {
        let alert = UIAlertController(
            title: Strings.notificationsDisabled,
            message: Strings.notificationsDeniedMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Strings.ok, style: .default))
        present(alert, animated: true)
    }

    private func showInternetRestoredConfirmation() {
        let message = NSLocalizedString(
            "tipJar.internetRestored",
            comment: "Feedback when tip jar automatically turned internet access off"
        )
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            alert.dismiss(animated: true)
        }
    }

    private func updateScheduleMenu() {
        let currentFrequency = settingsStore.reminderFrequency

        let dailyAction = UIAction(
            title: Strings.daily,
            state: currentFrequency == .daily ? .on : .off
        ) { [weak self] _ in
            self?.applySchedulePreset(.dailyEvening)
        }

        let weeklyAction = UIAction(
            title: Strings.weekly,
            state: currentFrequency == .weekly ? .on : .off
        ) { [weak self] _ in
            self?.applySchedulePreset(.weeklyEvening)
        }

        let monthlyAction = UIAction(
            title: Strings.monthly,
            state: currentFrequency == .monthly ? .on : .off
        ) { [weak self] _ in
            self?.applySchedulePreset(.monthlyFirstEvening)
        }

        scheduleButton.menu = UIMenu(children: [dailyAction, weeklyAction, monthlyAction])

        switch currentFrequency {
        case .daily: scheduleButton.setTitle(Strings.daily, for: .normal)
        case .weekly: scheduleButton.setTitle(Strings.weekly, for: .normal)
        case .monthly: scheduleButton.setTitle(Strings.monthly, for: .normal)
        }
    }

    private func applySchedulePreset(_ preset: SettingsStore.ReminderSchedulePreset) {
        settingsStore.applyReminderSchedule(preset)
        updateScheduleMenu()

        if settingsStore.remindersEnabled {
            ReminderNotificationService.shared.scheduleReminders()
        }

        HapticFeedbackManager.shared.impact(intensity: .light)
    }

    private func updateSchedulePickerVisibility() {
        let shouldShow = settingsStore.remindersEnabled
        let shouldHide = !shouldShow
        guard scheduleRow.isHidden != shouldHide else { return }
        UIView.animate(withDuration: 0.3) {
            self.scheduleRow.isHidden = shouldHide
            self.scheduleRow.alpha = shouldHide ? 0 : 1
            self.view.layoutIfNeeded()
        }
    }

}

@available(iOS 17.0, *)
#Preview {
    SettingsViewController()
}
