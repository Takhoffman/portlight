import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private var exposed: Int { model.snapshot.ports.filter(\.isExposed).count }
    private var storage: Double { model.snapshot.health.storageFreePercent }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "light.beacon.max.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 38, height: 38)
                    .background(.blue.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Portlight").font(.headline)
                    Text(model.isRefreshing ? "Checking your Mac…" : "Your Mac, at a glance").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.refresh() } label: {
                    if model.isRefreshing { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            .padding(16)

            Divider()

            VStack(spacing: 0) {
                MenuStatusRow(icon: exposed == 0 ? "checkmark.shield.fill" : "network.badge.shield.half.filled", color: exposed == 0 ? .green : .orange, title: exposed == 0 ? "Network looks calm" : "\(exposed) network-facing ports", detail: exposed == 0 ? "Nothing needs your attention" : "Open Portlight to see which apps")
                Divider().padding(.leading, 48)
                MenuStatusRow(icon: "internaldrive.fill", color: storage > 0.2 ? .green : .orange, title: "\(Int(storage * 100))% storage available", detail: ByteCountFormatter.string(fromByteCount: model.snapshot.health.storageFree, countStyle: .file) + " free")
                Divider().padding(.leading, 48)
                MenuStatusRow(icon: "waveform.path.ecg", color: .blue, title: "\(model.snapshot.processes.count) processes", detail: "Apps and background helpers")
            }
            .padding(.horizontal, 12)

            Divider().padding(.top, 4)

            HStack {
                Label("Read-only", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Open Portlight") {
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(width: 350)
        .background(.regularMaterial)
        .task { if model.snapshot.processes.isEmpty { model.refresh() } }
    }
}

struct MenuStatusRow: View {
    let icon: String; let color: Color; let title: String; let detail: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 11)
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: Section = .overview

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
                    .padding(.vertical, 4)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    Label("Read-only mode", systemImage: "lock.shield")
                        .font(.caption.weight(.medium))
                    Text("Portlight only looks. It never changes your Mac.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
        } detail: {
            Group {
                switch selection {
                case .overview: OverviewView()
                case .ports: PortsView()
                case .processes: ProcessesView()
                case .ssh: SSHKeysView()
                case .jobs: JobsView()
                case .startup: StartupItemsView()
                case .pressure: PressureView()
                case .tools: DeveloperToolsView()
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    TextField("Search", text: $model.search)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 210)
                    Button { model.refresh() } label: {
                        if model.isRefreshing { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                    .help("Refresh everything (⌘R)")
                    .disabled(model.isRefreshing)
                }
            }
        }
        .onAppear { selection = .overview }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    var icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 48, height: 48)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title2.bold())
                Text(subtitle).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct OverviewView: View {
    @EnvironmentObject private var model: AppModel
    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your Mac, at a glance").font(.largeTitle.bold())
                        Text("A calm map of the technical things happening behind the scenes.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    HealthBadge(exposed: model.snapshot.ports.filter(\.isExposed).count)
                }

                HStack(alignment: .top, spacing: 26) {
                    BackstageMap(snapshot: model.snapshot)
                        .frame(width: 330)
                    VStack(spacing: 18) {
                        TodayPanel(snapshot: model.snapshot)
                        LazyVGrid(columns: columns, spacing: 12) {
                            StatCard(title: "Listening ports", value: "\(model.snapshot.ports.count)", note: "Apps accepting connections", icon: "network", color: .blue)
                            StatCard(title: "Running processes", value: "\(model.snapshot.processes.count)", note: "Apps and background helpers", icon: "waveform.path.ecg", color: .purple)
                            StatCard(title: "SSH identities", value: "\(model.snapshot.sshKeys.count)", note: "Public keys only", icon: "key.horizontal", color: .green)
                            StatCard(title: "Scheduled jobs", value: "\(model.snapshot.jobs.count)", note: "Launch agents and cron", icon: "calendar.badge.clock", color: .orange)
                        }
                    }
                }

                GroupBox {
                    VStack(spacing: 0) {
                        InsightRow(icon: "shield.lefthalf.filled", color: .green, title: "Private SSH keys stay private", detail: "Portlight reads public .pub files and fingerprints only.")
                        Divider().padding(.leading, 44)
                        InsightRow(icon: "eye", color: .blue, title: "Nothing is changed", detail: "This version is intentionally read-only while you learn what everything means.")
                        Divider().padding(.leading, 44)
                        InsightRow(icon: "arrow.clockwise", color: .purple, title: "Live snapshot", detail: "Last checked \(model.snapshot.scannedAt.formatted(date: .omitted, time: .standard)).")
                    }
                } label: { Text("Good to know").font(.headline) }
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct BackstageMap: View {
    let snapshot: Snapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Mac backstage map").font(.headline).padding(.bottom, 14)
            MapNode(icon: "laptopcomputer", color: .blue, title: "This Mac", detail: snapshot.health.computerName)
            MapLine()
            MapNode(icon: "network", color: .blue, title: "Network", detail: "\(snapshot.ports.count) listening ports")
            MapLine()
            MapNode(icon: "gearshape.2", color: .purple, title: "Background Work", detail: "\(snapshot.processes.count) processes")
            MapLine()
            MapNode(icon: "key.horizontal", color: .green, title: "Identity", detail: "\(snapshot.sshKeys.count) SSH identities")
            MapLine()
            MapNode(icon: "internaldrive", color: .orange, title: "Storage", detail: ByteCountFormatter.string(fromByteCount: snapshot.health.storageFree, countStyle: .file) + " free")
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.separator.opacity(0.45)))
    }
}

