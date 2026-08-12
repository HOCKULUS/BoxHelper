//
//  SettingsBoxView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 30.01.25.
//


import SwiftUI

struct CreateSettingsView: View {
    var iconBackgroundColor: Color = .newRed
    var scrollToQRCodeSection: Bool = false
    @Environment(\.colorScheme) var colorScheme  // Zugriff auf Dark/Light Mode
    @EnvironmentObject var accentColorManager: AccentColorManager
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State var sliderValue4: Int = UserDefaults.standard.integer(forKey: "sliderValue4") == 0 ? 100 : UserDefaults.standard.integer(forKey: "sliderValue4")
    @State private var showQRCodeLogo: Bool = UserDefaults.standard.object(forKey: "showQRCodeLogo") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLogo")
    @State private var showQRCodeLocation: Bool = UserDefaults.standard.object(forKey: "showQRCodeLocation") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLocation")
    @State private var showQRCodeLocationColor: Bool = UserDefaults.standard.object(forKey: "showQRCodeLocationColor") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLocationColor")
    @State private var tinyQRCode: Bool = UserDefaults.standard.bool(forKey: "tinyQRCode")
    @State private var horizontalQRCodeLayout: Bool = UserDefaults.standard.bool(forKey: "horizontalQRCodeLayout")
    @State private var showQRCodeName: Bool = UserDefaults.standard.object(forKey: "showQRCodeName") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeName")
    @State private var dynamicQRCode: Bool = UserDefaults.standard.object(forKey: "dynamicQRCode") == nil ? true : UserDefaults.standard.bool(forKey: "dynamicQRCode")
    @State private var useShortQRCodeURL: Bool = UserDefaults.standard.object(forKey: "useShortQRCodeURL") == nil ? true : UserDefaults.standard.bool(forKey: "useShortQRCodeURL")
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
    @State private var saveCreateFormData: Bool = UserDefaults.standard.object(forKey: "saveCreateFormData") == nil ? true : UserDefaults.standard.bool(forKey: "saveCreateFormData")
    @State private var createNewItemInputAutofocusMode: String = UserDefaultsManager.shared.loadCreateNewItemInputAutofocusMode()
    @State private var createItemImageInputSource: String = UserDefaultsManager.shared.loadCreateItemImageInputSource()
    @State private var isRebuildingAutomaticTags: Bool = false
    @State private var rebuildAutomaticTagsStatus: String?
    @State private var rebuildAutomaticTagsTotalImages: Int = 0
    @State private var rebuildAutomaticTagsRemainingImages: Int = 0
    
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
                            
