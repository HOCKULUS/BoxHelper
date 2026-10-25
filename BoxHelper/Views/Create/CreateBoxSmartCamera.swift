import SwiftUI

/// Die Fotozeile besitzt keinen eigenen Kameralebenszyklus; Scrollen stoppt keine Bildserie.
struct CreateBoxSmartCamera: View {
    @ObservedObject var automation: BoxCameraAutomation
    let images: [UIImage]
    let feedEnabled: Bool
    let openGallery: () -> Void
    let openCamera: () -> Void
    let toggleFeed: () -> Void
    let removeImage: (Int) -> Void

    var body: some View {
        VStack {
            CreateItemPhotoPanel(camera: automation.camera, isFeedEnabled: feedEnabled,
                                 isAutomaticActive: automation.sessionID != nil && automation.referenceFeedback == .hidden,
                                 isAutomaticRunning: automation.sessionID != nil,
                                 referenceFeedback: automation.referenceFeedback,
                                 toggleDiagnostics: { automation.diagnosticsVisible.toggle() }, images: images,
                                 openGallery: openGallery, openCamera: openCamera, toggleFeed: toggleFeed,
                                 rotateFeed: {
                                     automation.stopMonitoring()
                                     automation.camera.rotatePreviewClockwise()
                                 }, removeImage: removeImage)
            if let message = automation.camera.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Gleiche feste Auslöser und Diktat-Hilfstaste wie bei der Gegenstandserfassung.
struct CreateBoxCameraControls: View {
    @ObservedObject var automation: BoxCameraAutomation
    @AppStorage(FeedSensitivityLevel.storageKey) private var sensitivityValue = 0
    @AppStorage(BoxAutomaticCapturePolicy.voiceNamingKey) private var voiceNaming = true
    @AppStorage(BoxAutomaticCapturePolicy.locationNamingKey) private var locationNaming = true
    let isBusy: Bool

    var body: some View {
        CreateCameraControls(isAutomaticSelected: automation.automaticSelected,
                             isAutomaticActive: automation.sessionID != nil,
                             sensitivity: automation.sensitivity, isDictationSelected: !automation.dictationMuted,
                             dynamicFactor: automation.camera.dynamicChangeFactor,
                             changeSensitivity: { sensitivityValue = automation.sensitivity.next.rawValue },
                             toggleDictation: { automation.dictationMuted.toggle() }, isReady: automation.camera.isReady,
                             isBusy: isBusy || automation.camera.isCapturing || automation.isCompleting,
                             takePhoto: automation.takePhoto, toggleAutomatic: automation.toggleMonitoring,
                             showsDictation: voiceNaming || locationNaming)
    }
}

/// Countdown, Aufnahme-Emoji und Diktat teilen die mittige Darstellung der Items.
struct CreateBoxCameraFeedback: View {
    @ObservedObject var automation: BoxCameraAutomation
    let isSaved: Bool

    var body: some View {
        Group {
            if automation.noticeID != nil {
                CreateAutomaticThresholdNotice(symbol: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90",
                                               message: "FeedMonitoring.HoldStill", isWarning: true)
                    .padding(.horizontal, 16)
            } else if let emoji = automation.abortEmoji {
                CreateAutomaticCaptureAbortFeedback(emoji: emoji)
            } else if let number = automation.countdown {
                CreateCameraCountdown(number: number)
            } else if automation.locationDictation.showsFeedback {
                CreateLocationDictationFeedback(dictation: automation.locationDictation)
            } else if automation.dictation.isListening {
                CreateAutomaticDictationFeedback(transcript: automation.dictation.transcript,
                                                 audioLevel: automation.dictation.audioLevel,
                                                 skip: automation.dictation.skip,
                                                 question: "CreateCamera.BoxNameQuestion")
            } else if let emoji = automation.emoji {
                CreateAutomaticCaptureFeedback(emoji: emoji, isSaved: isSaved && automation.isSaving)
            } else if isSaved {
                CreateSavedConfirmation()
            }
        }
        .task(id: automation.abortRevision) {
            guard automation.abortEmoji != nil else { return }
            do { try await Task.sleep(for: .milliseconds(1500)) }
            catch { return }
            automation.clearAbortFeedback()
        }
        .task(id: automation.noticeID) {
            guard automation.noticeID != nil else { return }
            do { try await Task.sleep(for: .seconds(3)) }
            catch { return }
            automation.clearNotice()
        }
    }
}
