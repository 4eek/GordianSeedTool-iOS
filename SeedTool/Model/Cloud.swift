//
//  Cloud.swift
//  SeedTool
//
//  Created by Wolf McNally on 6/12/21.
//

import Foundation
import CloudKit
import Combine
import UIKit
import SwiftUI
import os
import WolfBase
import BCApp

fileprivate let logger = Logger(subsystem: Application.bundleIdentifier, category: "Cloud")

class Cloud: ObservableObject {
    @Published private(set) var accountStatus: CKAccountStatus? {
        didSet {
            isSyncing = accountStatus == .available && settings.syncToCloud == .on
        }
    }
    
    var isSyncing: Bool = false {
        didSet {
            if oldValue != isSyncing && isSyncing == true {
                startSyncing()
            }
        }
    }

    static let container = CKContainer(identifier: "iCloud.com.blockchaincommons.Fehu")
    private lazy var database = Self.container.privateCloudDatabase
    private lazy var primaryZone = CKRecordZone(zoneName: "Primary")
    private var bag = Set<AnyCancellable>()
    private let model: Model
    private let settings: Settings
    private var isMock: Bool {
        settings.isMock
    }
    
    func removeChangeToken() {
        primaryZoneToken = nil
    }
    
    private var primaryZoneToken: CKServerChangeToken? {
        get {
            guard let data = UserDefaults.standard.value(forKey: "primaryZoneToken") as? Data else {
                return nil
            }
            
            guard let token = try! NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data) else {
                return nil
            }
            
            return token
        }
        set {
            if let token = newValue {
                let data = try! NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
                UserDefaults.standard.set(data, forKey: "primaryZoneToken")
            } else {
                UserDefaults.standard.removeObject(forKey: "primaryZoneToken")
            }
        }
    }
    
    init(model: Model, settings: Settings) {
        self.model = model
        self.settings = settings
        
        NotificationCenter.default.publisher(for: .CKAccountChanged).sink { value in
            //logger.debug("🔥 CKAccountChanged")
            self.updateAccountStatus()
        }.store(in: &bag)
        
        settings.$syncToCloud.sink { value in
            //logger.debug("🔥 syncToCloud: \(value) isSyncing: \(self.isSyncing)")
            self.updateAccountStatus()
        }.store(in: &bag)
        
        updateAccountStatus()
    }
    
    var syncStatus: (String, String) {
        guard settings.syncToCloud == .on else {
            return ("🟡", "Sync to iCloud is not active.")
        }
        
        switch accountStatus {
        case .available?:
            return ("🟢", "Sync to iCloud is active.")
        case .couldNotDetermine?:
            return ("🔴", "Could not determine status of iCloud account.")
        case .noAccount?:
            return ("🔴", "You are currently logged out of iCloud. No synchronization will be performed.")
        case .restricted?:
            return ("🔴", "Use of iCloud is currently restricted by permissions settings.")
        case .temporarilyUnavailable?:
            return ("🔴", "Temporarily unavailable.")
        case nil:
            return ("🔴", "Not determined.")
        @unknown default:
            return ("🔴", "Unknown.")
        }
    }

    private func updateAccountStatus() {
        guard !isMock else {
            self.accountStatus = .available
            return
        }
        
        Self.container.accountStatus { status, error in
            if let error = error {
                logger.error("⛔️ Unable to get cloud account status: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.accountStatus = status
                    //logger.debug("🔥 CKAccountStatus: \(status)")
                }
            }
        }
    }
    
    private func startSyncing() {
        logger.debug("🔵 startSyncing")
        setupZones() {
            logger.debug("🔵 Done with setupZones: \($0†)")
            //logger.debug("needsMergeWithCloud: \(self.settings.needsMergeWithCloud)")
            if self.settings.needsMergeWithCloud {
                self.model.mergeWithCloud() { result in
                    switch result {
                    case .success:
                        logger.debug("✅ mergeWithCloud")
                    case .failure(let error):
                        logger.error("⛔️ mergeWithCloud: \(error.localizedDescription)")
                    }
                    phase2()
                }
            } else {
                phase2()
            }
        }
        
        func phase2() {
            self.setupSubscriptions() {
                logger.debug("🔵 Done with setupSubscriptions: \($0†)")
                if !self.settings.needsMergeWithCloud {
                    self.fetchChanges {
                        logger.debug("🔵 Done with fetchChanges: \($0†)")
                    }
                }
            }
        }
        self.settings.needsMergeWithCloud = false
    }
    
    private func setupZones(completion: @escaping (Result<Void, Error>) -> Void) {
        guard !UserDefaults.standard.bool(forKey: "savedPrimaryZone") else {
            completion(.success(()))
            return
        }
        database.save(primaryZone) { _, error in
            if let error = error {
                logger.error("⛔️ Unable to save primary record zone: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                logger.debug("✅ Saved primary record zone")
                UserDefaults.standard.setValue(true, forKey: "savedPrimaryZone")
                completion(.success(()))
            }
        }
    }
    
    private func setupSubscriptions(completion: @escaping (Result<Void, Error>) -> Void) {
        setupSubscription(type: "Seed", subscriptionID: "seed-changes", userDefaultsKey: "hasSeedSubscription") { result in
            completion(result)
        }
    }
    
    private func setupSubscription(type: String, subscriptionID: String, userDefaultsKey: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !UserDefaults.standard.bool(forKey: userDefaultsKey) else {
            completion(.success(()))
            return
        }
        
        let subscription = CKRecordZoneSubscription(zoneID: primaryZone.zoneID, subscriptionID: subscriptionID)
        subscription.recordType = type
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                logger.debug("✅ Saved subscription for: \(subscriptionID)")
                UserDefaults.standard.setValue(true, forKey: userDefaultsKey)
                completion(.success(()))
            case .failure(let error):
                logger.error("⛔️ Couldn't create subscription: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        operation.qualityOfService = .userInitiated
        database.add(operation)
    }
    
    func decodeRecord<O>(type: O.Type, record: CKRecord) throws -> O where O: Decodable {
        guard let valueString = record.object(forKey: "value") as? String else {
            throw GeneralError("Could not retrieve value field from CloudKit record.")
        }
        guard let decodedRecord = try? JSONDecoder().decode(type, from: valueString.utf8Data) else {
            throw GeneralError("Could not decode value field in CloudKit record.")
        }
        return decodedRecord
    }
    
    func fetchAll<O>(type: String, completion: @escaping (Result<[O], Error>) -> Void) where O: Decodable {
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        database.fetch(withQuery: query, inZoneWith: primaryZone.zoneID) { result in
            switch result {
            case .success(let (recordResults, _)):
                var decodedRecords = [O]()
                for recordResult in recordResults {
                    switch recordResult.1 {
                    case .success(let record):
                        guard let decodedRecord = try? self.decodeRecord(type: O.self, record: record) else {
                            continue
                        }
                        decodedRecords.append(decodedRecord)
                    case .failure(let error):
                        logger.error("⛔️ Could not fetch record \(recordResult.0) of type \(type), error: \(error.localizedDescription)")
                    }
                }
                completion(.success(decodedRecords))
            case .failure(let error):
                logger.error("⛔️ Could not fetch records of type \(type), error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    func save<O>(type: String, id: UUID, object: O, completion: @escaping (Result<Void, Error>) -> Void) where O: Encodable {
        guard isSyncing else {
            completion(.success(()))
            return
        }
        
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: primaryZone.zoneID)
        database.fetch(withRecordID: recordID) { fetchedRecord, error in
            if let error = error {
                let nsError = error as NSError
                if nsError.domain == CKErrorDomain, nsError.code == CKError.unknownItem.rawValue {
                    // Item not found, ignore
                } else {
                    logger.error("⛔️ Could not fetch existing record \(id) error: \(error.localizedDescription)")
                }
            }
            let record = fetchedRecord ?? CKRecord(recordType: type, recordID: recordID)
            let value = try! JSONEncoder().encode(object)
            let valueString = value.utf8
            record.setValue(valueString, forKey: "value")
            //logger.debug("⬆️ Saving to cloud \(Date()) \(record.recordID)")
            self.database.save(record) { _, error in
                if let error = error {
                    logger.error("⛔️ Could not save to cloud \(Date()) \(record) error: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    //logger.debug("⬆️ Saved to cloud \(Date()) \(record.recordID)")
                    completion(.success(()))
                }
            }
        }
    }
    
    func fetch(id: String, completion: @escaping (CKRecord?, Error?) -> Void) {
        let recordID = CKRecord.ID(recordName: id, zoneID: primaryZone.zoneID)
        database.fetch(withRecordID: recordID, completionHandler: completion)
    }
    
    func delete(id: UUID) {
        guard isSyncing else {
            return
        }
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: primaryZone.zoneID)
        database.delete(withRecordID: recordID) { _, error in
            if let error = error {
                logger.error("⛔️ Could not delete from cloud \(Date()) \(recordID) error: \(error.localizedDescription)")
            } else {
                //logger.debug("🟥 Deleted from cloud \(Date()) \(recordID)")
            }
        }
    }
    
    let serialQueue = DispatchQueue(label: "serial")
    
    enum Action {
        case upsert(ModelSeed)
        case delete(UUID)
    }
    
    var actions = [Action]()
    
    private func addAction(_ action: Action) {
        serialQueue.sync {
            actions.append(action)
        }
    }
    
    func fetchChanges(completion: @escaping (Result<Void, Error>) -> Void) {
        guard isSyncing else {
            logger.debug("☁️ fetchChanges aborted, syncing not started.")
            return
        }
        logger.debug("☁️ fetchChanges")
        tryFetchChanges { [self] result in
            switch result {
            case .success:
                completion(result)
            case .failure(let error):
                if let error = error as? CKError, error.code == .changeTokenExpired {
                    logger.debug("⚠️ Change token expired. Retrying.")
                    removeChangeToken()
                    tryFetchChanges(completion: completion)
                }
            }
        }
    }
    
    private func tryFetchChanges(completion: @escaping (Result<Void, Error>) -> Void) {
        let previousToken = primaryZoneToken
//        let previousToken: CKServerChangeToken? = nil
        let recordZoneIDs = [primaryZone.zoneID]
        let configurations: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration] = [
            primaryZone.zoneID: CKFetchRecordZoneChangesOperation.ZoneConfiguration(previousServerChangeToken: previousToken)
        ]
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: recordZoneIDs, configurationsByRecordZoneID: configurations)
        
        operation.recordWasChangedBlock = { recordID, result in
            switch result {
            case .success(let record):
                logger.debug("🔶 record changed: \(record.recordID)")
                guard record.recordType == "Seed" else {
                    return
                }
                guard record.recordID.zoneID == self.primaryZone.zoneID else {
                    return
                }
                guard let seed = try? self.decodeRecord(type: ModelSeed.self, record: record) else {
                    return
                }
                self.addAction(.upsert(seed))
            case .failure(let error):
                logger.debug("⛔️ Error changing record \(Date()) \(recordID) error: \(error.localizedDescription)")
            }
        }
        
        operation.recordWithIDWasDeletedBlock = { recordID, recordType in
            logger.debug("🔶 record deleted, id: \(recordID) type: \(recordType)")
            guard recordType == "Seed" else {
                return
            }
            guard recordID.zoneID == self.primaryZone.zoneID else {
                return
            }
            guard let id = UUID(uuidString: recordID.recordName) else {
                return
            }
            self.addAction(.delete(id))
        }
        
        operation.recordZoneChangeTokensUpdatedBlock = { recordZoneID, token, _ in
            logger.debug("🔶 tokens updated: \(String(describing: token))")
            self.primaryZoneToken = token
        }
        
        operation.recordZoneFetchResultBlock = { recordZoneID, result in
            switch result {
            case .success(let (token, _, _)):
                logger.debug("🔶 fetch completed, token: \(String(describing: token))")
                
                self.primaryZoneToken = token
                completion(.success(()))
                
                func indexForSeed(in seeds: [ModelSeed], withID id: UUID) -> Int? {
                    return seeds.firstIndex { $0.id == id }
                }
                
                let actions = self.actions
                DispatchQueue.main.async {
                    withAnimation {
                        var newSeeds = self.model.seeds
                        for (_ /*actionIndex*/, action) in actions.enumerated() {
                            switch action {
                            case .upsert(let fetchedSeed):
                                fetchedSeed.isDirty = true
                                if let index = indexForSeed(in: newSeeds, withID: fetchedSeed.id) {
                                    newSeeds.remove(at: index)
                                    //logger.debug("🔥 \(actionIndex) update \(fetchedSeed.id)")
                                } else {
                                    //logger.debug("🔥 \(actionIndex) insert \(fetchedSeed.id)")
                                }
                                newSeeds.append(fetchedSeed)
                            case .delete(let deletedSeedID):
                                if let index = indexForSeed(in: newSeeds, withID: deletedSeedID) {
                                    let deletedSeed = newSeeds[index]
                                    //logger.debug("🔥 \(actionIndex) delete \(deletedSeed.id) at \(index)")
                                    deletedSeed.isDirty = true
                                    newSeeds.remove(at: index)
                                }
                            }
                        }
                        newSeeds.sortByOrdinal()
                        self.model.setSeeds(newSeeds, replicateToCloud: false)
                    }
                }
                self.actions.removeAll()
            case .failure(let error):
                completion(.failure(error))
            }
        }

        
        operation.fetchRecordZoneChangesResultBlock = { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                logger.debug("🔶 fetch record zone changes completed, error: \(String(describing: error))")
            }
        }
        
        operation.qualityOfService = .userInitiated
        database.add(operation)
    }
}

extension CKAccountStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .available:
            return "available"
        case .couldNotDetermine:
            return "couldNotDetermine"
        case .noAccount:
            return "noAccount"
        case .restricted:
            return "restricted"
        case .temporarilyUnavailable:
            return "temporarilyUnavailable"
        @unknown default:
            fatalError()
        }
    }
}

extension CKRecord.ID {
    convenience init(recordName: UUID) {
        self.init(recordName: recordName.uuidString)
    }
}
