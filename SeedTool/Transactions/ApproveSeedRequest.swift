//
//  ApproveSeedRequest.swift
//  SeedTool
//
//  Created by Wolf McNally on 10/13/21.
//

import SwiftUI
import BCApp

struct ApproveSeedRequest: View {
    let transactionID: ARID
    let requestBody: SeedRequestBody
    let note: String?
    @Environment(Model.self) private var model
    @State private var seed: ModelSeed?
    @State private var activityParams: ActivityParams?
    @State private var isResponseRevealed: Bool = false

    init(transactionID: ARID, requestBody: SeedRequestBody, note: String?) {
        self.transactionID = transactionID
        self.requestBody = requestBody
        self.note = note
    }
    
    var responseUR: UR {
        TransactionResponse(id: transactionID, result: Seed(seed!)).ur
    }
    
    var responseFields: ExportFields {
        [
            .id: seed!.digestIdentifier,
            .placeholder: "Response with \(seed!.name)",
            .type: "Response",
            .subtype: "Seed",
            .format: "UR",
        ]
    }

    var body: some View {
        Group {
            if let seed = seed {
                VStack(alignment: .leading, spacing: 20) {
                    Info("Another device is requesting a specific seed on this device.")
                        .font(.title3)
                    TransactionChat {
                        Rebus {
                            Image.seed
                            Image.questionmark
                        }
                    }
                    ObjectIdentityBlock(model: .constant(seed))
                        .frame(height: 100)
                    RequestNote(note: note)
                    Caution("Sending this seed will allow the other device to derive keys and other objects from it. The seed’s name, notes, and other metadata will also be sent.")
                    LockRevealButton(isRevealed: $isResponseRevealed, isSensitive: true, isChatBubble: true) {
                        VStack(alignment: .trailing) {
                            Rebus {
                                Image.seed
                                Symbol.sentItem
                            }
                            URDisplay(
                                ur: responseUR,
                                name: seed.name,
                                fields: responseFields
                            )
                            ExportDataButton("Share as ur:\(responseUR.type)", icon: Image.ur, isSensitive: true) {
                                activityParams = ActivityParams(
                                    responseUR,
                                    name: seed.name,
                                    fields: responseFields
                                )
                            }
                            WriteNFCButton(ur: responseUR, isSensitive: true, alertMessage: "Write UR for response.")
                        }
                    } hidden: {
                        Text("Approve")
                            .foregroundColor(.yellowLightSafe)
                    }
                }
                .background(ActivityView(params: $activityParams))
            } else {
                Failure("Another device requested a specific seed that is not on this device.")
                TransactionChat(response: .error) {
                    Rebus {
                        Image.seed
                        Image.questionmark
                    }
                }
            }
        }
        .onAppear {
            seed = model.findSeed(with: Fingerprint(digest: requestBody.digest))
        }
        .navigationBarTitle("Seed Request")
    }
}

#if DEBUG

import WolfLorem

struct SeedRequest_Previews: PreviewProvider {
    static let model = Lorem.model()
    static let settings = Settings(storage: MockSettingsStorage())
    static let matchingSeed = model.seeds.first!
    static let nonMatchingSeed = Lorem.seed()

    static func requestForSeed(_ seed: ModelSeed) -> TransactionRequest {
        try! TransactionRequest(body: SeedRequestBody(seedDigest: seed.fingerprint.digest))
    }

    static let matchingSeedRequest = requestForSeed(matchingSeed)
    static let nonMatchingSeedRequest = requestForSeed(nonMatchingSeed)
        
    static var previews: some View {
        Group {
            ApproveRequest(isPresented: .constant(true), request: matchingSeedRequest)
                .environment(model)
                .environment(settings)
                .previewDisplayName("Matching Seed Request")

            ApproveRequest(isPresented: .constant(true), request: nonMatchingSeedRequest)
                .environment(model)
                .environment(settings)
                .previewDisplayName("Non-Matching Seed Request")
        }
        .environment(model)
        .darkMode()
    }
}

#endif
