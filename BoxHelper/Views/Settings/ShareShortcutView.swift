//
//  ShareShortcutView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 06.07.25.
//

import SwiftUI

/*struct ShareShortcutView: View {
    @State private var showShareSheet = false
    @State private var fileToShare: URL?

    var body: some View {
        VStack(spacing: 20) {
            Button {
                if let fileURL = Bundle.main.url(forResource: "FindMyTools", withExtension: "shortcut") {
                    fileToShare = fileURL
                    showShareSheet = true
                }
            } label: {
                Text("Teile Shortcut-Datei")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let fileToShare = fileToShare {
                ShareSheet(activityItems: [fileToShare])
            }
        }
    }
}*/

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
