//
//  SeedDetail.swift
//  Fehu
//
//  Created by Wolf McNally on 12/10/20.
//

import SwiftUI
import Combine

struct SeedDetail: View {
    @ObservedObject var seed: Seed
    @Binding var isValid: Bool
    let saveWhenChanged: Bool
    let provideSuggestedName: Bool
    @State private var isEditingNameField: Bool = false
    @State private var presentedSheet: Sheet? = nil
    @EnvironmentObject var pasteboardCoordinator: PasteboardCoordinator
    
    private var seedCreationDate: Binding<Date> {
        Binding<Date>(get: {
            return seed.creationDate ?? Date()
        }, set: {
            seed.creationDate = $0
        })
    }

    init(seed: Seed, saveWhenChanged: Bool, provideSuggestedName: Bool = false, isValid: Binding<Bool>) {
        self.seed = seed
        self.saveWhenChanged = saveWhenChanged
        self.provideSuggestedName = provideSuggestedName
        _isValid = isValid
    }

    enum Sheet: Int, Identifiable {
        case ur
        case sskr
        case key

        var id: Int { rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                identity
                details
                data
                name
                creationDate
                notes
            }
            .padding()
        }
        .onReceive(seed.needsSavePublisher) { _ in
            if saveWhenChanged {
                seed.save()
            }
        }
        .onReceive(seed.isValidPublisher) {
            isValid = $0
        }
        .navigationBarBackButtonHidden(!isValid)
        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarItems(trailing: shareMenu)
        .sheet(item: $presentedSheet) { item -> AnyView in
            let isSheetPresented = Binding<Bool>(
                get: { presentedSheet != nil },
                set: { if !$0 { presentedSheet = nil } }
            )
            switch item {
            case .ur:
                return URView(subject: seed, isPresented: isSheetPresented).eraseToAnyView()
            case .sskr:
                return SSKRSetup(seed: seed, isPresented: isSheetPresented).eraseToAnyView()
            case .key:
                return KeyExport(seed: seed, isPresented: isSheetPresented).eraseToAnyView()
            }
        }
        .frame(maxWidth: 600)
    }

    var identity: some View {
        ModelObjectIdentity(id: seed.id, fingerprint: seed.fingerprint, type: .seed, name: $seed.name, provideSuggestedName: provideSuggestedName)
            .frame(height: 128)
    }

    var details: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Size: ").bold() + Text("\(seedBits) bits")
                Text("Strength: ").bold() + Text("\(entropyStrength.description)")
                    .foregroundColor(entropyStrengthColor)
//                Text("Creation Date: ").bold() + Text("unknown").foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    var data: some View {
        HStack {
            VStack(alignment: .leading) {
                Label("Data", systemImage: "shield.lefthalf.fill")
                LockRevealButton {
                    HStack {
                        Text(seed.data.hex)
                            .font(.system(.body, design: .monospaced))
                            .longPressAction {
                                pasteboardCoordinator.copyToPasteboard(seed.data.hex)
                            }
                        shareMenu
                    }
                } hidden: {
                    Text("Encrypted")
                        .foregroundColor(.secondary)
                }
                .fieldStyle()
            }
            Spacer()
        }
    }
    
    var creationDate: some View {
        VStack(alignment: .leading) {
            Label("Creation Date", systemImage: "calendar")
            HStack {
                if seed.creationDate != nil {
                    DatePicker(selection: seedCreationDate, displayedComponents: .date) {
                        Text("Creation Date")
                    }
                    .labelsHidden()
                    Spacer()
                    ClearButton {
                        seed.creationDate = nil
                    }
                    .font(.title3)
                } else {
                    Button {
                        seed.creationDate = Date()
                    } label: {
                        Text("unknown")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .fieldStyle()
        }
    }

    var name: some View {
        VStack(alignment: .leading) {
            Label("Name", systemImage: "quote.bubble")

            HStack {
                TextField("Name", text: $seed.name) { isEditing in
                    withAnimation {
                        isEditingNameField = isEditing
                    }
                }
                if isEditingNameField {
                    HStack(spacing: 20) {
                        FieldRandomTitleButton(seed: seed, text: $seed.name)
                        FieldClearButton(text: $seed.name)
                    }
                    .font(.title3)
                }
            }
            .validation(seed.nameValidator)
            .fieldStyle()
            .font(.body)
        }
    }

    var notes: some View {
        VStack(alignment: .leading) {
            Label("Notes", systemImage: "note.text")

            TextEditor(text: $seed.note)
                .id("notes")
                .frame(minHeight: 300)
                .fixedVertical()
                .fieldStyle()
        }
    }

    var shareMenu: some View {
        Menu {
            ContextMenuItem(title: "Copy as Hex", image: Image("hex.bar")) {
                pasteboardCoordinator.copyToPasteboard(seed.hex)
            }
            ContextMenuItem(title: "Copy as BIP39 words", image: Image("39.bar")) {
                pasteboardCoordinator.copyToPasteboard(seed.bip39)
            }
            ContextMenuItem(title: "Copy as SSKR words", image: Image("sskr.bar")) {
                pasteboardCoordinator.copyToPasteboard(seed.sskr)
            }
            ContextMenuItem(title: "Export as ur:crypto-seed…", image: Image("ur.bar")) {
                presentedSheet = .ur
            }
            ContextMenuItem(title: "Export as SSKR Multi-Share…", image: Image("sskr.bar")) {
                presentedSheet = .sskr
            }
            ContextMenuItem(title: "Derive and Export Key…", image: Image("key.fill.circle")) {
                presentedSheet = .key
            }
        } label: {
            Image(systemName: "square.and.arrow.up.on.square")
                .accentColor(.yellow)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .disabled(!isValid)
    }

    var seedBytes: Int {
        seed.data.count
    }

    var seedBits: Int {
        seedBytes * 8
    }

    var entropyStrength: EntropyStrength {
        EntropyStrength.categorize(Double(seedBits))
    }

    var entropyStrengthColor: Color {
        entropyStrength.color
    }
}

#if DEBUG

import WolfLorem

struct SeedDetail_Previews: PreviewProvider {
    static let seed = Lorem.seed()

    init() {
        UITextView.appearance().backgroundColor = .clear
    }

    static var previews: some View {
        NavigationView {
            SeedDetail(seed: seed, saveWhenChanged: true, isValid: .constant(true))
        }
        .preferredColorScheme(.dark)
    }
}

#endif
