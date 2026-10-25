//
//  ActionView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 07.06.25.
//
/*
import SwiftUI


struct ActionSheetView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Image("Background2")       // Vollflächiges Hintergrundbild
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            HStack{}
                .scaledToFill()
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
            VStack(spacing: 20) {
                HStack(alignment: .center) {
                    Spacer()
                    Image("BH")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 110)
                    Text("X")
                        .font(.title)
                        .foregroundStyle(Color.white)
                    HStack {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 40)
                        Text("BoxHelper")
                            .font(.callout.bold())
                            .foregroundStyle(Color.white)
                    }
                    Spacer()
                }
                .padding(-20)
                //.background(.ultraThinMaterial.quinary)
                .cornerRadius(12)
                //.frame(maxWidth: .infinity)
                Spacer()
                ScrollView(.vertical) {
                    HStack {
                        Image("Image")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                        VStack(alignment: .leading) {
                            Text("-12% auf ausgewählte Umzugsartikel")
                                .font(.headline)
                            HStack {
                                Text("TCZV-ZTFGU-UGZUZ")
                                    .background(Color.black)
                                    .padding(4)
                                    .cornerRadius(5)
                                    .font(.subheadline.monospacedDigit())
                                Image(systemName: "document.on.document")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12)
                            }
                            .padding(.vertical,-9)
                        }
                        .padding(5)
                        Spacer()
                    }
                    .cornerRadius(12)
                    .background(.ultraThinMaterial.quinary)
                    .frame(height: 50)
                    HStack {
                        Image("Image1")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                        VStack(alignment: .leading) {
                            Text("Umzugskarton 30er Set")
                                .font(.headline)
                            Text("50€")
                                .font(.subheadline.monospacedDigit())
                        }
                        .padding(5)
                        Spacer()
                        Image(systemName: "arrow.up.forward.app.fill")
                            .padding(5)
                    }
                    .cornerRadius(12)
                    .background(.ultraThinMaterial.quinary)
                    .frame(height: 50)
                    HStack {
                        Image("Image2")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                        VStack(alignment: .leading) {
                            Text("Stapelkarre")
                                .font(.headline)
                            Text("60€")
                                .font(.subheadline.monospacedDigit())
                        }
                        .padding(5)
                        Spacer()
                        Image(systemName: "arrow.up.forward.app.fill")
                            .padding(5)
                    }
                    .cornerRadius(12)
                    .background(.ultraThinMaterial.quinary)
                    .frame(height: 50)
                    HStack {
                        Image("Image3")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                        VStack(alignment: .leading) {
                            Text("Eurobehälter 60x40x32 10er Set")
                                .font(.headline)
                            Text("100€")
                                .font(.subheadline.monospacedDigit())
                        }
                        .padding(5)
                        Spacer()
                        Image(systemName: "arrow.up.forward.app.fill")
                            .padding(5)
                    }
                    .cornerRadius(12)
                    .background(.ultraThinMaterial.quinary)
                    .frame(height: 50)
                }
                .padding(15)
                Spacer()
                Button("Mehr über Bauhaus X BoxHelper") {
                    
                }
                .padding(5)
                .background(.ultraThinMaterial.quinary)
                .cornerRadius(12)
            }
            .padding()
            .presentationDetents([.medium])
        }
    }
}
*/
