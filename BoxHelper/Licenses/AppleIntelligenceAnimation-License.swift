import SwiftUI

/// Derselbe Navigationseintrag wie die übrigen eingebundenen Bibliotheken.
struct AppleIntelligenceAnimationLicenseView: View {
    private let license = """
    MIT License
    
    Copyright (c) 2026 TopScrech
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    """
    var body: some View {
        List {
            Section {
                Text("AppleIntelligenceAnimation.Attribution")
                Link("AppleIntelligenceAnimation.Source", destination: URL(string: "https://github.com/TopScrech/Apple-Intelligence-Animation")!)
                Link("AppleIntelligenceAnimation.License", destination: URL(string: "https://github.com/TopScrech/Apple-Intelligence-Animation/blob/main/LICENSE")!)
            }
            Section("MIT License") { Text(license).font(.footnote).textSelection(.enabled) }
        }
        .navigationTitle("AppleIntelligenceAnimation.Title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
