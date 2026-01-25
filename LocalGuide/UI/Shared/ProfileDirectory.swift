import Foundation
import SwiftUI

@MainActor
final class ProfileDirectory: ObservableObject {
    @Published private(set) var guides: [String: GuideProfile] = [:]
    @Published private(set) var hosts: [String: HostProfile] = [:]
    @Published private(set) var users: [String: AppUser] = [:]

    func guide(_ email: String) -> GuideProfile? { guides[email] }
    func host(_ id: String) -> HostProfile? { hosts[id] }
    func user(_ id: String) -> AppUser? { users[id] }

    func loadGuideIfNeeded(_ email: String) async {
        print(guides)
        if guides[email] != nil { return }
        do {
            let g = try await FirestoreService.shared.getGuideProfile(guideEmail: email)
            print(g)
            guides[email] = g
            print(guides)
        } catch { }
    }

    func loadUserIfNeeded(_ id: String) async {
        if users[id] != nil { return }
        do {
            let u = try await FirestoreService.shared.getUser(uid: id)
            users[id] = u
        } catch { }
    }

    func loadHostIfNeeded(_ email: String) async {
        if hosts[email] != nil { return }
        do {
            let h = try await FirestoreService.shared.getHostProfile(hostEmail: email)
            hosts[email] = h
        } catch { }
    }
}
