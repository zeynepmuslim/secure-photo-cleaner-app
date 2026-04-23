//
//  TipJarManager.swift
//  Purgio
//
//  Created by ZeynepMüslim on 18.04.2026.
//

import Foundation
import StoreKit

@MainActor
final class TipJarManager: ObservableObject {

    static let shared = TipJarManager()

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case success
        case failed(String)
    }

    enum StoreError: LocalizedError {
        case verificationFailed

        var errorDescription: String? {
            "Transaction verification failed."
        }
    }

    private let productIDs: [String] = [
        "com.zeynepmuslim.purgio.tip.small",
        "com.zeynepmuslim.purgio.tip.medium",
        "com.zeynepmuslim.purgio.tip.large"
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactions()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                purchaseState = .success
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func resetPurchaseState() {
        purchaseState = .idle
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                await self.handleTransactionUpdate(result)
            }
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)

            if let revocationDate = transaction.revocationDate {
                print("[TipJar] Transaction refunded — productID: \(transaction.productID), date: \(revocationDate), reason: \(String(describing: transaction.revocationReason))")
                // NotificationCenter.default.post(
                //     name: .tipJarTransactionRefunded,
                //     object: nil,
                //     userInfo: [
                //         "productID": transaction.productID,
                //         "revocationDate": revocationDate
                //     ]
                // )
            } else {
                print("[TipJar] Background transaction update — productID: \(transaction.productID)")
                // NotificationCenter.default.post(
                //     name: .tipJarTransactionCompleted,
                //     object: nil,
                //     userInfo: ["productID": transaction.productID]
                // )
            }

            await transaction.finish()
        } catch {
            print("[TipJar] Failed to verify background transaction update: \(error.localizedDescription)")
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// extension Notification.Name {
//     static let tipJarTransactionRefunded = Notification.Name("tipJarTransactionRefunded")
//     static let tipJarTransactionCompleted = Notification.Name("tipJarTransactionCompleted")
// }
