//
//  StoreManager.swift
//  Vole
//
//  Created by 杨权 on 12/7/25.
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published var products: [Product] = []

    private init() {}

    /// 加载商品列表
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [
                "yang.quan.vole.coin5",
                "yang.quan.vole.coin10",
                "yang.quan.vole.coin50",
            ])
            products = storeProducts
        } catch {
            print("❌ 加载商品失败:", error)
        }
    }

    /// 发起购买
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("✅ 购买成功: \(transaction.productID)")
                    await transaction.finish()
                    return true
                case .unverified(_, _):
                    print("❌ 交易未验证")
                    return false
                }
            case .userCancelled, .pending:
                print("用户取消或交易等待中")
                return false
            @unknown default:
                return false
            }
        } catch {
            print("❌ 购买失败:", error)
            return false
        }
    }
}
