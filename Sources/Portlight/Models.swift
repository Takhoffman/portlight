import Foundation
import SwiftUI

enum Section: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case ports = "Open Ports"
    case processes = "Running Apps"
    case ssh = "SSH Keys"
    case jobs = "Scheduled Jobs"
    case startup = "Startup Items"
    case pressure = "Storage & Pressure"
    case tools = "Developer Tools"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .ports: "network"
        case .processes: "shippingbox"
        case .ssh: "key.horizontal"
        case .jobs: "calendar.badge.clock"
        case .startup: "rocket"
        case .pressure: "gauge.with.dots.needle.67percent"
        case .tools: "hammer"
        }
    }
}

struct PortRecord: Identifiable, Sendable {
    let id = UUID()
    let process: String
    let pid: Int
    let user: String
    let protocolName: String
    let address: String
    let port: Int

    var isExposed: Bool {
        address == "*" || address == "0.0.0.0" || address == "::"
    }
}

struct ProcessRecord: Identifiable, Sendable {
    let id = UUID()
    let pid: Int
    let cpu: Double
    let memory: Double
    let command: String
    let fullCommand: String
}

struct SSHKeyRecord: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let fingerprint: String
    let kind: String
    let modified: Date?
}

struct JobRecord: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let source: String
    let status: String
    let detail: String
}

struct StartupRecord: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let location: String
    let scope: String
    let isApple: Bool
}

struct ToolRecord: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let version: String
    let path: String
    let icon: String
}

struct SystemHealth: Sendable {
    var computerName = "This Mac"
    var model = "Mac"
    var storageFree: Int64 = 0
    var storageTotal: Int64 = 0
    var memoryUsedPercent: Double = 0
    var uptime = "—"

    var storageFreePercent: Double {
        guard storageTotal > 0 else { return 0 }
        return Double(storageFree) / Double(storageTotal)
    }
}

struct Snapshot: Sendable {
    var ports: [PortRecord] = []
    var processes: [ProcessRecord] = []
    var sshKeys: [SSHKeyRecord] = []
    var jobs: [JobRecord] = []
    var startupItems: [StartupRecord] = []
    var tools: [ToolRecord] = []
    var health = SystemHealth()
    var scannedAt = Date()
}
