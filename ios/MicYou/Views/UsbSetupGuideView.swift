import SwiftUI

/// USB 模式设置指引。对齐 `docs/ios/02-connection-modes.md` §3。
///
/// 当用户选择 USB 模式时展示 iproxy 设置步骤。iOS 无 adb reverse，
/// 需 Mac 端运行 `iproxy`（libimobiledevice）转发端口。
struct UsbSetupGuideView: View {
    var port: Int = WireConstants.defaultTcpPort

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                step1
                step2
                step3
                step4
                alternative
            }
            .padding()
        }
        .navigationTitle("USB 设置指引")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("USB 模式使用 iproxy 转发", systemImage: "cable.connector")
                .font(.headline)
            Text("iOS 无 adb reverse，需在 Mac 端运行 iproxy（libimobiledevice）把 Mac 端口转发到 iPhone。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var step1: some View {
        stepView(number: 1, title: "安装 libimobiledevice") {
            codeBlock("brew install libimobiledevice")
        }
    }

    private var step2: some View {
        stepView(number: 2, title: "用 USB 线连接 iPhone") {
            Text("将 iPhone 用数据线连接到 Mac，首次连接时 iPhone 会提示「信任此电脑」，点击信任。")
                .font(.subheadline)
        }
    }

    private var step3: some View {
        stepView(number: 3, title: "启动 iproxy 转发") {
            VStack(alignment: .leading, spacing: 8) {
                codeBlock("iproxy \(port) \(port) &")
                Text("若使用 TCP+UDP 模式，还需转发 UDP 端口：")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                codeBlock("iproxy \(port + 1) \(port + 1) &")
            }
        }
    }

    private var step4: some View {
        stepView(number: 4, title: "在 app 中开始") {
            Text("选择 USB 模式，端口 \(port)，点击开始即可。iPhone 连接 127.0.0.1:\(port)，经 iproxy 转发到 Mac。")
                .font(.subheadline)
        }
    }

    private var alternative: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Label("备选：USB 个人热点", systemImage: "wifi")
                .font(.headline)
            Text("若不想安装 iproxy，可开启 iPhone 个人热点，Mac 连接后用 Wi-Fi 模式填 Mac 的热点 IP（通常 172.20.10.1）。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("注意：此方式本质走 tethered 路由，非真 USB 转发，延迟略高。推荐使用 iproxy。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 辅助
    private func stepView<C: View>(number: Int, title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.tint, in: Circle())
                Text(title).font(.headline)
            }
            content()
                .padding(.leading, 32)
        }
    }

    private func codeBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
