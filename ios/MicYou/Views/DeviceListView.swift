import SwiftUI

/// 设备发现列表。对齐 Android `DeviceDiscoveryManager` 设备列表 UI。
struct DeviceListView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("已发现设备", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline)
                Spacer()
                if viewModel.discovery.isBrowsing {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Button {
                        viewModel.startDiscovery()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .font(.subheadline)
                }
            }

            if viewModel.discovery.devices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("未发现设备")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("请确保桌面端已启动并在同一局域网")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(viewModel.discovery.devices, id: \.id) { device in
                    deviceRow(device)
                }
            }

            if let error = viewModel.discovery.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear { viewModel.startDiscovery() }
        .onDisappear { viewModel.stopDiscovery() }
    }

    private func deviceRow(_ device: DiscoveredDevice) -> some View {
        Button {
            viewModel.selectDevice(device)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "desktopcomputer")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.subheadline.bold())
                    Text("\(device.ipAddress):\(device.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
