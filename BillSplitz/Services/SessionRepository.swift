//
//  SessionRepository.swift
//  BillSplitz
//

import Foundation

@MainActor
protocol SessionRepository {
    func loadActiveDraft() throws -> SplitDraft?
    func saveActiveDraft(_ draft: SplitDraft) throws
    func clearActiveDraft() throws
}

@MainActor
struct UserDefaultsSessionRepository: SessionRepository {
    private let userDefaults: UserDefaults
    private let key = "BillSplitz.activeDraft"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadActiveDraft() throws -> SplitDraft? {
        guard let payload = userDefaults.data(forKey: key) else {
            return nil
        }

        return try decoder.decode(SplitDraft.self, from: payload)
    }

    func saveActiveDraft(_ draft: SplitDraft) throws {
        var draftToStore = draft
        draftToStore.updatedAt = .now
        let payload = try encoder.encode(draftToStore)
        userDefaults.set(payload, forKey: key)
    }

    func clearActiveDraft() throws {
        userDefaults.removeObject(forKey: key)
    }
}

@MainActor
final class InMemorySessionRepository: SessionRepository {
    private(set) var savedDraft: SplitDraft?

    init(savedDraft: SplitDraft? = nil) {
        self.savedDraft = savedDraft
    }

    func loadActiveDraft() throws -> SplitDraft? {
        savedDraft
    }

    func saveActiveDraft(_ draft: SplitDraft) throws {
        savedDraft = draft
    }

    func clearActiveDraft() throws {
        savedDraft = nil
    }
}
