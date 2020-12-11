//
//  SeedList.swift
//  Fehu
//
//  Created by Wolf McNally on 12/9/20.
//

import SwiftUI
import LifeHash

struct SeedList: View {
    @EnvironmentObject var model: Model
    @State var isNewSeedPresented: Bool = false
    @State var isNameSeedPresented: Bool = false
    @State var newSeed: Seed?

    var body: some View {
        VStack(spacing: 0) {
            if model.seeds.isEmpty {
                Label("Tap the button above to add a seed.", systemImage: "plus")
                    .padding()
            }

            List {
                ForEach(model.seeds) { seed in
                    Item(seed: seed)
                }
                .onDelete { indexSet in
                    withAnimation {
                        model.seeds.remove(atOffsets: indexSet)
                    }
                }
                .onMove { indices, newOffset in
                    model.seeds.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
        }
        .navigationTitle("Seeds")
        .navigationBarItems(leading: addButton, trailing: trailingNavigationBarItems)
        .onChange(of: newSeed) { value in
            if newSeed != nil {
                isNameSeedPresented = true
            }
        }
        .sheet(isPresented: $isNameSeedPresented) {
            VStack {
                if let newSeed = newSeed {
                    NameSeed(seed: newSeed, isPresented: $isNameSeedPresented) {
                        withAnimation {
                            model.seeds.insert(newSeed, at: 0)
                        }
                    }
                }
            }
        }
        .onChange(of: isNewSeedPresented) { value in
            print("isNewSeedPresented: \(isNewSeedPresented)")
        }
        .onChange(of: isNameSeedPresented) { value in
            print("isNameSeedPresented: \(isNameSeedPresented)")
        }
    }

    var trailingNavigationBarItems: some View {
        Group {
            if model.seeds.isEmpty {
                EmptyView()
            } else {
                EditButton()
            }
        }
    }

    var addButton: some View {
        Button {
            isNewSeedPresented = true
        } label: {
            Image(systemName: "plus")
                .padding()
        }
        .sheet(isPresented: $isNewSeedPresented) {
            NewSeed(isPresented: $isNewSeedPresented) { seed in
                newSeed = seed
            }
        }
    }

    struct Item: View {
        @ObservedObject var seed: Seed
        @StateObject var lifeHashState: LifeHashState

        init(seed: Seed) {
            self.seed = seed
            _lifeHashState = .init(wrappedValue: LifeHashState(input: seed))
        }

        var body: some View {
            NavigationLink(destination: SeedDetail(seed: seed)) {
                ModelObjectIdentity(fingerprint: seed.fingerprint, type: .seed, name: $seed.name)
                    .frame(height: 64)
            }
        }
    }
}

import WolfLorem

struct SeedList_Previews: PreviewProvider {
    static let model: Model = Lorem.model()

    static var previews: some View {
        NavigationView {
            SeedList()
        }
        .environmentObject(model)
        .preferredColorScheme(.dark)
    }
}