                            Image(systemName: "plus.circle.fill")
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
                        Text("TabView.Label.Create")
                            .font(.system(size: 25, weight: .bold))
                        Spacer()
                    }
                    HStack {
                        Text("Configure everything required to create new boxes. Select a naming scheme, adjust QR code genration and tag options and more.")
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
                    .listRowSeparator(!showBoxNameSheme ? Visibility.automatic : Visibility.hidden)
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
                    //.listRowSeparator(Visibility.visible)
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
                        /*
                        Button {
                            resetLastBoxID()
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .font(.title3)
                         */
                    }
                    //.listRowSeparator(Visibility.hidden)
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
                .listRowSeparator(Visibility.visible)
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
            Section(
                header: Text("Cache"),
                footer: Text("If enabled every value you fill in the Create-Tab will be saved on app launch.")
            ) {
                Toggle("Remember last input", isOn: $saveCreateFormData)
                    .onChange(of: saveCreateFormData, initial: true) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "saveCreateFormData")
                    }
            }

            Section(
                header: Text("New item focus"),
                footer: Text("Choose how the input fokus should be handled.")
            ) {
                Picker("New item field focus", selection: $createNewItemInputAutofocusMode) {
                    Text("never").tag("no")
                    Text("smart").tag("smart")
                    Text("always").tag("yes")
                }
                .pickerStyle(.segmented)
                .onChange(of: createNewItemInputAutofocusMode, initial: true) { _, newValue in
                    UserDefaultsManager.shared.saveCreateNewItemInputAutofocusMode(newValue)
                }
            }

            Section(
                header: Text("Item Images"),
                footer: Text("Choose which source should be used when adding an image to a new item.")
            ) {
                Picker("Item image source", selection: $createItemImageInputSource) {
                    Label("None", systemImage: "eye.slash.fill").tag("none")
                    Label("Camera", systemImage: "camera.fill").tag("camera")
                    Label("Gallery", systemImage: "photo.fill").tag("gallery")
                }
                .pickerStyle(.segmented)
                .onChange(of: createItemImageInputSource, initial: true) { _, newValue in
                    UserDefaultsManager.shared.saveCreateItemImageInputSource(newValue)
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
                    useShortURL: useShortQRCodeURL,
                    standortColor: UIColor.systemBlue
                )
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
                useShortQRCodeURL = UserDefaultsManager.shared.loadUseShortQRCodeURL()
                saveCreateFormData = UserDefaults.standard.object(forKey: "saveCreateFormData") == nil ? true : UserDefaults.standard.bool(forKey: "saveCreateFormData")
                createNewItemInputAutofocusMode = UserDefaultsManager.shared.loadCreateNewItemInputAutofocusMode()
                createItemImageInputSource = UserDefaultsManager.shared.loadCreateItemImageInputSource()
            }
            
            ///TAGS DEAKTIVIERT
            Section(header: Text("Tags"), footer: Text("Tags are automatically generated from text detected in images to improve search results.")) {
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
                                Text("500").tag(500)
                                Text("1000").tag(1000)
                                Text("2000").tag(2000)
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
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            rebuildAutomaticTagsFromStoredImages()
                        } label: {
                            HStack {
                                if isRebuildingAutomaticTags {
                                    ProgressView()
                                        .padding(.trailing, 4)
                                }
                                Text(isRebuildingAutomaticTags ? "Scanning images…" : "Rebuild tags from all images")
                                Spacer()
                            }
                        }
                        .disabled(isRebuildingAutomaticTags)

                        if isRebuildingAutomaticTags, rebuildAutomaticTagsTotalImages > 0 {
                            let processedImages = rebuildAutomaticTagsTotalImages - rebuildAutomaticTagsRemainingImages
                            ProgressView(value: Double(processedImages), total: Double(rebuildAutomaticTagsTotalImages))
                                .progressViewStyle(.linear)

                            Text("\(rebuildAutomaticTagsTotalImages) images total, \(rebuildAutomaticTagsRemainingImages) remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let rebuildAutomaticTagsStatus {
                            Text(rebuildAutomaticTagsStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                    Text("ShortURL")
                    Spacer()
                    Toggle("", isOn: $useShortQRCodeURL)
                        .onChange(of: useShortQRCodeURL, initial: false) { _, newValue in
                            UserDefaultsManager.shared.saveUseShortQRCodeURL(newValue)
                            markQRCodeAsCustomized()
                        }
                        .tint(accentColorManager.accentColor)
                }
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
                    .overlay( /// apply a rounded border
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary, lineWidth: 2)
                    )
                    .background(Color.white)
                    .cornerRadius(8)
                    .frame(width: 75, height: 100)
                    VStack {
                        HStack {
                            Image(systemName:"arrowshape.right.fill")
                            Image(systemName:"printer.fill")
                        }
                    }
                    HStack {
                        QRPrintLayoutPreview(qrCodeImage: qrCodeImage, perPage: qrCodeCopies)
                            .frame(width: 75, height: 100)
                    }
                    .overlay( /// apply a rounded border
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary, lineWidth: 2)
                    )
                    .background(Color.white)
                    .cornerRadius(8)
                    .frame(width: 75, height: 100)
                }
                .onChange(of: dynamicQRCode) { _, _ in updateQRCodePreview() }
                .onChange(of: showQRCodeLogo) { _, _ in updateQRCodePreview() }
                .onChange(of: showQRCodeLocation) { _, _ in updateQRCodePreview() }
                .onChange(of: showQRCodeLocationColor) { _, _ in updateQRCodePreview() }
                .onChange(of: tinyQRCode) { _, _ in updateQRCodePreview() }
                .onChange(of: horizontalQRCodeLayout) { _, _ in updateQRCodePreview() }
                .onChange(of: showQRCodeName) { _, _ in updateQRCodePreview() }
                .onChange(of: useShortQRCodeURL) { _, _ in updateQRCodePreview() }
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
            useShortURL: useShortQRCodeURL,
            standortColor: UIColor.systemBlue
        )
        qrCodeImage = newImage?.withRenderingMode(.alwaysOriginal) ?? UIImage()
    }

    private func markQRCodeAsCustomized() {
        customizableQRCodeTip().invalidate(reason: .actionPerformed)
    }
}

