//
//  SettingsViewController.swift
//  Secure Photo Cleaner
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

    private let privacyNoticeContainer = UIView()
    private let privacyIconView = UIImageView()
    private let privacyTitleLabel = UILabel()
    private let privacyTextLabel = UILabel()
    private let privacyContentStack = UIStackView()
    private let privacyTopStack = UIStackView()

    private let storeSectionLabel = UILabel()
    private let storeInfoContainer = UIView()
    private let storeIconView = UIImageView()
    private let storeTitleLabel = UILabel()
    private let storeTextLabel = UILabel()
    private let storeContentStack = UIStackView()
    private let storeTopStack = UIStackView()

    private let transparencySectionLabel = UILabel()
    private let transparencyContainer = UIView()
    private let transparencyIconView = UIImageView()
    private let transparencyTitleLabel = UILabel()
    private let transparencyTextLabel = UILabel()
    private let githubButton = UIButton(type: .system)
    private let transparencyContentStack = UIStackView()
    private let transparencyTopStack = UIStackView()

    private let supportSectionLabel = UILabel()
    private let supportContainer = UIView()
    private let supportIconView = UIImageView()
    private let supportTitleLabel = UILabel()
    private let supportTextLabel = UILabel()
    private let patreonButton = UIButton(type: .system)
    private let supportContentStack = UIStackView()
    private let supportTopStack = UIStackView()

    private let languageContainer = UIView()
    private let languageTitleLabel = UILabel()
    private let languageSubtitleLabel = UILabel()
    private let languageButton = UIButton(type: .system)
    private let languageContentStack = UIStackView()
    private let languageTopStack = UIStackView()
    private let languageIconView = UIImageView()

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

        privacyNoticeContainer.backgroundColor = .cardBackground
        privacyNoticeContainer.layer.cornerRadius = 14
        privacyNoticeContainer.layer.borderWidth = 0
        privacyNoticeContainer.layer.borderColor = UIColor.separator.cgColor
        privacyNoticeContainer.translatesAutoresizingMaskIntoConstraints = false

        let lockConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        privacyIconView.image = UIImage(systemName: "lock.shield", withConfiguration: lockConfig)
        privacyIconView.tintColor = .systemBlue
        privacyIconView.contentMode = .scaleAspectFit
        privacyIconView.translatesAutoresizingMaskIntoConstraints = false

        privacyTitleLabel.text = Strings.privacyTitle
        privacyTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        privacyTitleLabel.textColor = .label

        privacyTextLabel.text = Strings.privacyText
        privacyTextLabel.font = .systemFont(ofSize: 14, weight: .regular)
        privacyTextLabel.textColor = .secondaryLabel
        privacyTextLabel.numberOfLines = 0

        privacyContentStack.axis = .vertical
        privacyContentStack.spacing = 8
        privacyContentStack.translatesAutoresizingMaskIntoConstraints = false

        privacyTopStack.axis = .horizontal
        privacyTopStack.spacing = 12
        privacyTopStack.alignment = .center
        privacyTopStack.translatesAutoresizingMaskIntoConstraints = false

        privacyTopStack.addArrangedSubview(privacyIconView)
        privacyTopStack.addArrangedSubview(privacyTitleLabel)

        privacyContentStack.addArrangedSubview(privacyTopStack)
        privacyContentStack.addArrangedSubview(privacyTextLabel)

        privacyNoticeContainer.addSubview(privacyContentStack)

        storeSectionLabel.text = Strings.features
        storeSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        storeSectionLabel.textColor = .systemGray
        contentStack.addArrangedSubview(storeSectionLabel)

        contentStack.addArrangedSubview(remindersToggleContainer)

        languageContainer.backgroundColor = .cardBackground
        languageContainer.layer.cornerRadius = 14
        languageContainer.translatesAutoresizingMaskIntoConstraints = false

        let globeConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        languageIconView.image = UIImage(systemName: "globe", withConfiguration: globeConfig)
        languageIconView.tintColor = .systemBlue
        languageIconView.contentMode = .scaleAspectFit
        languageIconView.translatesAutoresizingMaskIntoConstraints = false

        languageTitleLabel.text = Strings.languageTitle
        languageTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        languageTitleLabel.textColor = .label

        languageSubtitleLabel.text = Strings.languageSubtitle
        languageSubtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        languageSubtitleLabel.textColor = .secondaryLabel
        languageSubtitleLabel.numberOfLines = 0

        var langConfig = UIButton.Configuration.filled()
        langConfig.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        langConfig.baseForegroundColor = .label
        langConfig.title = Strings.languageButton
        langConfig.image = UIImage(systemName: "gear")
        langConfig.imagePadding = 8
        langConfig.cornerStyle = .medium
        langConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        languageButton.configuration = langConfig
        languageButton.translatesAutoresizingMaskIntoConstraints = false
        languageButton.addTarget(self, action: #selector(openLanguageSettings), for: .touchUpInside)

        languageContentStack.axis = .vertical
        languageContentStack.spacing = 12
        languageContentStack.alignment = .fill
        languageContentStack.translatesAutoresizingMaskIntoConstraints = false

        languageTopStack.axis = .horizontal
        languageTopStack.spacing = 12
        languageTopStack.alignment = .center
        languageTopStack.translatesAutoresizingMaskIntoConstraints = false

        languageTopStack.addArrangedSubview(languageIconView)
        languageTopStack.addArrangedSubview(languageTitleLabel)
        languageTopStack.addArrangedSubview(UIView.flexibleSpacer())

        languageContentStack.addArrangedSubview(languageTopStack)
        languageContentStack.addArrangedSubview(languageSubtitleLabel)
        languageContentStack.addArrangedSubview(languageButton)

        languageContainer.addSubview(languageContentStack)
        contentStack.addArrangedSubview(languageContainer)

        storeInfoContainer.backgroundColor = .cardBackground
        storeInfoContainer.layer.cornerRadius = 14
        storeInfoContainer.layer.borderWidth = 0
        storeInfoContainer.layer.borderColor = UIColor.separator.cgColor
        storeInfoContainer.translatesAutoresizingMaskIntoConstraints = false

        let infoConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        storeIconView.image = UIImage(systemName: "archivebox.fill", withConfiguration: infoConfig)
        storeIconView.tintColor = ThemeManager.Colors.statusYellow
        storeIconView.contentMode = .scaleAspectFit
        storeIconView.translatesAutoresizingMaskIntoConstraints = false

        storeTitleLabel.text = Strings.storeTitle
        storeTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        storeTitleLabel.textColor = .label

        storeTextLabel.text = Strings.storeText
        storeTextLabel.font = .systemFont(ofSize: 14, weight: .regular)
        storeTextLabel.textColor = .secondaryLabel
        storeTextLabel.numberOfLines = 0

        storeContentStack.axis = .vertical
        storeContentStack.spacing = 8
        storeContentStack.translatesAutoresizingMaskIntoConstraints = false

        storeTopStack.axis = .horizontal
        storeTopStack.spacing = 12
        storeTopStack.alignment = .center
        storeTopStack.translatesAutoresizingMaskIntoConstraints = false

        storeTopStack.addArrangedSubview(storeIconView)
        storeTopStack.addArrangedSubview(storeTitleLabel)

        storeContentStack.addArrangedSubview(storeTopStack)
        storeContentStack.addArrangedSubview(storeTextLabel)

        storeInfoContainer.addSubview(storeContentStack)

        let storeTap = UITapGestureRecognizer(target: self, action: #selector(storeInfoTapped))
        storeInfoContainer.addGestureRecognizer(storeTap)
        storeInfoContainer.isUserInteractionEnabled = true

        contentStack.addArrangedSubview(storeInfoContainer)

        transparencySectionLabel.text = Strings.transparencySafety
        transparencySectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        transparencySectionLabel.textColor = .systemGray
        contentStack.addArrangedSubview(transparencySectionLabel)

        contentStack.addArrangedSubview(privacyNoticeContainer)

        transparencyContainer.backgroundColor = .cardBackground
        transparencyContainer.layer.cornerRadius = 14
        transparencyContainer.layer.borderWidth = 0
        transparencyContainer.layer.borderColor = UIColor.separator.cgColor
        transparencyContainer.translatesAutoresizingMaskIntoConstraints = false

        let shieldConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        transparencyIconView.image = UIImage(systemName: "checkmark.shield.fill", withConfiguration: shieldConfig)
        transparencyIconView.tintColor = .systemGreen
        transparencyIconView.contentMode = .scaleAspectFit
        transparencyIconView.translatesAutoresizingMaskIntoConstraints = false

        transparencyTitleLabel.text = Strings.transparencyTitle
        transparencyTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        transparencyTitleLabel.textColor = .label

        transparencyTextLabel.text = Strings.transparencyText
        transparencyTextLabel.font = .systemFont(ofSize: 14, weight: .regular)
        transparencyTextLabel.textColor = .secondaryLabel
        transparencyTextLabel.numberOfLines = 0

        var githubConfig = UIButton.Configuration.filled()
        githubConfig.baseBackgroundColor = .systemGreen.withAlphaComponent(0.15)
        githubConfig.baseForegroundColor = .label
        githubConfig.title = Strings.viewSourceCode
        githubConfig.imagePadding = 8
        githubConfig.cornerStyle = .medium
        githubConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        githubConfig.image = UIImage(named: "GitHub_Invertocat")?.resized(to: CGSize(width: 20, height: 20))
        githubButton.configuration = githubConfig
        githubButton.translatesAutoresizingMaskIntoConstraints = false
        githubButton.addTarget(self, action: #selector(openGitHub), for: .touchUpInside)

        transparencyContentStack.axis = .vertical
        transparencyContentStack.spacing = 12
        transparencyContentStack.translatesAutoresizingMaskIntoConstraints = false

        transparencyTopStack.axis = .horizontal
        transparencyTopStack.spacing = 12
        transparencyTopStack.alignment = .center
        transparencyTopStack.translatesAutoresizingMaskIntoConstraints = false

        transparencyTopStack.addArrangedSubview(transparencyIconView)
        transparencyTopStack.addArrangedSubview(transparencyTitleLabel)

        transparencyContentStack.addArrangedSubview(transparencyTopStack)
        transparencyContentStack.addArrangedSubview(transparencyTextLabel)
        transparencyContentStack.addArrangedSubview(githubButton)

        transparencyContainer.addSubview(transparencyContentStack)
        contentStack.addArrangedSubview(transparencyContainer)

        supportSectionLabel.text = Strings.support
        supportSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        supportSectionLabel.textColor = .systemGray
        contentStack.addArrangedSubview(supportSectionLabel)

        supportContainer.backgroundColor = .cardBackground
        supportContainer.layer.cornerRadius = 14
        supportContainer.translatesAutoresizingMaskIntoConstraints = false

        let heartConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        supportIconView.image = UIImage(systemName: "heart.fill", withConfiguration: heartConfig)
        supportIconView.tintColor = .systemPink
        supportIconView.contentMode = .scaleAspectFit
        supportIconView.translatesAutoresizingMaskIntoConstraints = false

        supportTitleLabel.text = Strings.supportTitle
        supportTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        supportTitleLabel.textColor = .label

        supportTextLabel.text = Strings.supportText
        supportTextLabel.font = .systemFont(ofSize: 14, weight: .regular)
        supportTextLabel.textColor = .secondaryLabel
        supportTextLabel.numberOfLines = 0

        var patreonConfig = UIButton.Configuration.filled()
        patreonConfig.baseBackgroundColor = .systemPink.withAlphaComponent(0.15)
        patreonConfig.baseForegroundColor = .label
        patreonConfig.title = Strings.supportButton
        patreonConfig.imagePadding = 8
        patreonConfig.cornerStyle = .medium
        patreonConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        patreonConfig.image = UIImage(named: "patreon_logo")?.resized(to: CGSize(width: 20, height: 20))
        patreonButton.configuration = patreonConfig
        patreonButton.translatesAutoresizingMaskIntoConstraints = false
        patreonButton.addTarget(self, action: #selector(openPatreon), for: .touchUpInside)

        supportContentStack.axis = .vertical
        supportContentStack.spacing = 12
        supportContentStack.translatesAutoresizingMaskIntoConstraints = false

        supportTopStack.axis = .horizontal
        supportTopStack.spacing = 12
        supportTopStack.alignment = .center
        supportTopStack.translatesAutoresizingMaskIntoConstraints = false

        supportTopStack.addArrangedSubview(supportIconView)
        supportTopStack.addArrangedSubview(supportTitleLabel)

        supportContentStack.addArrangedSubview(supportTopStack)
        supportContentStack.addArrangedSubview(supportTextLabel)
        supportContentStack.addArrangedSubview(patreonButton)

        supportContainer.addSubview(supportContentStack)
        contentStack.addArrangedSubview(supportContainer)

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

            languageContentStack.topAnchor.constraint(equalTo: languageContainer.topAnchor, constant: 16),
            languageContentStack.leadingAnchor.constraint(equalTo: languageContainer.leadingAnchor, constant: 16),
            languageContentStack.trailingAnchor.constraint(equalTo: languageContainer.trailingAnchor, constant: -16),
            languageContentStack.bottomAnchor.constraint(equalTo: languageContainer.bottomAnchor, constant: -16),
            
            privacyIconView.widthAnchor.constraint(equalToConstant: 24),
            privacyIconView.heightAnchor.constraint(equalToConstant: 24),

            privacyContentStack.topAnchor.constraint(equalTo: privacyNoticeContainer.topAnchor, constant: 16),
            privacyContentStack.leadingAnchor.constraint(equalTo: privacyNoticeContainer.leadingAnchor, constant: 18),
            privacyContentStack.trailingAnchor.constraint(
                equalTo: privacyNoticeContainer.trailingAnchor, constant: -18),
            privacyContentStack.bottomAnchor.constraint(equalTo: privacyNoticeContainer.bottomAnchor, constant: -16),

            storeIconView.widthAnchor.constraint(equalToConstant: 24),
            storeIconView.heightAnchor.constraint(equalToConstant: 24),

            storeContentStack.topAnchor.constraint(equalTo: storeInfoContainer.topAnchor, constant: 16),
            storeContentStack.leadingAnchor.constraint(equalTo: storeInfoContainer.leadingAnchor, constant: 18),
            storeContentStack.trailingAnchor.constraint(equalTo: storeInfoContainer.trailingAnchor, constant: -18),
            storeContentStack.bottomAnchor.constraint(equalTo: storeInfoContainer.bottomAnchor, constant: -16),

            transparencyIconView.widthAnchor.constraint(equalToConstant: 24),
            transparencyIconView.heightAnchor.constraint(equalToConstant: 24),

            transparencyContentStack.topAnchor.constraint(equalTo: transparencyContainer.topAnchor, constant: 16),
            transparencyContentStack.leadingAnchor.constraint(
                equalTo: transparencyContainer.leadingAnchor, constant: 18),
            transparencyContentStack.trailingAnchor.constraint(
                equalTo: transparencyContainer.trailingAnchor, constant: -18),
            transparencyContentStack.bottomAnchor.constraint(
                equalTo: transparencyContainer.bottomAnchor, constant: -16),

            supportIconView.widthAnchor.constraint(equalToConstant: 24),
            supportIconView.heightAnchor.constraint(equalToConstant: 24),

            supportContentStack.topAnchor.constraint(equalTo: supportContainer.topAnchor, constant: 16),
            supportContentStack.leadingAnchor.constraint(equalTo: supportContainer.leadingAnchor, constant: 18),
            supportContentStack.trailingAnchor.constraint(equalTo: supportContainer.trailingAnchor, constant: -18),
            supportContentStack.bottomAnchor.constraint(equalTo: supportContainer.bottomAnchor, constant: -16)
        ])
    }

    @objc private func openLanguageSettings() {
        HapticFeedbackManager.shared.impact(intensity: .light)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    @objc private func openPatreon() {
        if let url = URL(string: "https://www.patreon.com/cw/zeynepmuslim") {
            UIApplication.shared.open(url)
            HapticFeedbackManager.shared.impact(intensity: .light)
        }
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/zeynepmuslim/secure-photo-cleaner-app") {
            UIApplication.shared.open(url)

            HapticFeedbackManager.shared.impact(intensity: .light)
        }
    }

    @objc private func storeInfoTapped() {
        HapticFeedbackManager.shared.impact(intensity: .light)
        let tutorial = StoreTutorialSheetViewController()
        present(tutorial, animated: true)
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
        githubButton.configuration?.image = UIImage(named: "GitHub_Invertocat")?.resized(to: CGSize(width: 20, height: 20))
        patreonButton.configuration?.image = UIImage(named: "patreon_logo")?.resized(to: CGSize(width: 20, height: 20))
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
