import SwiftUI

struct License2: Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

struct LicenseListViewZoom: View {
    let License = (title: "Zoomable Scroll View", content: """
        MIT License

        Copyright (c) 2021 Jacob Bandes-Storch

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
        """)
    var code = """
       //Modified version of the code that includes double-tap to zoom functionality
       struct ZoomableScrollView<Content: View>: UIViewRepresentable {
           private var content: Content

           init(@ViewBuilder content: () -> Content) {
               self.content = content()
           }

           func makeUIView(context: Context) -> UIScrollView {
               let scrollView = UIScrollView()
               scrollView.delegate = context.coordinator
               scrollView.maximumZoomScale = 10
               scrollView.minimumZoomScale = 1
               scrollView.bouncesZoom = true
               scrollView.showsHorizontalScrollIndicator = false
               scrollView.showsVerticalScrollIndicator = false
               scrollView.backgroundColor = .clear

               // UIHostingController for SwiftUI content
               let hostedView = context.coordinator.hostingController.view!
               hostedView.translatesAutoresizingMaskIntoConstraints = true
               hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
               hostedView.frame = scrollView.bounds
               hostedView.backgroundColor = .clear
               scrollView.addSubview(hostedView)

               // Add double-tap gesture recognizer
               let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleDoubleTap))
               doubleTapGesture.numberOfTapsRequired = 2
               scrollView.addGestureRecognizer(doubleTapGesture)

               return scrollView
           }

           func makeCoordinator() -> Coordinator {
               return Coordinator(hostingController: UIHostingController(rootView: self.content))
           }

           func updateUIView(_ uiView: UIScrollView, context: Context) {
               context.coordinator.hostingController.rootView = self.content
               assert(context.coordinator.hostingController.view.superview == uiView)
           }

           // MARK: - Coordinator

           class Coordinator: NSObject, UIScrollViewDelegate {
               var hostingController: UIHostingController<Content>

               init(hostingController: UIHostingController<Content>) {
                   self.hostingController = hostingController
               }

               func viewForZooming(in scrollView: UIScrollView) -> UIView? {
                   return hostingController.view
               }

               // Handle double-tap to reset zoom
               @objc func handleDoubleTap(_ sender: UITapGestureRecognizer) {
                   if let scrollView = sender.view as? UIScrollView {
                       if scrollView.zoomScale == 1.0 {
                           scrollView.setZoomScale(6.0, animated: true)
                       }
                       else {
                           scrollView.setZoomScale(1.0, animated: true)
                       }
                   }
               }
           }
       }
       """
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    var body: some View {
        NavigationView {
                ScrollView {
                    Link("GitHub", destination: URL(string: "https://github.com/jtbandes/SpacePOD/blob/main/SpacePOD/ZoomableScrollView.swift")!)
                        .foregroundColor(selectedColor)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    Text(License.content)
                        .padding()
                    ScrollView {
                        TextEditor(text: .constant(code))
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .padding()
                            .frame(maxHeight: 200) // Limit the height of the TextField
                    }
                    .frame(maxHeight: 300)
                    Spacer()
                }
                .navigationTitle(License.title)
        }
        .padding(.top, -20)
    }
}
