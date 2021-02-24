//
//  UseInfo.swift
//  Guardian
//
//  Created by Wolf McNally on 1/22/21.
//

import Foundation
import URKit

// https://github.com/BlockchainCommons/Research/blob/master/papers/bcr-2020-007-hdkey.md#cddl-for-coin-info
struct UseInfo {
    let asset: Asset
    let network: Network

    init(asset: Asset = .btc, network: Network = .mainnet) {
        self.asset = asset
        self.network = network
    }
    
    var isDefault: Bool {
        return asset == .btc && network == .mainnet
    }
    
    var coinType: UInt32 {
        switch asset {
        case .btc:
            switch network {
            case .mainnet:
                return Asset.btc.rawValue
            case .testnet:
                return 1
            }
        case .eth:
            switch network {
            case .mainnet:
                return Asset.eth.rawValue
            case .testnet:
                return 1
            }
        }
//        case .bch:
//            switch network {
//            case .mainnet:
//                return Asset.bch.rawValue
//            case .testnet:
//                return 1
//            }
//        }
    }

    var cbor: CBOR {
        var a: [OrderedMapEntry] = []
        
        if asset != .btc {
            a.append(.init(key: 1, value: asset.cbor))
        }
        
        if network != .mainnet {
            a.append(.init(key: 2, value: network.cbor))
        }
        
        return CBOR.orderedMap(a)
    }
    
    var taggedCBOR: CBOR {
        CBOR.tagged(.useInfo, cbor)
    }

    init(cbor: CBOR) throws {
        guard case let CBOR.map(pairs) = cbor else {
            throw GeneralError("Invalid CoinInfo.")
        }
        
        let asset: Asset
        if let rawAsset = pairs[1] {
            asset = try Asset(cbor: rawAsset)
        } else {
            asset = .btc
        }
        
        let network: Network
        if let rawNetwork = pairs[2] {
            network = try Network(cbor: rawNetwork)
        } else {
            network = .mainnet
        }
        
        self.init(asset: asset, network: network)
    }
    
    init(taggedCBOR: CBOR) throws {
        guard case let CBOR.tagged(.useInfo, cbor) = taggedCBOR else {
            throw GeneralError("CoinInfo tag (305) not found.")
        }
        try self.init(cbor: cbor)
    }
}
