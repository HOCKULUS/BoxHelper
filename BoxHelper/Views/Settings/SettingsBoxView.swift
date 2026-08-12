//
//  SettingsBoxView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 30.01.25.
//


import SwiftUI

struct SettingsBoxView: View {
    var iconBackgroundColor: Color = .newRed
    var scrollToQRCodeSection: Bool = false
    @Environment(\.colorScheme) var colorScheme  // Zugriff auf Dark/Light Mode
    @EnvironmentObject var accentColorManager: AccentColorManager
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State var sliderValue4: Int = UserDefaults.standard.integer(forKey: "sliderValue4") == 0 ? 100 : UserDefaults.standard.integer(forKey: "sliderValue4")
    @State private var showDetails: Bool = UserDefaults.standard.object(forKey: "showDetails") == nil ? true : UserDefaults.standard.bool(forKey: "showDetails")
    @State private var showDetailsDate1: Bool = UserDefaults.standard.object(forKey: "showDetailsDate1") == nil ? false : UserDefaults.standard.bool(forKey: "showDetailsDate1")
    @State private var showDetailsDate2: Bool = UserDefaults.standard.object(forKey: "showDetailsDate2") == nil ? false : UserDefaults.standard.bool(forKey: "showDetailsDate2")
    @State private var showDetailsItems: Bool = UserDefaults.standard.object(forKey: "showDetailsItems") == nil ? false : UserDefaults.standard.bool(forKey: "showDetailsItems")
    @State private var showDetailsItemsCounter: Bool = UserDefaults.standard.object(forKey: "showDetailsItemsCounter") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsItemsCounter")
    @State private var showDetailsTagCounter: Bool = UserDefaults.standard.object(forKey: "showDetailsTagCounter") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsTagCounter")
    @State private var showDetailsImagesCounter: Bool = UserDefaults.standard.object(forKey: "showDetailsImagesCounter") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsImagesCounter")
    @State private var showDetailsLocation: Bool = UserDefaults.standard.object(forKey: "showDetailsLocation") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsLocation")
    @State private var showQRCodeLogo: Bool = UserDefaults.standard.object(forKey: "showQRCodeLogo") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLogo")
    @State private var showQRCodeLocation: Bool = UserDefaults.standard.object(forKey: "showQRCodeLocation") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLocation")
    @State private var showQRCodeLocationColor: Bool = UserDefaults.standard.object(forKey: "showQRCodeLocationColor") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLocationColor")
    @State private var tinyQRCode: Bool = UserDefaults.standard.bool(forKey: "tinyQRCode")
    @State private var horizontalQRCodeLayout: Bool = UserDefaults.standard.bool(forKey: "horizontalQRCodeLayout")
    @State private var showQRCodeName: Bool = UserDefaults.standard.object(forKey: "showQRCodeName") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeName")
    @State private var dynamicQRCode: Bool = UserDefaults.standard.object(forKey: "dynamicQRCode") == nil ? true : UserDefaults.standard.bool(forKey: "dynamicQRCode")
    @State private var previewUUID = UUID()
    @State private var qrCodeImage: UIImage? = nil
    @State private var qrCodeCopies: Int = UserDefaultsManager.shared.getQRCodeCopies()
    @State private var qrCodeNumber: Int = UserDefaultsManager.shared.getQRCodeNumber()
    @State private var blockedTags: [String] = UserDefaults.standard.array(forKey: "blockedTags") as? [String] ?? []
    @State private var boxNameScheme = NSLocalizedString(UserDefaults.standard.string(forKey: "boxNameScheme") ?? "CreateView.Box", comment: "")
    @State private var showBoxNameSheme = UserDefaultsManager.shared.loadShowBoxNameSheme()
    @State private var useBoxUUIDasBoxName = UserDefaultsManager.shared.loadUseBoxUUIDasBoxName()
    @State private var showBoxNumberSheme = UserDefaultsManager.shared.loadShowBoxNumberSheme()
    ///TAGS DEAKTIVIERT!!!!
    @State private var showTags: Bool = UserDefaults.standard.object(forKey: "showTags") == nil ? true : UserDefaults.standard.bool(forKey: "showTags")
    @State private var hideTags: Bool = UserDefaults.standard.object(forKey: "hideTags") == nil ? true : UserDefaults.standard.bool(forKey: "hideTags")
    @State private var smartZoom: Bool = UserDefaults.standard.object(forKey: "smartZoom") == nil ? true : UserDefaults.standard.bool(forKey: "smartZoom")
    @State private var showUserDefaultsAlert2 = false
    @State private var showUserDefaultsAlert3 = false
    @State private var showUserDefaultsAlert4 = false
    @State private var showUserDefaultsAlert5 = false
    @State private var didAutoScrollToQRCodeSection = false
    @State private var lastBoxID: Int = max(0, UserDefaults.standard.integer(forKey: "lastBoxID"))
    @State private var lastBoxIDInput: String = ""
    @State private var selectedImageOrderOption: String = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
    
