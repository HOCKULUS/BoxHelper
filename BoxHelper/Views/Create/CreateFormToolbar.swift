import SwiftUI

/// Keep the supplementary navigation actions identical across all three forms.
struct CreateFeedbackButton: View {
    @State private var showFeedback = false

    var body: some View {
        Button { showFeedback = true } label: { Image(systemName: "flag") }
            .accessibilityLabel("Open feedback form")
            .sheet(isPresented: $showFeedback) { FeedbackReportSheet() }
    }
}

