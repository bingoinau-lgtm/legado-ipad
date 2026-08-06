import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var host: String = ""
    @State private var portText: String = "1122"
    @State private var isTesting = false

    var body: some View {
        Form {
            Section {
                TextField("手机 IP，例如 192.168.1.8", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)

                TextField("端口", text: $portText)
                    .keyboardType(.numberPad)
            } header: {
                Text("Web 服务")
            } footer: {
                Text("在手机阅读 App 中开启 Web 服务（默认 HTTP 1122），确保 iPad 与手机在同一局域网。")
            }

            Section {
                Button {
                    Task { await saveAndTest() }
                } label: {
                    if isTesting {
                        ProgressView()
                    } else {
                        Text("保存并连接")
                    }
                }
                .disabled(isTesting || host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let message = appState.connectionMessage {
                Section("状态") {
                    Label(
                        message,
                        systemImage: appState.isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle"
                    )
                    .foregroundStyle(appState.isConnected ? .green : .primary)
                }
            }

            Section("使用说明") {
                Text("1. 手机打开「阅读」→ 启用 Web 服务 / 远程访问")
                Text("2. 记下手机局域网 IP")
                Text("3. 在此填写 IP，点击连接后即可同步书架")
            }
        }
        .navigationTitle("连接手机")
        .onAppear {
            host = appState.serverConfig.host
            portText = String(appState.serverConfig.port)
        }
    }

    private func saveAndTest() async {
        let port = Int(portText) ?? ServerConfig.defaultPort
        isTesting = true
        defer { isTesting = false }
        await appState.updateServer(host: host, port: port)
        await appState.testConnection()
    }
}