struct MapNode: View {
    let icon: String; let color: Color; let title: String; let detail: String
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.title3.weight(.medium)).foregroundStyle(color).frame(width: 42, height: 42).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.callout.weight(.semibold)); Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
        }
    }
}

struct MapLine: View {
    var body: some View { Rectangle().fill(.blue.opacity(0.28)).frame(width: 2, height: 19).padding(.leading, 20) }
}

struct TodayPanel: View {
    let snapshot: Snapshot
    private var exposed: Int { snapshot.ports.filter(\.isExposed).count }
    var body: some View {
        GroupBox {
            VStack(spacing: 0) {
                InsightRow(icon: "globe", color: .blue, title: "\(exposed) apps can receive network traffic", detail: exposed == 0 ? "Nothing is listening beyond this Mac." : "Review the highlighted ports if that surprises you.")
                Divider().padding(.leading, 44)
                InsightRow(icon: "internaldrive", color: .green, title: snapshot.health.storageFreePercent > 0.2 ? "Storage has plenty of breathing room" : "Storage is getting tight", detail: "\(Int(snapshot.health.storageFreePercent * 100))% of your disk is available.")
                Divider().padding(.leading, 44)
                InsightRow(icon: "checkmark.circle", color: .green, title: "No unusual background activity", detail: "The busiest processes are shown in Running Apps.")
            }
        } label: { Text("Today").font(.headline) }
    }
}

struct HealthBadge: View {
    let exposed: Int
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: exposed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text(exposed == 0 ? "Looks calm" : "\(exposed) network-facing")
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(exposed == 0 ? .green : .orange)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background((exposed == 0 ? Color.green : Color.orange).opacity(0.1), in: Capsule())
    }
}

struct StatCard: View {
    let title: String; let value: String; let note: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon).foregroundStyle(color).font(.title2)
                Spacer()
                Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.separator.opacity(0.45)))
    }
}

struct InsightRow: View {
    let icon: String; let color: Color; let title: String; let detail: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding(.vertical, 11)
    }
}

