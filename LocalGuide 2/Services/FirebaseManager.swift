import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseFunctions

final class FirebaseManager {
    static let shared = FirebaseManager()
    let db = Firestore.firestore()
    let storage = Storage.storage()
    let functions = Functions.functions(region: "europe-west1")

    private init() {}
}
