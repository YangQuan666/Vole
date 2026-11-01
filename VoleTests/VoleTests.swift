//
//  VoleTests.swift
//  VoleTests
//
//  Created by 杨权 on 5/26/25.
//

import Foundation
import Testing
@testable import Vole

struct VoleTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func notificationReadStateIsIsolatedByAccount() {
        let (defaults, suiteName) = makeTestDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = NotificationReadStateStore(defaults: defaults)
        let state = NotificationReadState(
            readIds: [12, 18],
            lastReadAllId: 20,
            allReadTotalCount: 35
        )

        store.save(state, for: "id-account-a")

        #expect(store.load(for: "id-account-a") == state)
        #expect(store.load(for: "id-account-b") == NotificationReadState())
    }

    @Test func migratesLegacyNotificationReadStateToFirstAccountOnly() {
        let (defaults, suiteName) = makeTestDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set([4, 9], forKey: "read_notification_ids")
        defaults.set(10, forKey: "last_read_all_id")
        defaults.set(25, forKey: "all_read_total_count")
        let store = NotificationReadStateStore(defaults: defaults)

        let migrated = store.load(for: "id-account-a")

        #expect(
            migrated == NotificationReadState(
                readIds: [4, 9],
                lastReadAllId: 10,
                allReadTotalCount: 25
            )
        )
        #expect(store.load(for: "id-account-b") == NotificationReadState())
        #expect(defaults.object(forKey: "read_notification_ids") == nil)
    }

    private func makeTestDefaults() -> (UserDefaults, String) {
        let suiteName = "VoleTests.NotificationReadState.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

}
