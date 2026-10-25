//
//  ItemRow.swift
//  BoxHelper
//
//  Created by HOCKULUS on 28.12.24.
//
import SwiftUI

struct ItemRow: View {
    let item: Items
    let selectedColor: Color
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(item.name)
            Spacer()
            Menu {
                Button(role: .destructive, action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Settings.delete")
                            .foregroundColor(.red)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(selectedColor)
                    .scaleEffect(1.2)
            }
        }
    }
}
