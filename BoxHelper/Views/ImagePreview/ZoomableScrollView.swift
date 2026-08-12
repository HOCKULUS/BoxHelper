//
//  ZoomableScrollView.swift
//  BoxHelper
//
//  Created by admin on 13.02.26.
//

import SwiftUI


struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    @Binding var zoomScale: CGFloat
    private var content: Content

    init(zoomScale: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
        self._zoomScale = zoomScale
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
        return Coordinator(
            hostingController: UIHostingController(rootView: self.content),
            zoomScale: $zoomScale
        )
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = self.content
        assert(context.coordinator.hostingController.view.superview == uiView)
        if zoomScale == 1.0 && uiView.zoomScale != 1.0 {
            uiView.setZoomScale(1.0, animated: false)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>
        @Binding var zoomScale: CGFloat

        init(hostingController: UIHostingController<Content>, zoomScale: Binding<CGFloat>) {
            self.hostingController = hostingController
            self._zoomScale = zoomScale
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }

        // Handle double-tap to reset zoom
        @objc func handleDoubleTap(_ sender: UITapGestureRecognizer) {
            if let scrollView = sender.view as? UIScrollView {
                if scrollView.zoomScale == 1.0 {
                    scrollView.setZoomScale(4.0, animated: true)
                }
                else {
                    scrollView.setZoomScale(1.0, animated: true)
                }
            }
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            zoomScale = scrollView.zoomScale
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            zoomScale = scale
        }
    }
}
