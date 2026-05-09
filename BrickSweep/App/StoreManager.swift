import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class StoreManager {

    // MARK: - Public state

    private(set) var isPro: Bool = false
    private(set) var proProduct: Product?
    private(set) var isLoading: Bool = false
    private(set) var purchaseError: String?

    // MARK: - Private state

    private var transactionListener: Task<Void, Never>?

    // MARK: - Init / deinit

    init() {
        transactionListener = listenForTransactions()
        Task {
            await fetchProduct()
            await refreshPurchaseStatus()
        }
    }

    // MARK: - Product fetch

    private func fetchProduct() async {
        do {
            let products = try await Product.products(for: [AppConstants.IAP.proProductID])
            proProduct = products.first
        } catch {
            // Non-fatal: paywall shows a price placeholder
        }
    }

    // MARK: - Purchase

    func purchase() async -> Bool {
        guard let product = proProduct else {
            purchaseError = "Product unavailable. Check your connection and try again."
            return false
        }
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                if case .verified(let transaction) = verificationResult {
                    await transaction.finish()
                    isPro = true
                    return true
                }
                purchaseError = "Purchase could not be verified."
                return false
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        await refreshPurchaseStatus()
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await verificationResult in Transaction.updates {
                guard let self else { return }
                await self.handle(verificationResult: verificationResult)
            }
        }
    }

    // MARK: - Helpers

    private func refreshPurchaseStatus() async {
        var hasPro = false
        for await verificationResult in Transaction.currentEntitlements {
            if case .verified(let transaction) = verificationResult,
               transaction.productID == AppConstants.IAP.proProductID,
               transaction.revocationDate == nil
            {
                hasPro = true
                await transaction.finish()
            }
        }
        isPro = hasPro
    }

    @MainActor
    private func handle(verificationResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verificationResult else { return }
        if transaction.productID == AppConstants.IAP.proProductID {
            isPro = transaction.revocationDate == nil
            await transaction.finish()
        }
    }
}
