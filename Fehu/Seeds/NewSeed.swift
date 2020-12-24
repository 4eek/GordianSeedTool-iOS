//
//  NewSeed.swift
//  Fehu
//
//  Created by Wolf McNally on 12/9/20.
//

import SwiftUI
import WolfSwiftUI

struct NewSeed: View {
    @Binding var isPresented: Bool
    let addSeed: (Seed) -> Void
    @State var newSeed: Seed?

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                RevealButton {
                    Text("Seeds are stored encrypted in the system keychain using your device passcode. When your device is locked no one can access them without the passcode.")
                } hidden: {
                    Text("Seeds are stored encrypted.")
                }
                Form {
                    Section {
                        sectionHeader("Generate a new seed with cryptographic strength.")
                        Button {
                            newSeed = Seed()
                            isPresented = false
                        } label: {
                            Label("Quick Create", systemImage: "hare")
                        }
                    }
                    
                    Section {
                        sectionHeader("Generate a new seed from entropy you provide.")
                        KeypadItem(BitKeypad.self, imageName: "centsign.circle") { seed in
                            newSeed = seed
                            isPresented = false
                        }
                        KeypadItem(DieKeypad.self, imageName: "die.face.3") { seed in
                            newSeed = seed
                            isPresented = false
                        }
                        KeypadItem(CardKeypad.self, imageName: "suit.heart") { seed in
                            newSeed = seed
                            isPresented = false
                        }
                    }
                    
                    Section {
                        sectionHeader("Import an existing seed.")
                        KeypadItem(ByteKeypad.self, imageName: "number") { seed in
                            newSeed = seed
                            isPresented = false
                        }
                        ImportItem(ImportChildView<ImportURModel>.self, title: "Scan ur:crypto-seed QR Code", imageName: "qrcode.viewfinder", shouldScan: true) { seed in
                            newSeed = seed
                            isPresented = false
                        }
                        ImportItem(ImportChildView<ImportURModel>.self, title: "ur:crypto-seed", imageName: "u.circle", shouldScan: false) { seed in
                            newSeed = seed
                            isPresented = false
                        }
                        ImportItem(ImportChildView<ImportBIP39Model>.self, title: "BIP39 mnemonic", imageName: "b.circle", shouldScan: false) { seed in
                            newSeed = seed
                            isPresented = false
                        }
                        ImportItem(ImportChildView<ImportSSKRModel>.self, title: "SSKR", imageName: "s.circle", shouldScan: false) { seed in
                            newSeed = seed
                            isPresented = false
                        }
                    }
                }
            }
            .padding()
            .accentColor(.green)
            .navigationTitle("Add Seed")
            .navigationBarItems(leading: cancelButton)
        }
        .onDisappear {
            if let newSeed = newSeed {
                addSeed(newSeed)
            }
        }
    }

    var cancelButton: some View {
        CancelButton {
            isPresented = false
        }
    }

    func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding()
    }

    struct ImportItem<ImportChildViewType>: View where ImportChildViewType: Importer {
        @State var isPresented: Bool = false
        let title: String
        let imageName: String
        let shouldScan: Bool
        let addSeed: (Seed) -> Void
        
        init(_ importChildViewType: ImportChildViewType.Type, title: String, imageName: String, shouldScan: Bool, addSeed: @escaping (Seed) -> Void) {
            self.title = title
            self.imageName = imageName
            self.shouldScan = shouldScan
            self.addSeed = addSeed
        }

        var body: some View {
            Button {
                isPresented = true
            } label: {
                Label(title, systemImage: imageName)
            }
            .sheet(isPresented: $isPresented) {
                ImportParentView(importChildViewType: ImportChildViewType.self, isPresented: $isPresented, shouldScan: shouldScan) { seed in
                    addSeed(seed)
                }
            }
        }
    }

    struct KeypadItem<KeypadType>: View where KeypadType: View & Keypad {
        @State var isPresented: Bool = false
        let imageName: String
        let addSeed: (Seed) -> Void

        init(_ KeypadType: KeypadType.Type, imageName: String, addSeed: @escaping (Seed) -> Void) {
            self.imageName = imageName
            self.addSeed = addSeed
        }

        var body: some View {
            Button {
                isPresented = true
            } label: {
                Label(KeypadType.name, systemImage: imageName)
            }.sheet(isPresented: $isPresented) {
                EntropyView(keypadType: KeypadType.self, isPresented: $isPresented) { seed in
                    addSeed(seed)
                }
            }
        }
    }
}

#if DEBUG

struct NewSeed_Previews: PreviewProvider {
    static var previews: some View {
        NewSeed(isPresented: .constant(true), addSeed: { _ in })
            .preferredColorScheme(.dark)
    }
}

#endif