    private let qrSectionAnchorID = "settings_box_qr_section_anchor"

    var body: some View {
        ScrollViewReader { proxy in
        Form{
            Section {
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous) // Abgerundete Ecken statt Kreis
                                .fill(iconBackgroundColor)
                                .frame(width: 70, height: 70) // Beibehaltung der Box-Größe
                            
                            Image(systemName: "shippingbox.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50) // Größeres Icon für bessere Sichtbarkeit
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Text("TabView.Label.Boxes")
                            .font(.system(size: 25, weight: .bold))
                        Spacer()
                    }
                    HStack {
                        Text("Choose a naming scheme, adjust image resolution or modify their detals in the list.")
                            .font(.subheadline) // Einheitliche Schriftgröße
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.bottom, 10)
                }
            }
            Section(header: Text(String(format: NSLocalizedString("Boxnamingscheme", comment: ""))), footer: Text(String(format: NSLocalizedString("Define how your boxes should be named automatically. Choose between a unique ID or a combination of sequential numbers and custom text.", comment: "")))) {
                if !useBoxUUIDasBoxName {
                    // Option: Enable Text for Box Name
                    HStack {
                        Text("Enable Naming")
                        Spacer()
                        Toggle("", isOn: $showBoxNameSheme)
                            .onChange(of: showBoxNameSheme) { _, newValue in
                                UserDefaultsManager.shared.saveShowBoxNameSheme(newValue)
                                introduceBoxNaming().invalidate(reason: .actionPerformed)
                            }
                            .tint(accentColorManager.accentColor)
                    }
                    .listRowSeparator(showBoxNameSheme ? Visibility.hidden : Visibility.visible)
                }
                // TextField for Box Name, shown only if Naming is enabled
                if showBoxNameSheme {
                    if !useBoxUUIDasBoxName {
                        HStack {
                            TextField("CreateView.Box", text: $boxNameScheme)
                                .onChange(of: boxNameScheme) { _, newValue in
                                    introduceBoxNaming().invalidate(reason: .actionPerformed)
                                    let validInput = newValue.prefix(20) // Limit to 20 characters
                                    boxNameScheme = String(validInput)
                                    UserDefaults.standard.set(validInput, forKey: "boxNameScheme")
                                }
                                .frame(maxWidth: .infinity)
                            if boxNameScheme != "" {
                                Button(action: {
                                    boxNameScheme = ""
                                    introduceBoxNaming().invalidate(reason: .actionPerformed)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if !useBoxUUIDasBoxName {
                    // Option: Enable Numbering for Box Name
                    HStack {
                        Text("Enable Numbering")
                        Spacer()
                        Toggle("", isOn: $showBoxNumberSheme)
                            .onChange(of: showBoxNumberSheme) { _, newValue in
                                UserDefaultsManager.shared.saveShowBoxNumberSheme(newValue)
                                lastBoxID = max(0, UserDefaults.standard.integer(forKey: "lastBoxID"))
                                lastBoxIDInput = String(lastBoxID)
                                introduceBoxNaming().invalidate(reason: .actionPerformed)
                            }
                            .tint(accentColorManager.accentColor)
                    }
                    .listRowSeparator(Visibility.visible)
                }
                if !useBoxUUIDasBoxName && showBoxNumberSheme {
                    HStack(spacing: 10) {
                        TextField("Set last number", text: $lastBoxIDInput)
                            .keyboardType(.numberPad)
                            .onChange(of: lastBoxIDInput) { _, newValue in
                                let filtered = newValue.filter(\.isNumber)
                                if filtered != newValue {
                                    lastBoxIDInput = filtered
                                    return
                                }
                                guard !filtered.isEmpty else { return }
                                let sanitizedValue = max(0, Int(filtered) ?? 0)
                                lastBoxID = sanitizedValue
                                UserDefaults.standard.set(sanitizedValue, forKey: "lastBoxID")
                                introduceBoxNaming().invalidate(reason: .actionPerformed)
                            }
                        Button {
                            resetLastBoxID()
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .font(.title3)
                    }
                }
                HStack {
                    Text("Use Box ID as Name")
                    Spacer()
                    Toggle("", isOn: $useBoxUUIDasBoxName)
                        .onChange(of: useBoxUUIDasBoxName) { _, newValue in
                            UserDefaultsManager.shared.saveUseBoxUUIDasBoxName(newValue)
                            introduceBoxNaming().invalidate(reason: .actionPerformed)
                        }
                        .tint(accentColorManager.accentColor)
                }
                // Display concatenated name if Naming or Numbering is enabled
                if showBoxNameSheme || showBoxNumberSheme || useBoxUUIDasBoxName {
                    HStack {
                        HStack {
                            if useBoxUUIDasBoxName {
                                Text("#\((UUID().description).prefix(6))")
                                    .foregroundStyle(Color.secondary)
                            }
                            else{
                                Text("\(showBoxNameSheme ? (boxNameScheme.isEmpty ? NSLocalizedString("CreateView.Box", comment: "") + " " : boxNameScheme) : "")"+"\(showBoxNumberSheme ? "\(lastBoxID + 1)" : "")")
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
            }
            .onAppear {
                // Lade Werte aus UserDefaults
                qrCodeImage = generateQRCodeForBoxPreview(
                    previewUUID,
                    text: NSLocalizedString("CreateView.Box", comment: ""),
                    standort: NSLocalizedString("Location", comment: ""),
                    dynamicQRCode: dynamicQRCode,
                    showQRCodeLogo: showQRCodeLogo,
                    showQRCodeLocation: showQRCodeLocation,
                    showQRCodeName: showQRCodeName,
                    showQRCodeLocationColor: showQRCodeLocationColor,
                    showTinyQRCode: tinyQRCode,
                    horizontalQRCodeLayout: horizontalQRCodeLayout,
                    standortColor: UIColor.systemBlue
                )
                showDetails = UserDefaults.standard.object(forKey: "showDetails") == nil ? true : UserDefaults.standard.bool(forKey: "showDetails")
                showDetailsDate1 = UserDefaults.standard.object(forKey: "showDetailsDate1") == nil ? false : UserDefaults.standard.bool(forKey: "showDetailsDate1")
                showDetailsDate2 = UserDefaults.standard.object(forKey: "showDetailsDate2") == nil ? false : UserDefaults.standard.bool(forKey: "showDetailsDate2")
                showDetailsItems = UserDefaults.standard.object(forKey: "showDetailsItems") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsItems")
                showDetailsItemsCounter = UserDefaults.standard.object(forKey: "showDetailsItemsCounter") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsItemsCounter")
                showDetailsTagCounter = UserDefaults.standard.object(forKey: "showDetailsTagCounter") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsTagCounter")
                showDetailsImagesCounter = UserDefaults.standard.object(forKey: "showDetailsImagesCounter") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsImagesCounter")
                showDetailsLocation = UserDefaults.standard.object(forKey: "showDetailsLocation") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsLocation")
                showBoxNameSheme = UserDefaultsManager.shared.loadShowBoxNameSheme()
                showBoxNumberSheme = UserDefaultsManager.shared.loadShowBoxNumberSheme()
                lastBoxID = max(0, UserDefaults.standard.integer(forKey: "lastBoxID"))
                lastBoxIDInput = String(lastBoxID)
                boxNameScheme = UserDefaults.standard.string(forKey: "boxNameScheme") ?? ""
                showBoxNameSheme = UserDefaultsManager.shared.loadShowBoxNameSheme()
                useBoxUUIDasBoxName = UserDefaultsManager.shared.loadUseBoxUUIDasBoxName()
                showQRCodeLogo = UserDefaults.standard.object(forKey: "showQRCodeLogo") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLogo")
                showQRCodeLocation = UserDefaults.standard.object(forKey: "showQRCodeLocation") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLocation")
                showQRCodeLocationColor = UserDefaults.standard.object(forKey: "showQRCodeLocationColor") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLocationColor")
                if !showQRCodeLocation && showQRCodeLocationColor {
                    showQRCodeLocationColor = false
                    UserDefaultsManager.shared.saveShowQRCodeLocationColor(false)
                }
                tinyQRCode = UserDefaults.standard.bool(forKey: "tinyQRCode")
                horizontalQRCodeLayout = UserDefaults.standard.bool(forKey: "horizontalQRCodeLayout")
                showQRCodeName = UserDefaults.standard.object(forKey: "showQRCodeName") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeName")
                dynamicQRCode = UserDefaults.standard.object(forKey: "dynamicQRCode") == nil ? true : UserDefaults.standard.bool(forKey: "dynamicQRCode")
            }
            Section(header: Text("Image order"), footer: Text("Selecting ‘new → old’ will use the most recent image as the preview for the box")) {
                // Picker für Auflösung und Kompression
                Picker("Image order", selection: $selectedImageOrderOption) {
                    Text("new → old").tag("new")
                    Text("old → new").tag("old")
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedImageOrderOption, initial: false ) { oldValue, newValue in
                    switch newValue {
                        case "new":
                            UserDefaults.standard.set("new", forKey: "imageSortingOption")
                            selectedImageOrderOption = "new"
                        case "old":
                            UserDefaults.standard.set("old", forKey: "imageSortingOption")
                            selectedImageOrderOption = "old"
                    default:
                        UserDefaults.standard.set("new", forKey: "imageSortingOption")
                        selectedImageOrderOption = "new"
                    }
                }
                .onAppear {
                    selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
                }
            }
            ///TAGS DEAKTIVIERT
            Section(header: Text("Tags")) {
                VStack {
                    HStack {
                        Text("Enable Tags")
                        Spacer()
                        Toggle("", isOn: $showTags)
                            .onChange(of: showTags, initial: true) { oldValue, newValue in
                                UserDefaultsManager.shared.saveShowTags(newValue)
                                //updateUserDefaultsSize() // Größe aktualisieren
                            }
                            .tint(accentColorManager.accentColor)
                    }
                }
                if showTags {
                    VStack {
                        HStack {
                            Text("Hide Tags")
                            Spacer()
                            Toggle("", isOn: $hideTags)
                                .onChange(of: hideTags, initial: true) { oldValue, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "hideTags")
                                    //updateUserDefaultsSize() // Größe aktualisieren
                                }
                                .tint(accentColorManager.accentColor)
                        }
                    }
                    HStack {
                        //.padding(.leading, 15)
                        // Slider zur Auswahl eines Wertes
                        Picker(String(format: NSLocalizedString("Limit per Image", comment: "")), selection: $sliderValue4) {
                                Text("1").tag(1)
                                Text("5").tag(5)
                                Text("10").tag(10)
                                Text("25").tag(25)
                                Text("50").tag(50)
                                Text("100").tag(100)
                                Text("200").tag(200)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: sliderValue4, initial: false) { oldValue, newValue in
                            sliderValue4 = newValue
                            UserDefaultsManager.shared.saveSliderValue4(sliderValue4)
                        }
                        .onAppear {
                            sliderValue4 = UserDefaultsManager.shared.loadSliderValue4()
                        }
                        .accentColor(selectedColor)
                    }
                    VStack {
                        VStack {
                            HStack {
                                Text("Blocked Tags:")
                                Spacer()
                                Text("\(blockedTags.count)")
                            }
                            .onAppear(){
                                print ("blockedTags Settings: \(blockedTags)")
                                blockedTags = UserDefaults.standard.array(forKey: "blockedTags") as? [String] ?? []
                            }
                            HStack {
                                if !blockedTags.isEmpty {
                                    HStack {
                                        Image(systemName: "trash")
                                        //.frame(width: 20, height: 20)
                                            .foregroundStyle(.white)
                                            .scaleEffect(1.5)
                                    }
                                    .frame(width: 26, height: 26)
                                    .background(.red)
                                    .cornerRadius(5)
                                    .font(.footnote)
                                    .foregroundStyle(.white)
                                    .padding(.top, 3)
                                    .padding(.bottom, 3)
                                    .onTapGesture {
                                        showUserDefaultsAlert5 = true
                                    }
                                    .alert(isPresented: $showUserDefaultsAlert5) {
                                        Alert(title: Text("Delete Blocked Tags"), message: Text("Do you want to delete all blocked tags?"), primaryButton: .destructive(Text("Settings.delete")) {
                                            UserDefaultsManager.shared.saveBlockedTags([])
                                            blockedTags = []
                                            showUserDefaultsAlert5 = false
                                        },
                                              secondaryButton: .cancel() {showUserDefaultsAlert5 = false} )
                                        
                                    }
                                    
                                }
                                else {
                                    HStack {
                                        Image(systemName: "arrow.uturn.left")
                                        //.frame(width: 20, height: 20)
                                            .foregroundStyle(.clear)
                                            .scaledToFit()
                                    }
                                    .frame(width: 26, height: 26)
                                    .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                    .cornerRadius(5)
                                    .font(.footnote)
                                    .foregroundStyle(.white)
                                    .padding(.top, 3)
                                    .padding(.bottom, 3)
                                }
                                ScrollView(.horizontal) {
                                    HStack {
                                        if !blockedTags.isEmpty {
                                            ForEach(blockedTags, id: \.self) { text in
                                                HStack {
                                                    Button {
                                                        blockedTags.removeAll(where: { $0 == text })
                                                        UserDefaultsManager.shared.saveBlockedTags(blockedTags)
                                                        //print("Delete \(text)")
                                                    } label: {
                                                        Image(systemName: "xmark")
                                                            //.resizable()
                                                            .scaleEffect(1.4)
                                                            //.frame(width: 15, height: 15)
                                                            .foregroundStyle(isColorTooDark(color: selectedColor) ? .white : .black)
                                                        //.padding(-6)
                                                            .padding(.leading, 8)
                                                    }
                                                    Text(text)
                                                        .padding(.trailing, 6)
                                                        .padding(.leading, -2)
                                                        .font(.callout)
                                                        .padding(4)
                                                }
                                                .frame(height: 26)
                                                .background(selectedColor)
                                                .cornerRadius(5)
                                                .font(.footnote)
                                                .foregroundStyle(isColorTooDark(color: selectedColor) ? .white : .black)
                                            }
                                        }
                                        else {
                                            ForEach(3...5, id: \.self) { number in
                                                HStack {
                                                    
                                                }
                                                .frame(width: 75,height: 26)
                                                .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                                .cornerRadius(5)
                                                .font(.footnote)
                                                .foregroundStyle(.white)
                                            }
                                        }
                                    }
                                }
                                .cornerRadius(5)
                            }
                        }
                    }
                }
                /*
                    Text("Show Quick Searchqerys")
                 */
            }
            if showTags {
                Text("If some Tags are not spefic enough, you can block them by clicking on 🚫. Blocked Tags will be shown here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .padding(.top, -8)
                    .padding(.bottom, -8)
            }
            else {
                Text("Tags are automatically generated from text detected in images to improve search results.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .padding(.top, -8)
                    .padding(.bottom, -8)
            }

            Section(header: Text(String(format: NSLocalizedString("Settings.QRcode", comment: ""))), footer: Text("If you plan to reuse a QR code later, you should consider disabling the location.")) {
                Picker("Print Layout", selection: $qrCodeCopies) {
                    ForEach([1, 2, 4], id: \.self) { value in
                        let layout = layoutDescription(for: value)
                        Text(layout).tag(value)
                    }
                    Text("2x4").tag(8)
                    ForEach([9, 16], id: \.self) { value in
                        let layout = layoutDescription(for: value)
                        Text(layout).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .id(qrSectionAnchorID)
                .onChange(of: qrCodeCopies, initial: false) { oldValue, newValue in
                    if qrCodeCopies == 8 {
                        UserDefaultsManager.shared.saveQRCodeCopies(8)
                        UserDefaultsManager.shared.saveQRCodeNumber(8)
                    }
                    else {
                        UserDefaultsManager.shared.saveQRCodeCopies(newValue)
                        UserDefaultsManager.shared.saveQRCodeNumber(newValue)
                    }
                    markQRCodeAsCustomized()
                }
                .onAppear {
                    qrCodeCopies = UserDefaultsManager.shared.getQRCodeCopies()
                }
                HStack {
                    Text("Dynamic scaling")
                    Spacer()
                    Toggle("", isOn: $dynamicQRCode)
                        .onChange(of: dynamicQRCode, initial: false) { oldValue, newValue in
                            UserDefaultsManager.shared.saveDynamicQRCode(newValue)
                            markQRCodeAsCustomized()
                            //updateUserDefaultsSize() // Größe aktualisieren
                        }
                        .tint(accentColorManager.accentColor)
                }
                HStack {
                    Text("BoxHelper")
                    Spacer()
                    Toggle("", isOn: $showQRCodeLogo)
                        .onChange(of: showQRCodeLogo, initial: false) { oldValue, newValue in
                            UserDefaultsManager.shared.saveShowQRCodeLogo(newValue)
                            markQRCodeAsCustomized()
                            //updateUserDefaultsSize() // Größe aktualisieren
                        }
                        .tint(accentColorManager.accentColor)
                }
                HStack {
                    Text("CreateView.BoxTitle")
                    Spacer()
                    Toggle("", isOn: $showQRCodeName)
                        .onChange(of: showQRCodeName, initial: false) { oldValue, newValue in
                            UserDefaultsManager.shared.saveShowQRCodeName(newValue)
                            markQRCodeAsCustomized()
                            //updateUserDefaultsSize() // Größe aktualisieren
                        }
                        .tint(accentColorManager.accentColor)
                }
                HStack {
                    Text("CreateView.Location")
                    Spacer()
                    Toggle("", isOn: $showQRCodeLocation)
                        .onChange(of: showQRCodeLocation, initial: false) { oldValue, newValue in
                            UserDefaultsManager.shared.saveShowQRCodeLocation(newValue)
                            if !newValue {
                                showQRCodeLocationColor = false
                                UserDefaultsManager.shared.saveShowQRCodeLocationColor(false)
                            }
                            markQRCodeAsCustomized()
                            //updateUserDefaultsSize() // Größe aktualisieren
                        }
                        .tint(accentColorManager.accentColor)
                }
                HStack {
                    Text("Print location color")
                    Spacer()
                    Toggle("", isOn: $showQRCodeLocationColor)
                        .onChange(of: showQRCodeLocationColor, initial: false) { _, newValue in
                            UserDefaultsManager.shared.saveShowQRCodeLocationColor(newValue)
                            markQRCodeAsCustomized()
                        }
                        .tint(accentColorManager.accentColor)
                }
                .disabled(!showQRCodeLocation)
                .opacity(showQRCodeLocation ? 1.0 : 0.45)
                HStack {
                    Text("Tiny QR Code")
                    Spacer()
                    Toggle("", isOn: $tinyQRCode)
                        .onChange(of: tinyQRCode, initial: false) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "tinyQRCode")
                            markQRCodeAsCustomized()
                        }
                        .tint(accentColorManager.accentColor)
                }
                HStack {
                    Text("Horizontal layout")
                    Spacer()
                    Toggle("", isOn: $horizontalQRCodeLayout)
                        .onChange(of: horizontalQRCodeLayout, initial: false) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "horizontalQRCodeLayout")
                            markQRCodeAsCustomized()
                        }
                        .tint(accentColorManager.accentColor)
                }
                HStack {
                    if let qrCodeImage = qrCodeImage {
                        Image(uiImage: qrCodeImage)
                            .resizable()
                            .scaledToFit()
                            .background(Color.white)
                            //.cornerRadius(8)
                            .scaleEffect(0.92)
                            .frame(width: 75, height: 100)
                    }
                }
                .onChange(of: dynamicQRCode) { _, _ in updateQRCodePreview() }
                .onChange(of: showQRCodeLogo) { _, _ in updateQRCodePreview() }
                .onChange(of: showQRCodeLocation) { _, _ in updateQRCodePreview() }
                .onChange(of: showQRCodeLocationColor) { _, _ in updateQRCodePreview() }
                .onChange(of: tinyQRCode) { _, _ in updateQRCodePreview() }
                .onChange(of: horizontalQRCodeLayout) { _, _ in updateQRCodePreview() }
                .onChange(of: showQRCodeName) { _, _ in updateQRCodePreview() }
                .overlay( /// apply a rounded border
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary, lineWidth: 2)
                )
                .background(Color.white)
                .cornerRadius(8)
                .frame(width: 75, height: 100)
            }

            Section(header: Text("Settings.Appereance")) {
                /*
                Text("Settings.showImages")
                */
                HStack {
                    Text("Settings.showDetails")
                    Spacer()
                    Toggle("", isOn: $showDetails)
                        .onChange(of: showDetails, initial: false) { oldValue, newValue in
                            UserDefaultsManager.shared.saveShowDetails(newValue)
                            //updateUserDefaultsSize() // Größe aktualisieren
                        }
                        .tint(accentColorManager.accentColor)
                }
                .onAppear {
                    //Die Einstellungen sind nicht so wichtig und müssen nicht neu aufgerufen werden
                    UserDefaultsManager.shared.saveLastState("")
                    //sliderValue = UserDefaultsManager.shared.loadSliderValue()
                    ///TAGS DEAKTIVIERT!!!!
                    showTags = UserDefaults.standard.object(forKey: "showTags") == nil ? true : UserDefaults.standard.bool(forKey: "showTags")
                    //showImages = UserDefaults.standard.object(forKey: "showImages") == nil ? true : UserDefaults.standard.bool(forKey: "showImages")
                    showDetails = UserDefaults.standard.object(forKey: "showDetails") == nil ? true : UserDefaults.standard.bool(forKey: "showDetails")
                }
                if showDetails {
                    HStack {
                        Text("Settings.showDetailsLocation")
                        Spacer()
                        Toggle("", isOn: $showDetailsLocation)
                            .onChange(of: showDetailsLocation, initial: false) { oldValue, newValue in
                                UserDefaultsManager.shared.saveShowDetailsLocation(newValue)
                                //updateUserDefaultsSize() // Größe aktualisieren
                            }
                            .tint(accentColorManager.accentColor)
                    }
                    /*
                    HStack {
                        Text("Show Items")
                        Spacer()
                        Toggle("", isOn: $showDetailsItems)
                            .onChange(of: showDetailsItems, initial: false) { oldValue, newValue in
                                UserDefaultsManager.shared.saveShowDetailsItems(newValue)
                                //updateUserDefaultsSize() // Größe aktualisieren
                            }
                            .tint(accentColorManager.accentColor)
                    }
                     */
                    HStack {
                        Text("Settings.showDetailsItemCounter")
                        Spacer()
                        Toggle("", isOn: $showDetailsItemsCounter)
                            .onChange(of: showDetailsItemsCounter, initial: false) { oldValue, newValue in
                                UserDefaultsManager.shared.saveShowDetailsItemsCounter(newValue)
                                //updateUserDefaultsSize() // Größe aktualisieren
                            }
                            .tint(accentColorManager.accentColor)
                    }
                    ///TAGS DEAKTIVIERT!!!!
                    if showTags {
                        HStack {
                            Text("Show Tag Counter")
                            Spacer()
                            Toggle("", isOn: $showDetailsTagCounter)
                                .onChange(of: showDetailsTagCounter, initial: false) { oldValue, newValue in
                                    UserDefaultsManager.shared.saveShowDetailsTagCounter(newValue)
                                    //updateUserDefaultsSize() // Größe aktualisieren
                                }
                                .tint(accentColorManager.accentColor)
                        }
                    }
                    HStack {
                        Text("Settings.showDetailsImagesCounter")
                        Spacer()
                        Toggle("", isOn: $showDetailsImagesCounter)
                            .onChange(of: showDetailsImagesCounter, initial: false) { oldValue, newValue in
                                UserDefaultsManager.shared.saveShowDetailsImagesCounter(newValue)
                                //updateUserDefaultsSize() // Größe aktualisieren
                            }
                            .tint(accentColorManager.accentColor)
                    }
                    HStack {
                        Text("Settings.showDetailsDate1")
                        Spacer()
                        Toggle("", isOn: $showDetailsDate1)
                            .onChange(of: showDetailsDate1, initial: false) { oldValue, newValue in
                                UserDefaultsManager.shared.saveShowDetailsDate1(newValue)
                                //updateUserDefaultsSize() // Größe aktualisieren
                            }
                            .tint(accentColorManager.accentColor)
                    }
                    HStack {
                        Text("Settings.showDetailsDate2")
                        Spacer()
                        Toggle("", isOn: $showDetailsDate2)
                            .onChange(of: showDetailsDate2, initial: false) { oldValue, newValue in
                                UserDefaultsManager.shared.saveShowDetailsDate2(newValue)
                                //updateUserDefaultsSize() // Größe aktualisieren
                            }
                            .tint(accentColorManager.accentColor)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .listSectionSpacing(8)
        .onAppear {
            guard scrollToQRCodeSection, !didAutoScrollToQRCodeSection else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation {
                    proxy.scrollTo(qrSectionAnchorID, anchor: .top)
                }
                didAutoScrollToQRCodeSection = true
            }
        }
        }
    }
    
    private func resetLastBoxID() {
        lastBoxID = 0
        lastBoxIDInput = "0"
        UserDefaults.standard.set(0, forKey: "lastBoxID")
        introduceBoxNaming().invalidate(reason: .actionPerformed)
    }
    
    private func updateQRCodePreview() {
        let newImage = generateQRCodeForBoxPreview(
            previewUUID,
            text: NSLocalizedString("CreateView.Box", comment: ""),
            standort: NSLocalizedString("Location", comment: ""),
            dynamicQRCode: dynamicQRCode,
            showQRCodeLogo: showQRCodeLogo,
            showQRCodeLocation: showQRCodeLocation,
            showQRCodeName: showQRCodeName,
            showQRCodeLocationColor: showQRCodeLocationColor,
            showTinyQRCode: tinyQRCode,
            horizontalQRCodeLayout: horizontalQRCodeLayout,
            standortColor: UIColor.systemBlue
        )
        qrCodeImage = newImage?.withRenderingMode(.alwaysOriginal) ?? UIImage()
    }

    private func markQRCodeAsCustomized() {
        customizableQRCodeTip().invalidate(reason: .actionPerformed)
    }
}
            
