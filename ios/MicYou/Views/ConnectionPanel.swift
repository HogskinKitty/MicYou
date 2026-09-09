import SwiftUI

/// 连接面板：模式选择 + 主机/端口 + 传输协议 + 音频设置。
/// 对齐 Android `MobileHome` 连接区。
struct ConnectionPanel: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            modePicker
            modeFields
            if settings.connectionMode != .web {
                transportPicker
            }
            audioSettings
        }
    }

    // MARK: - 模式选择
    private var modePicker: some View {
        Picker("连接模式", selection: $settings.connectionMode) {
            ForEach(ConnectionMode.allCases, id: \.self) { mode in
                Label(mode.label, systemImage: mode.icon).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 模式相关字段
    @ViewBuilder
    private var modeFields: some View {
        switch settings.connectionMode {
        case .wifi: wifiFields
        case .usb: usbFields
        case .web: webFields
        }
    }

    private var wifiFields: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                labeledField("IP 地址", text: $settings.host, placeholder: "192.168.1.100")
                labeledField("端口", value: $settings.port, range: 1...65535)
            }
        }
    }

    private var usbFields: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                labeledField("目标", text: .constant("127.0.0.1"), placeholder: "")
                    .disabled(true)
                labeledField("端口", value: $settings.port, range: 1...65535)
            }
            NavigationLink {
                UsbSetupGuideView(port: settings.port)
            } label: {
                Label("USB 设置指引", systemImage: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
            }
        }
    }

    private var webFields: some View {
        VStack(spacing: 12) {
            labeledField("主机", text: $settings.webHost, placeholder: "example.com")
            HStack(spacing: 12) {
                labeledField("Web 端口", value: $settings.webPort, range: 1...65535)
                Spacer()
                Label("wss://", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 传输协议
    private var transportPicker: some View {
        Picker("传输协议", selection: $settings.transportProtocol) {
            ForEach(TransportProtocol.allCases, id: \.self) { proto in
                Text(proto.label).tag(proto)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 音频设置
    private var audioSettings: some View {
        VStack(spacing: 12) {
            Picker("采样率", selection: $settings.sampleRate) {
                ForEach(SampleRate.allCases, id: \.self) { rate in
                    Text(rate.label).tag(rate)
                }
            }
            Picker("声道", selection: $settings.channelCount) {
                ForEach(ChannelCount.allCases, id: \.self) { ch in
                    Text(ch.label).tag(ch)
                }
            }
            Picker("格式", selection: $settings.audioFormat) {
                ForEach(AudioFormatType.allCases.filter(\.availableForUI), id: \.self) { fmt in
                    Text(fmt.label).tag(fmt)
                }
            }
        }
        .pickerStyle(.menu)
    }

    // MARK: - 辅助
    private func labeledField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
        }
    }

    private func labeledField(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, value: value, formatter: NumberFormatter())
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
                .keyboardType(.numberPad)
        }
    }
}
