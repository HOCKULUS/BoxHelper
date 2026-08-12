import SwiftUI

struct License: Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

struct LicenseListViewZip: View {
    let License = (title: "Swift ZIP Framework", content: """
        The MIT License (MIT)

        Copyright (c) 2015 Roy Marmelstein

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.
        """)
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    var body: some View {
        NavigationView {
                ScrollView {
                    Text(License.content)
                        .padding()
                    Link("GitHub", destination: URL(string: "https://github.com/marmelroy/Zip")!)
                        .foregroundColor(selectedColor)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    Spacer()
                }
                .navigationTitle("Swift ZIP Framework")
        }
        .padding(.top, -20)
    }
}
