//
//  RefreshIndicatorView.swift
//  FinancialAnalyzer
//
//  UI components for data refresh status
//

import SwiftUI

/// Subtle refresh indicator for background updates
struct RefreshIndicatorView: View {
    let isRefreshing: Bool
    let strategy: RefreshStrategy
    let lastUpdated: String?
    var isStale: Bool = false

    private var iconName: String {
        if isRefreshing && strategy.showsSubtleIndicator {
            return "arrow.clockwise"
        }
        return isStale ? "exclamationmark.circle" : "clock"
    }

    private var foregroundColor: Color {
        if isRefreshing && strategy.showsSubtleIndicator {
            return .blue
        }
        return isStale ? .orange : .secondary
    }

    private var backgroundColor: Color {
        if isRefreshing && strategy.showsSubtleIndicator {
            return Color.blue.opacity(0.1)
        }
        return isStale ? Color.orange.opacity(0.1) : Color(.systemGray6)
    }

    private var displayText: String {
        if isRefreshing && strategy.showsSubtleIndicator {
            return strategy.description
        }
        if isStale {
            return "Data may be outdated"
        }
        return lastUpdated ?? ""
    }

    private var shouldShow: Bool {
        (isRefreshing && strategy.showsSubtleIndicator) ||
        (lastUpdated != nil && lastUpdated != "Never") ||
        isStale
    }

    var body: some View {
        HStack(spacing: 6) {
            if isRefreshing && strategy.showsSubtleIndicator {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(foregroundColor)
            } else {
                Image(systemName: iconName)
                    .font(.caption2)
            }

            Text(displayText)
                .font(.caption2)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .opacity(shouldShow ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isRefreshing)
    }
}

// MARK: - Offline Banner

/// Banner shown when device is offline
struct OfflineBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)

            Text("Offline - showing cached data")
                .font(.caption)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.orange)
        .cornerRadius(8)
    }
}

// MARK: - Refresh Status Banner

/// Banner showing refresh status for background operations
struct RefreshStatusBanner: View {
    let strategy: RefreshStrategy
    let isVisible: Bool

    var body: some View {
        if isVisible && strategy.showsSubtleIndicator {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.white)

                Text(strategy.description)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.9))
            )
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Last Updated Text

/// Simple text showing when data was last updated
struct LastUpdatedText: View {
    let lastUpdated: String?

    var body: some View {
        if let lastUpdated = lastUpdated, lastUpdated != "Never" {
            Text("Updated \(lastUpdated)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Refresh Indicator") {
    VStack(spacing: 20) {
        RefreshIndicatorView(
            isRefreshing: true,
            strategy: .backgroundFull,
            lastUpdated: nil
        )

        RefreshIndicatorView(
            isRefreshing: false,
            strategy: .none,
            lastUpdated: "5m ago"
        )

        RefreshIndicatorView(
            isRefreshing: true,
            strategy: .balancesOnly,
            lastUpdated: nil
        )

        RefreshIndicatorView(
            isRefreshing: false,
            strategy: .none,
            lastUpdated: nil,
            isStale: true
        )
    }
    .padding()
}

#Preview("Offline Banner") {
    VStack(spacing: 20) {
        OfflineBannerView()
    }
    .padding()
}

#Preview("Refresh Status Banner") {
    VStack(spacing: 20) {
        RefreshStatusBanner(
            strategy: .backgroundFull,
            isVisible: true
        )

        RefreshStatusBanner(
            strategy: .balancesOnly,
            isVisible: true
        )
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