struct PortsView: View {
    @EnvironmentObject private var model: AppModel
    var rows: [PortRecord] { model.snapshot.ports.filter { model.search.isEmpty || "\($0.process) \($0.port) \($0.address)".localizedCaseInsensitiveContains(model.search) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Open Ports", subtitle: "Doorways where apps are listening for network connections.", icon: "network")
            Table(rows) {
                TableColumn("App") { row in Label(row.process, systemImage: "app.dashed").fontWeight(.medium) }
                TableColumn("Port") { row in Text("\(row.port)").font(.system(.body, design: .monospaced)) }.width(70)
                TableColumn("Reach") { row in
                    Text(row.isExposed ? "Network" : "This Mac")
                        .foregroundStyle(row.isExposed ? .orange : .green)
                }.width(90)
                TableColumn("Address") { row in Text(row.address).foregroundStyle(.secondary) }
                TableColumn("PID") { row in Text("\(row.pid)").foregroundStyle(.secondary) }.width(65)
            }
        }.padding(24)
    }
}

struct ProcessesView: View {
    @EnvironmentObject private var model: AppModel
    var rows: [ProcessRecord] { model.snapshot.processes.filter { model.search.isEmpty || "\($0.command) \($0.fullCommand)".localizedCaseInsensitiveContains(model.search) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Running Apps", subtitle: "Visible apps, helpers, and system processes using your Mac.", icon: "shippingbox")
            Table(rows) {
                TableColumn("Process") { row in VStack(alignment: .leading) { Text(row.command).fontWeight(.medium); Text(row.fullCommand).font(.caption).foregroundStyle(.secondary).lineLimit(1) } }
                TableColumn("CPU") { row in Text(row.cpu, format: .number.precision(.fractionLength(1))).monospacedDigit() }.width(65)
                TableColumn("Memory") { row in Text("\(row.memory.formatted(.number.precision(.fractionLength(1))))% ").monospacedDigit() }.width(80)
                TableColumn("PID") { row in Text("\(row.pid)").foregroundStyle(.secondary) }.width(65)
            }
        }.padding(24)
    }
}

struct SSHKeysView: View {
    @EnvironmentObject private var model: AppModel
    var rows: [SSHKeyRecord] { model.snapshot.sshKeys.filter { model.search.isEmpty || "\($0.name) \($0.kind) \($0.fingerprint)".localizedCaseInsensitiveContains(model.search) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "SSH Keys", subtitle: "The public identities your Mac uses to prove who it is.", icon: "key.horizontal")
            if rows.isEmpty {
                ContentUnavailableView("No public SSH keys found", systemImage: "key.slash", description: Text("Portlight looks for .pub files in ~/.ssh."))
            } else {
                List(rows) { key in
                    HStack(spacing: 14) {
                        Image(systemName: "key.fill").foregroundStyle(.orange).frame(width: 32, height: 32).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(key.name).fontWeight(.semibold); Text(key.kind).font(.caption).padding(.horizontal, 7).padding(.vertical, 2).background(.quaternary, in: Capsule()) }
                            Text(key.fingerprint).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                            Text(key.path).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        }
                        Spacer()
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: key.path)]) }
                    }.padding(.vertical, 6)
                }
            }
        }.padding(24)
    }
}

struct JobsView: View {
    @EnvironmentObject private var model: AppModel
    var rows: [JobRecord] { model.snapshot.jobs.filter { model.search.isEmpty || "\($0.label) \($0.source) \($0.detail)".localizedCaseInsensitiveContains(model.search) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Scheduled Jobs", subtitle: "Background chores macOS and your apps run automatically.", icon: "calendar.badge.clock")
            Table(rows) {
                TableColumn("Job") { row in Text(row.label).fontWeight(.medium) }
                TableColumn("Type") { row in Text(row.source).foregroundStyle(.secondary) }.width(100)
                TableColumn("Status") { row in Text(row.status).foregroundStyle(row.status.hasPrefix("Running") ? .green : .secondary) }.width(130)
                TableColumn("Last result") { row in Text(row.detail).foregroundStyle(row.detail == "Healthy" ? .green : .secondary).lineLimit(1) }
            }
        }.padding(24)
    }
}

