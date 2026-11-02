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

    var isPro: Bool { hasPurchasedPro || isFoundingUser }
    private(set) var hasPurchasedPro = false
    private(set) var hasCheckedFoundingStatus = false
    private var verifiedFoundingUser: Bool
    var isFoundingUser: Bool {
        #if DEBUG
        if let foundingUserOverride { return foundingUserOverride }
        #endif
        return verifiedFoundingUser
    }

    #if DEBUG
    /// Session-only simulation; never writes the verified cache.
    var foundingUserOverride: Bool?
    #endif
    private(set) var proProduct: Product?
    private(set) var isLoading: Bool = false
    private(set) var purchaseError: String?
    private(set) var purchaseMessage: String?
    private(set) var productFetchState: ProductFetchState = .idle

    // MARK: - Private state

    private var transactionListener: Task<Void, Never>?
    private var purchaseRefreshTask: Task<Void, Never>?

    // MARK: - Init / deinit

    private let appTransactionProvider: @MainActor () async throws -> AppInstallRecord
    private let purchasedProProvider: @MainActor () async -> Bool
    private let defaults: UserDefaults

    init(
        defaults: UserDefaults = .standard,
        appTransactionProvider: @escaping @MainActor () async throws -> AppInstallRecord = StoreManager.appInstallRecord,
        purchasedProProvider: @escaping @MainActor () async -> Bool = StoreManager.purchasedPro,
        startsAutomatically: Bool = true
    ) {
        self.defaults = defaults
        self.appTransactionProvider = appTransactionProvider
        self.purchasedProProvider = purchasedProProvider
        verifiedFoundingUser = defaults.bool(forKey: AppConstants.UserDefaultsKeys.verifiedFoundingUser)
        #if DEBUG
        switch ProcessInfo.processInfo.environment["BRICKSWEEP_FOUNDING_USER"] {
        case "1": foundingUserOverride = true
        case "0": foundingUserOverride = false
        default: break
        }
        #endif
        guard startsAutomatically else { return }
        transactionListener = listenForTransactions()
        Task {
            await refreshPurchaseStatus()
        }
        Task {
            await fetchProductWithRetry()
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
                    hasPurchasedPro = true
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

    func refreshPurchaseStatus() async {
        if let purchaseRefreshTask {
            await purchaseRefreshTask.value
            return
        }
        let task = Task { @MainActor in
            async let foundingCheck: Void = refreshFoundingStatus()
            hasPurchasedPro = await purchasedProProvider()
            await foundingCheck
        }
        purchaseRefreshTask = task
        await task.value
        purchaseRefreshTask = nil
    }

    func refreshFoundingStatus() async {
        do {
            let record = try await appTransactionProvider()
            // An explicit verification failure cannot confer founder access.
            if case .verified(let originalAppVersion) = record,
               let build = Int(originalAppVersion) {
                verifiedFoundingUser = build <= AppConstants.lastFoundingBuild
            } else {
                verifiedFoundingUser = false
            }
            defaults.set(verifiedFoundingUser, forKey: AppConstants.UserDefaultsKeys.verifiedFoundingUser)
            hasCheckedFoundingStatus = true
        } catch {
            // Keep the last verified result when StoreKit is unavailable/offline.
            hasCheckedFoundingStatus = defaults.object(forKey: AppConstants.UserDefaultsKeys.verifiedFoundingUser) != nil
        }
    }

    static func appInstallRecord() async throws -> AppInstallRecord {
        switch try await AppTransaction.shared {
        case .verified(let transaction):
            return .verified(originalAppVersion: transaction.originalAppVersion)
        case .unverified:
            return .unverified
        }
    }

    static func purchasedPro() async -> Bool {
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
        return hasPro
    }

    @MainActor
    private func handle(verificationResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verificationResult else { return }
        if transaction.productID == AppConstants.IAP.proProductID {
            hasPurchasedPro = transaction.revocationDate == nil
            await transaction.finish()
        }
    }
}

/// Only the StoreKit adapter creates a verified record in production.
enum AppInstallRecord: Equatable {
    case verified(originalAppVersion: String)
    case unverified
}