private struct QRPrintLayoutPreview: View {
    let qrCodeImage: UIImage?
    let perPage: Int

    private let pageWidth: CGFloat = 595.0
    private let pageHeight: CGFloat = 842.0
    private let margin: CGFloat = 28.35
    private let spacing: CGFloat = 20.0

    var body: some View {
        if let renderedPage = makePrintPreviewPageImage() {
            Image(uiImage: renderedPage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        }
    }

    // Rendert exakt eine PDF-Seite als UIImage mit derselben Platzierungslogik wie beim Druck.
    private func makePrintPreviewPageImage() -> UIImage? {
        guard let qrCodeImage else { return nil }
        let pageSize = CGSize(width: pageWidth, height: pageHeight)
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 2
        let renderer = UIGraphicsImageRenderer(size: pageSize, format: rendererFormat)

        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: pageSize))

            for frame in previewSlots() {
                let rotate90 = perPage == 2 || perPage == 8
                let fittedImage = createFittedImage(from: qrCodeImage, in: frame.size, rotate90: rotate90)
                fittedImage.draw(in: frame)
            }
        }
    }

    private func createFittedImage(from image: UIImage, in size: CGSize, rotate90: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            guard let cgImage = image.cgImage else {
                image.draw(in: CGRect(origin: .zero, size: size))
                return
            }

            let imageToDraw = rotate90
                ? UIImage(cgImage: cgImage, scale: image.scale, orientation: .right)
                : image

            let imageSize = imageToDraw.size
            let widthRatio = size.width / imageSize.width
            let heightRatio = size.height / imageSize.height
            let scale = min(widthRatio, heightRatio)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let origin = CGPoint(x: (size.width - scaledSize.width) / 2, y: (size.height - scaledSize.height) / 2)
            imageToDraw.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }

    // Nutzt die gleichen Geometrie-Regeln wie der PDF-Druckcode.
    private func previewSlots() -> [CGRect] {
        let safePerPage = max(perPage, 1)
        let contentWidth = pageWidth - 2 * margin
        let contentHeight = pageHeight - 2 * margin

        if safePerPage == 1 {
            return [CGRect(x: margin, y: margin, width: contentWidth, height: contentHeight)]
        }

        if safePerPage == 2 {
            let availableHeight = contentHeight - spacing
            let halfHeight = availableHeight / 2
            return (0..<2).map { i in
                CGRect(
                    x: margin,
                    y: margin + CGFloat(i) * (halfHeight + spacing),
                    width: contentWidth,
                    height: halfHeight
                )
            }
        }

        if safePerPage == 8 {
            let labelSize = CGSize(width: (97.0 * 2.3), height: (67.7 * 2.3))
            let marginTop: CGFloat = 55.0
            let marginLeft: CGFloat = 45.84
            let horizontalSpacing: CGFloat = 60.08
            let verticalSpacing: CGFloat = 37

            var frames: [CGRect] = []
            for row in 0..<4 {
                for col in 0..<2 {
                    frames.append(
                        CGRect(
                            x: marginLeft + CGFloat(col) * (labelSize.width + horizontalSpacing),
                            y: marginTop + CGFloat(row) * (labelSize.height + verticalSpacing),
                            width: labelSize.width,
                            height: labelSize.height
                        )
                    )
                }
            }
            return frames
        }

        let cols = Int(ceil(sqrt(Double(safePerPage))))
        let rows = Int(ceil(Double(safePerPage) / Double(cols)))
        let totalSpacingX = CGFloat(cols - 1) * spacing
        let totalSpacingY = CGFloat(rows - 1) * spacing
        let itemWidth = (contentWidth - totalSpacingX) / CGFloat(cols)
        let itemHeight = (contentHeight - totalSpacingY) / CGFloat(rows)

        var frames: [CGRect] = []
        frames.reserveCapacity(safePerPage)

        var slotsUsed = 0
        for row in 0..<rows {
            for col in 0..<cols {
                guard slotsUsed < safePerPage else { break }
                frames.append(
                    CGRect(
                        x: margin + CGFloat(col) * (itemWidth + spacing),
                        y: margin + CGFloat(row) * (itemHeight + spacing),
                        width: itemWidth,
                        height: itemHeight
                    )
                )
                slotsUsed += 1
            }
        }

        return frames
    }
}

