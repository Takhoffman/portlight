import Foundation

enum SystemScanner {
    static func scan() -> Snapshot {
        Snapshot(
            ports: scanPorts(),
            processes: scanProcesses(),
            sshKeys: scanSSHKeys(),
            jobs: scanJobs(),
            startupItems: scanStartupItems(),
            tools: scanTools(),
            health: scanHealth(),
            scannedAt: Date()
        )
    }

    private static func run(_ executable: String, _ arguments: [String]) -> String {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private static func scanPorts() -> [PortRecord] {
        let text = run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcuPn"])
        var results: [PortRecord] = []
        var process = "Unknown"
        var pid = 0
        var user = ""
        var protocolName = "TCP"

        for line in text.split(separator: "\n").map(String.init) {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p": pid = Int(value) ?? 0
            case "c": process = value
            case "u": user = value
            case "P": protocolName = value
            case "n":
                guard let parsed = parseEndpoint(value) else { continue }
                results.append(PortRecord(process: process, pid: pid, user: user, protocolName: protocolName, address: parsed.address, port: parsed.port))
            default: break
            }
        }

        return results
            .reduce(into: [String: PortRecord]()) { items, item in
                items["\(item.pid):\(item.port):\(item.address)"] = item
            }
            .values
            .sorted { $0.port < $1.port }
    }

    private static func parseEndpoint(_ value: String) -> (address: String, port: Int)? {
        let cleaned = value.replacingOccurrences(of: " (LISTEN)", with: "")
        guard let colon = cleaned.lastIndex(of: ":"),
              let port = Int(cleaned[cleaned.index(after: colon)...]) else { return nil }
        var address = String(cleaned[..<colon])
        if address.hasPrefix("[") && address.hasSuffix("]") {
            address = String(address.dropFirst().dropLast())
        }
        return (address, port)
    }

