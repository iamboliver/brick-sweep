import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class StoreManager {

    enum ProductFetchState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    // MARK: - Public state

    private(set) var isPro: Bool = false
    private(set) var proProduct: Product?
    private(set) var isLoading: Bool = false
    private(set) var purchaseError: String?
    private(set) var purchaseMessage: String?
    private(set) var productFetchState: ProductFetchState = .idle

    // MARK: - Private state

    private var transactionListener: Task<Void, Never>?

    // MARK: - Init / deinit

    init() {
        transactionListener = listenForTransactions()
        Task {
            await fetchProductWithRetry()
            await refreshPurchaseStatus()
        }
    }

    // MARK: - Product fetch

    private func fetchProduct() async {
        productFetchState = .loading
        do {
            let products = try await Product.products(for: [AppConstants.IAP.proProductID])
            if let product = products.first {
                proProduct = product
                productFetchState = .loaded
            } else {
                productFetchState = .failed("BrickSweep Pro is temporarily unavailable. Please try again.")
            }
        } catch {
            productFetchState = .failed("Unable to load purchase options. Check your connection and try again.")
        }
    }

    private func fetchProductWithRetry() async {
        await fetchProduct()
        guard proProduct == nil else { return }

        for delay in [1_000_000_000, 2_000_000_000] {
            try? await Task.sleep(nanoseconds: UInt64(delay))
            await fetchProduct()
            if proProduct != nil { return }
        }
    }

    func retryProductFetch() async {
        purchaseError = nil
        purchaseMessage = nil
        await fetchProductWithRetry()
    }

    // MARK: - Purchase

    func purchase() async -> Bool {
        guard let product = proProduct else {
            purchaseError = "Product unavailable. Check your connection and try again."
            return false
        }
        isLoading = true
        purchaseError = nil
        purchaseMessage = nil
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
                purchaseMessage = "Purchase pending approval. You'll get access once Apple confirms it."
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
        purchaseMessage = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = "Could not contact the App Store to restore purchases. Please try again."
        }
        await refreshPurchaseStatus()
        purchaseMessage = isPro
            ? "Purchases restored."
            : "No previous BrickSweep Pro purchase was found for this Apple ID."
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
