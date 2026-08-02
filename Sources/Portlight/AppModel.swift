import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot = Snapshot()
    @Published var isRefreshing = false
    @Published var search = ""

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            let fresh = await Task.detached(priority: .userInitiated) {
                SystemScanner.scan()
            }.value
            snapshot = fresh
            isRefreshing = false
        }
    }
}