struct StartupItemsView: View {
    @EnvironmentObject private var model: AppModel
    var rows: [StartupRecord] { model.snapshot.startupItems.filter { model.search.isEmpty || "\($0.label) \($0.scope)".localizedCaseInsensitiveContains(model.search) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Startup Items", subtitle: "Helpers that can wake up when you sign in or when your Mac starts.", icon: "rocket")
            HStack { Label("Third-party first", systemImage: "sparkles"); Text("macOS components are kept lower in the list.").foregroundStyle(.secondary) }.font(.caption)
            Table(rows) {
                TableColumn("Item") { row in Label(row.label, systemImage: row.isApple ? "apple.logo" : "puzzlepiece.extension").fontWeight(.medium) }
                TableColumn("Who it affects") { row in Text(row.scope).foregroundStyle(.secondary) }.width(110)
                TableColumn("Kind") { row in Text(row.isApple ? "macOS" : "Third-party").foregroundStyle(row.isApple ? Color.secondary : Color.blue) }.width(100)
                TableColumn("File") { row in Text(row.location).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
        }.padding(24)
    }
}

struct PressureView: View {
    @EnvironmentObject private var model: AppModel
    var health: SystemHealth { model.snapshot.health }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Storage & Pressure", subtitle: "How much breathing room your Mac has right now.", icon: "gauge.with.dots.needle.67percent")
                HStack(spacing: 16) {
                    GaugeCard(title: "Storage available", value: health.storageFreePercent, detail: ByteCountFormatter.string(fromByteCount: health.storageFree, countStyle: .file) + " free", color: health.storageFreePercent > 0.2 ? .green : .orange, icon: "internaldrive")
                    GaugeCard(title: "Memory in use", value: health.memoryUsedPercent, detail: "Active and cached memory", color: health.memoryUsedPercent < 0.85 ? .blue : .orange, icon: "memorychip")
                }
                GroupBox("This Mac") {
                    LabeledContent("Computer", value: health.computerName)
                    Divider()
                    LabeledContent("Model", value: health.model)
                    Divider()
                    LabeledContent("Time since restart", value: health.uptime)
                }
                Text("Memory use can look high even when everything is healthy—macOS uses spare memory to make apps faster.").font(.callout).foregroundStyle(.secondary)
            }.padding(24)
        }
    }
}

struct GaugeCard: View {
    let title: String; let value: Double; let detail: String; let color: Color; let icon: String
    var body: some View {
        HStack(spacing: 20) {
            Gauge(value: value) { Image(systemName: icon) }.gaugeStyle(.accessoryCircularCapacity).tint(color).scaleEffect(1.25).frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(value, format: .percent.precision(.fractionLength(0))).font(.system(size: 28, weight: .bold, design: .rounded)); Text(detail).font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }.padding(20).frame(maxWidth: .infinity).background(.background, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.separator.opacity(0.45)))
    }
}

struct DeveloperToolsView: View {
    @EnvironmentObject private var model: AppModel
    var rows: [ToolRecord] { model.snapshot.tools.filter { model.search.isEmpty || "\($0.name) \($0.version)".localizedCaseInsensitiveContains(model.search) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Developer Tools", subtitle: "The building blocks installed for coding and local services.", icon: "hammer")
            if rows.isEmpty { ContentUnavailableView("No common developer tools found", systemImage: "hammer") }
            else {
                List(rows) { tool in
                    HStack(spacing: 14) {
                        Image(systemName: tool.icon).foregroundStyle(.blue).frame(width: 36, height: 36).background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 3) { Text(tool.name).fontWeight(.semibold); Text(tool.version).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                        Spacer(); Text(tool.path).font(.caption2).foregroundStyle(.tertiary).lineLimit(1).frame(maxWidth: 280, alignment: .trailing)
                    }.padding(.vertical, 5)
                }
            }
        }.padding(24)
    }
}
