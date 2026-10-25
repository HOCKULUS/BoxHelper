import SwiftUI

/// Der Text wechselt von der Zeile über dem Picker in die neue Standortkarte.
struct CreateLocationDictationFeedback: View {
    @ObservedObject var dictation: AutomaticLocationDictation

    var body: some View {
        CreateAutomaticDictationFeedback(transcript: dictation.standaloneTranscript,
                                         audioLevel: dictation.speech.audioLevel, skip: dictation.skip,
                                         question: "CreateCamera.LocationNameQuestion",
                                         isListening: dictation.speech.isListening) { width, _ in
            CreateDictatedLocationList(dictation: dictation, width: width)
        }
    }
}
