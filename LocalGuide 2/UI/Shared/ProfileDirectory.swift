import Foundation
import SwiftUI

@MainActor
final class ProfileDirectory: ObservableObject {
    @Published private(set) var guides: [String: GuideProfile] = [:]
    @Published private(set) var hosts: [String: HostProfile] = [:]
    @Published private(set) var users: [String: AppUser] = [:]

    func guide(_ id: String) -> GuideProfile? { guides[id] }
    func host(_ id: String) -> HostProfile? { hosts[id] }
    func user(_ id: String) -> AppUser? { users[id] }

    func loadGuideIfNeeded(_ id: String) async {
        if guides[id] != nil { return }
        do {
            let g = try await FirestoreService.shared.getGuideProfile(guideId: id)
            guides[id] = g
        } catch { }
    }

    func loadUserIfNeeded(_ id: String) async {
        if users[id] != nil { return }
        do {
            let u = try await FirestoreService.shared.getUser(uid: id)
            users[id] = u
        } catch { }
    }

    func loadHostIfNeeded(_ id: String) async {
        if hosts[id] != nil { return }
        do {
            let h = try await FirestoreService.shared.getHostProfile(hostId: id)
            hosts[id] = h
        } catch { }
    }
}
