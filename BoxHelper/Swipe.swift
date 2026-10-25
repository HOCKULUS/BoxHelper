//
//  Swipe.swift
//  BoxHelper
//
//  Created by HOCKULUS on 06.04.25.
//

import SwiftUI

struct SwipeGestureView: UIViewRepresentable {
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        // Swipe nach links
        let swipeLeft = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        
        // Swipe nach rechts
        let swipeRight = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight)
    }
    
    class Coordinator: NSObject {
        var onSwipeLeft: () -> Void
        var onSwipeRight: () -> Void
        
        init(onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) {
            self.onSwipeLeft = onSwipeLeft
            self.onSwipeRight = onSwipeRight
        }
        
        // @MainActor stellt sicher, dass die Methode auf dem Hauptthread ausgeführt wird
        @MainActor @objc func handleSwipe(_ gestureRecognizer: UISwipeGestureRecognizer) {
            if gestureRecognizer.direction == .left {
                onSwipeLeft()
            } else if gestureRecognizer.direction == .right {
                onSwipeRight()
            }
        }
    }
}
