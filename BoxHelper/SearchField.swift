//
//  SearchField.swift
//  BoxHelper
//
//  Created by HOCKULUS on 20.06.25.
//

import SwiftUI

struct SearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    var placeholder: LocalizedStringKey = "Suchen"
    var onCommit: (() -> Void)? = nil

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text, onCommit: {
                onCommit?()
            })
            .focused($isFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)

            if text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(height: 10)
                }
            }
        }
        .padding(5)
        .background(
            Group {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .glassEffect()
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        //.fill(Color(.systemGray5))
                }
            }
        )
        //.animation(.easeInOut(duration: 0.2), value: text)
        //.padding(.horizontal)
    }
}