private extension CreateSettingsView {
    private func rebuildAutomaticTagsFromStoredImages() {
        guard !isRebuildingAutomaticTags else { return }

        let boxesWithImages = loadBoxes().filter { !$0.images.isEmpty }
        let itemsWithImages = loadItems().filter { !$0.images.isEmpty }
        let totalImages = boxesWithImages.reduce(0) { $0 + $1.images.count } + itemsWithImages.reduce(0) { $0 + $1.images.count }

        isRebuildingAutomaticTags = true
        rebuildAutomaticTagsStatus = nil
        rebuildAutomaticTagsTotalImages = totalImages
        rebuildAutomaticTagsRemainingImages = totalImages

        DispatchQueue.global(qos: .userInitiated).async {
            var boxes = loadBoxes()
            var items = loadItems()
            var updatedBoxes = 0
            var updatedItems = 0
            var addedTagsCount = 0

            for index in boxes.indices where !boxes[index].images.isEmpty {
                let imageCount = boxes[index].images.count
                let generatedTags = automaticTags(fromImagePaths: boxes[index].images)
                DispatchQueue.main.async {
                    rebuildAutomaticTagsRemainingImages = max(0, rebuildAutomaticTagsRemainingImages - imageCount)
                }
                let existingTags = boxes[index].tags ?? []
                let mergedTags = mergeStoredTags(existingTags, with: generatedTags)
                let newTagsAdded = mergedTags.count - existingTags.count

                if newTagsAdded > 0 {
                    boxes[index].tags = mergedTags
                    updatedBoxes += 1
                    addedTagsCount += newTagsAdded
                }
            }

            for index in items.indices where !items[index].images.isEmpty {
                let imageCount = items[index].images.count
                let generatedTags = automaticTags(fromImagePaths: items[index].images)
                DispatchQueue.main.async {
                    rebuildAutomaticTagsRemainingImages = max(0, rebuildAutomaticTagsRemainingImages - imageCount)
                }
                let existingTags = items[index].tags ?? []
                let mergedTags = mergeStoredTags(existingTags, with: generatedTags)
                let newTagsAdded = mergedTags.count - existingTags.count

                if newTagsAdded > 0 {
                    items[index].tags = mergedTags
                    updatedItems += 1
                    addedTagsCount += newTagsAdded
                }
            }

            saveBoxes(boxes)
            saveItems(items)

            DispatchQueue.main.async {
                isRebuildingAutomaticTags = false
                rebuildAutomaticTagsRemainingImages = 0
                rebuildAutomaticTagsStatus = "Added \(addedTagsCount) new tags across \(updatedBoxes) boxes and \(updatedItems) items."
            }
        }
    }
}

private func mergeStoredTags(_ existingTags: [String], with generatedTags: [String]) -> [String] {
    Array(Set(existingTags).union(generatedTags))
        .sorted { $0.localizedLowercase < $1.localizedLowercase }
}
