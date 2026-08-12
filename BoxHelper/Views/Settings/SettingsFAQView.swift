//
//  SettingsRoadmapView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 30.01.25.
//

//
//  SettingsAppereance.swift
//  BoxHelper
//
//  Created by HOCKULUS on 30.01.25.
//

import SwiftUI

struct SettingsFAQView: View {
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State private var searchText: String = ""

    struct FAQItem: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
        let searchText: [String]
        var isExpanded: Bool
    }

    @State private var faqItems: [FAQItem] = [
        FAQItem(
            question: NSLocalizedString("How can I share my Boxes with friends and family?", comment: "Question about sharing boxes"),
            answer: NSLocalizedString("Go to App Settings → Storage & Backup. Create a backup and share it. Currently, this is the only way to share Boxes.", comment: "Answer about how to share boxes"),
            searchText: ["share", "sharing", "backup", "export", "import", "sync", "family", "friends", "transfer"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("Why does a 👻 emoji appear instead of text?", comment: "Question about emoji appearing instead of text"),
            answer: NSLocalizedString("This means the saved text was empty. If you believe it's a bug, please recreate the issue and send a description.", comment: "Answer about why an emoji appears instead of text"),
            searchText: ["emoji", "ghost", "text", "empty", "missing", "placeholder", "bug","icon"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("Why is the app laggy when scrolling?", comment: "Question about app lagging when scrolling"),
            answer: NSLocalizedString("Performance may drop with many high-res images. Check image resolution in Settings and try to reduce images if needed.", comment: "Answer about performance issues with large images"),
            searchText: ["lag", "laggy", "slow", "scroll", "performance", "images", "large", "resolution", "throttle"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("Is any of my data transmitted over the internet?", comment: "Question about privacy and data transmission"),
            answer: NSLocalizedString("No personal data is ever transmitted to me. All your content is securely stored locally on your device.", comment: "Answer about privacy and data transmission"),
            searchText: ["privacy", "data", "transmission", "internet", "upload", "cloud", "local", "secure", "security", "offline"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("The app feels unfinished and obvious features are missing. It seems too simple.", comment: "Question about app being too simple"),
            answer: NSLocalizedString("You're right! The app is still very young and under active development. My goal is to keep it simple and focused, but more features will be added step by step. If something important is missing for you, I’d really appreciate hearing from you!", comment: "Answer about app being too simple"),
            searchText: ["unfinished", "missing", "feature", "simple", "basic", "incomplete", "feedback", "rückmeldung", "bug", "fehler", "problem", "idea", "vorschlag", "suggestion"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("What happens if I delete the app?", comment: "Question about what happens when the app is deleted"),
            answer: NSLocalizedString("All your data will be permanently deleted when the app is removed. Since everything is stored only on your device, make sure to create a manual backup in the app settings before deleting if you want to keep your data.", comment: "Answer about data loss when deleting the app"),
            searchText: ["delete", "remove", "uninstall", "data", "lost", "backup", "local storage", "reset", "löschen","daten","entfernen","app","backup","local storage","reset","wiederherstellen","lokaler Speicher"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("Why don’t my locations show colors on the QR code?", comment: "Question about missing color representation for locations on QR codes"),
            answer: NSLocalizedString("Currently, it's not technically possible to display custom colors directly on the QR code. However, you’re welcome to use colored emojis like 🟦 or 🔵 in your location names to visually highlight them in the QR code. It's a simple and effective workaround!", comment: "Answer explaining QR code color limitations and emoji workaround"),
            searchText: ["qr", "code", "color", "location", "emoji", "blue", "highlight", "label", "missing"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("Can I import RAW images into the app?", comment: "Question about RAW image support"),
            answer: NSLocalizedString("Currently, the app supports common formats like HEIC, JPG and PNG. RAW image files are not officially supported and may not display correctly. This is due to limited system-level support and file size considerations.", comment: "Answer about lack of RAW image support"),
            searchText: ["raw", "image", "photo", "jpg", "png", "heic", "unsupported", "format", "camera", "import"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("Can I edit or use my backup data outside the app?", comment: "Question about accessing and editing backup data externally"),
            answer: NSLocalizedString("Yes, you can export your backup and open it with any ZIP program to view or edit the raw data. Just make sure not to change the internal folder structure. When compressing the data again, do not include an extra top-level folder. The original structure must remain intact. Otherwise, the import might fail.", comment: "Answer explaining how to safely edit or repack exported backup data"),
            searchText: ["backup", "zip", "edit", "raw", "external", "import", "structure", "error", "export", "unpack"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("Why is the app free?", comment: "Question about why the app doesn’t cost anything"),
            answer: NSLocalizedString("I’m developing this app in my free time and currently don’t charge anything — mostly because setting up payment systems and handling taxes is a bit too complex for me right now. Of course, I still have ongoing costs to keep the app available in the App Store. If the app is useful to you, a quick rating or review would mean a lot and really helps support my work!", comment: "Answer explaining that the app is free for simplicity but still has ongoing costs, and encourages App Store support"),
            searchText: ["free", "cost", "price", "support", "donate", "review", "app store", "why", "payment", "charge","taxes"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("Can I support the app?", comment: "Question about how users can support development"),
            answer: NSLocalizedString("Yes, absolutely! Whether you want to help with translations, offer feedback, contribute ideas, or support the app financially — I really appreciate it. Just send me an email and let me know how you'd like to help.", comment: "Answer explaining how users can help support development, including by email"),
            searchText: ["support", "help", "translate", "contribute", "development", "funding", "finance", "email", "feedback", "contact"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("I run a company – can we collaborate?", comment: "Question from companies about possible partnerships"),
            answer: NSLocalizedString("Sure! I’m always open to meaningful collaborations that offer real value to users. For example, I’d love to offer discounts or vouchers for boxes or storage products that help people organize their space better. If you’re interested, feel free to get in touch by email — I’d be happy to hear your ideas.", comment: "Answer encouraging business collaborations that benefit app users, like discounts for storage boxes"),
            searchText: ["company", "business", "partnership", "collaboration", "sponsor", "discount", "boxes", "cooperate", "voucher"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("Can I take over the app project?", comment: "Question about taking over or acquiring the app"),
            answer: NSLocalizedString("As a solo developer, keeping an app alive and evolving is both challenging and time-consuming. I’d be happy to see the app grow under professional leadership. If you're seriously interested, feel free to reach out by email.", comment: "Answer explaining that the app could be handed over if the conditions are right"),
            searchText: ["takeover", "buy", "acquire", "project", "app", "ownership", "handover", "solo", "developer", "offer"],
            isExpanded: false
        ),
        FAQItem(
            question: NSLocalizedString("Why does the app or its web presence seem unprofessional or incomplete?", comment: "Question about the app or website appearing unpolished"),
            answer: NSLocalizedString("Fair question. I’m a solo developer and have limited time and resources. My main focus is building a private, useful, and stable app. That’s why the app might look simple or the online presence might feel basic. I appreciate your understanding and support as I continue to improve things step by step.", comment: "Answer explaining the limited scope of a solo developer and focus on core functionality first"),
            searchText: ["unprofessional", "website", "web", "appearance", "design", "serious", "trust", "presentation", "developer", "solo"],
            isExpanded: false
        )
    ]

    // 🔍 Gefilterte FAQs nach Suchtext
    var filteredItems: [Binding<FAQItem>] {
        if searchText.isEmpty {
            return $faqItems.filter { item in
                true
            }
        } else {
            return $faqItems.filter { item in
                let lowercasedSearch = searchText.lowercased()
                return item.wrappedValue.question.lowercased().contains(lowercasedSearch) ||
                       item.wrappedValue.searchText.contains(where: { $0.lowercased().contains(lowercasedSearch) })
            }
        }
    }

    var body: some View {
        List {
            ForEach(filteredItems) { $item in
                Section {
                    VStack{
                        HStack {
                            Text(item.question)
                                .font(.headline)
                            Spacer()
                            Image(systemName: item.isExpanded ? "chevron.down" : "chevron.right")
                                .foregroundStyle(selectedColor)
                        }
                        if item.isExpanded {
                            Text(item.answer)
                                .padding(.top, 8)
                        }
                    }
                    .onTapGesture {
                        for i in faqItems.indices {
                            if faqItems[i].id != item.id {
                                faqItems[i].isExpanded = false
                            }
                        }
                        item.isExpanded.toggle()
                    }
                }
                .onTapGesture {
                    for i in faqItems.indices {
                        if faqItems[i].id != item.id {
                            faqItems[i].isExpanded = false
                        }
                    }
                    item.isExpanded.toggle()
                }
            }
            Button(action: {
                sendSupportEmail()
            }) {
                HStack {
                    Text("Feedback")
                        .foregroundStyle(Color.primary)
                        //.fontWeight(.bold)
                    Spacer()
                    Image(systemName: "arrow.up.forward.app.fill")
                        .foregroundStyle(Color.primary.opacity(0.5))
                }
            }
            Button(action: {
                if let url = URL(string: "https://apps.apple.com/de/app/boxhelper/id6737223705?action=write-review") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Text("Write a review ♥")
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "arrow.up.forward.app.fill")
                        .foregroundStyle(Color.primary.opacity(0.5))
                }
                
            }
        }
        .onAppear
        {
            faqItems = faqItems.sorted { $0.question < $1.question }
        }
        .listSectionSpacing(8)
        .searchable(text: $searchText, placement: .toolbar)
        .navigationTitle("FAQs")
    }
}
