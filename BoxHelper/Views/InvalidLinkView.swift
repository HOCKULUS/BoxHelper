//
//  Error.swift
//  BoxHelper
//
//  Created by HOCKULUS on 24.04.25.
//

import SwiftUI

struct InvalidLinkView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.orange)
                .padding()

            Text("Link Error")
                .font(.title)
                .fontWeight(.bold)

            Text("There was a problem processing the link you opened. Please check if the link is correct and try again.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button(action: {
                // Action, z. B. zurück zur Startseite
            }) {
                Text("Try Again")
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}