    private static func scanProcesses() -> [ProcessRecord] {
        let text = run("/bin/ps", ["-axo", "pid=,%cpu=,%mem=,comm=,args="])
        return text.split(separator: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            let pieces = line.split(maxSplits: 4, whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard pieces.count == 5,
                  let pid = Int(pieces[0]),
                  let cpu = Double(pieces[1]),
                  let memory = Double(pieces[2]) else { return nil }
            let executable = pieces[4].split(separator: " ").first.map(String.init) ?? pieces[3]
            return ProcessRecord(pid: pid, cpu: cpu, memory: memory, command: URL(fileURLWithPath: executable).lastPathComponent, fullCommand: pieces[4])
        }
        .sorted { $0.cpu > $1.cpu }
    }

    private static func scanSSHKeys() -> [SSHKeyRecord] {
        let ssh = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        guard let files = try? FileManager.default.contentsOfDirectory(at: ssh, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return [] }

        return files
            .filter { $0.pathExtension == "pub" }
            .map { url in
                let fingerprintOutput = run("/usr/bin/ssh-keygen", ["-lf", url.path]).trimmingCharacters(in: .whitespacesAndNewlines)
                let parts = fingerprintOutput.split(separator: " ").map(String.init)
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                return SSHKeyRecord(
                    name: url.deletingPathExtension().lastPathComponent,
                    path: url.path,
                    fingerprint: parts.count > 1 ? parts[1] : "Fingerprint unavailable",
                    kind: parts.last?.trimmingCharacters(in: CharacterSet(charactersIn: "()")) ?? "Unknown",
                    modified: values?.contentModificationDate
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func scanJobs() -> [JobRecord] {
        var jobs: [JobRecord] = []
        let launchctl = run("/bin/launchctl", ["list"])
        for line in launchctl.split(separator: "\n").dropFirst() {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 3 else { continue }
            let pid = columns[0] == "-" ? "Not running" : "Running · PID \(columns[0])"
            let code = columns[1] == "0" || columns[1] == "-" ? "Healthy" : "Exit code \(columns[1])"
            jobs.append(JobRecord(label: columns[2], source: "LaunchAgent", status: pid, detail: code))
        }

        let cron = run("/usr/bin/crontab", ["-l"])
        for (index, line) in cron.split(separator: "\n").map(String.init).filter({ !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }).enumerated() {
            jobs.append(JobRecord(label: "Cron job \(index + 1)", source: "crontab", status: "Scheduled", detail: line))
        }
        return jobs.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private static func scanStartupItems() -> [StartupRecord] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let locations: [(String, String)] = [
            (home + "/Library/LaunchAgents", "Your account"),
            ("/Library/LaunchAgents", "All users"),
            ("/Library/LaunchDaemons", "System"),
            ("/System/Library/LaunchAgents", "macOS"),
            ("/System/Library/LaunchDaemons", "macOS")
        ]
        var records: [StartupRecord] = []
        for (directory, scope) in locations {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory) else { continue }
            for file in files where file.hasSuffix(".plist") {
                let path = directory + "/" + file
                let data = NSDictionary(contentsOfFile: path)
                let label = data?["Label"] as? String ?? String(file.dropLast(6))
                records.append(StartupRecord(label: label, location: path, scope: scope, isApple: label.hasPrefix("com.apple.")))
            }
        }
        return records.sorted { lhs, rhs in
            if lhs.isApple != rhs.isApple { return !lhs.isApple }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }

    private static func scanTools() -> [ToolRecord] {
        let candidates: [(String, String, [String], String)] = [
            ("Git", "/usr/bin/git", ["--version"], "arrow.triangle.branch"),
            ("Swift", "/usr/bin/swift", ["--version"], "swift"),
            ("Xcode", "/usr/bin/xcodebuild", ["-version"], "hammer.fill"),
            ("Homebrew", "/opt/homebrew/bin/brew", ["--version"], "mug.fill"),
            ("Node.js", "/opt/homebrew/bin/node", ["--version"], "hexagon.fill"),
            ("Python", "/usr/bin/python3", ["--version"], "chevron.left.forwardslash.chevron.right"),
            ("Docker", "/usr/local/bin/docker", ["--version"], "shippingbox.fill")
        ]
        return candidates.compactMap { name, path, arguments, icon in
            guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
            let version = run(path, arguments).split(separator: "\n").first.map(String.init) ?? "Installed"
            return ToolRecord(name: name, version: version, path: path, icon: icon)
        }
    }

    private static func scanHealth() -> SystemHealth {
        var health = SystemHealth()
        health.computerName = Host.current().localizedName ?? "This Mac"
        health.model = run("/usr/sbin/sysctl", ["-n", "hw.model"]).trimmingCharacters(in: .whitespacesAndNewlines)

        if let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]) {
            health.storageFree = values.volumeAvailableCapacityForImportantUsage ?? 0
            health.storageTotal = Int64(values.volumeTotalCapacity ?? 0)
        }

        let totalMemory = Double(run("/usr/sbin/sysctl", ["-n", "hw.memsize"]).trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let vm = run("/usr/bin/vm_stat", [])
        let pageSize = Double(vm.split(separator: "\n").first?.split(separator: " ").dropLast().last ?? "4096") ?? 4096
        func pages(_ label: String) -> Double {
            guard let line = vm.split(separator: "\n").first(where: { $0.hasPrefix(label) }),
                  let value = line.split(separator: ":").last else { return 0 }
            return Double(value.trimmingCharacters(in: CharacterSet(charactersIn: " ."))) ?? 0
        }
        let free = (pages("Pages free") + pages("Pages speculative")) * pageSize
        health.memoryUsedPercent = totalMemory > 0 ? max(0, min(1, 1 - free / totalMemory)) : 0

        let seconds = Double(run("/usr/bin/uptime", []).split(separator: " ").first ?? "0")
        let boot = run("/usr/sbin/sysctl", ["-n", "kern.boottime"])
        if let range = boot.range(of: "sec = "), let comma = boot[range.upperBound...].firstIndex(of: ","), let epoch = Double(boot[range.upperBound..<comma]) {
            let interval = Date().timeIntervalSince1970 - epoch
            let days = Int(interval / 86400)
            let hours = Int(interval.truncatingRemainder(dividingBy: 86400) / 3600)
            health.uptime = days > 0 ? "\(days)d \(hours)h" : "\(hours)h"
        } else if let seconds { health.uptime = "\(Int(seconds))s" }
        return health
    }
}
