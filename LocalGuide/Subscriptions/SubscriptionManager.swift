import Foundation
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var isPremium: Bool = false
    @Published var lastError: String?

    func loadProducts() async {
        do {
            products = try await Product.products(for: Array(AppConfig.subscriptionProductIds))
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var premium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if AppConfig.subscriptionProductIds.contains(transaction.productID) {
                    premium = true
                }
            }
        }
        isPremium = premium
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(_) = verification {
                    await refreshEntitlements()
                }
            default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
