import SwiftUI

/// Post-onboarding dashboard view
/// Shows financial overview after user has completed their financial plan
struct DashboardView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var selectedBucket: BucketCategory?
    @State private var showProfileSheet = false

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        // Offline banner
                        if viewModel.isOffline {
                            OfflineBannerView()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        planActiveView
                    }
                    .padding(DesignTokens.Spacing.md)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isOffline)
                }
                .primaryBackgroundGradient()
                .navigationTitle("Financial Overview")
                .toolbar {
                    // Add account button
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                await viewModel.connectBankAccount(from: nil)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(DesignTokens.Colors.accentPrimary)
                        }
                    }

                    // Profile button
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showProfileSheet = true
                        } label: {
                            Image(systemName: "person.circle")
                                .foregroundColor(DesignTokens.Colors.accentPrimary)
                        }
                    }
                }
                .refreshable {
                    await viewModel.performSmartRefresh(isUserInitiated: true)
                }
                .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                    Button("OK") {
                        viewModel.error = nil
                    }
                } message: {
                    if let error = viewModel.error {
                        Text(error.localizedDescription)
                    }
                }
                .sheet(isPresented: $showProfileSheet) {
                    ProfileView(authService: AuthService.shared)
                }
            }

            // Loading overlay
            LoadingOverlay(
                currentStep: viewModel.loadingStep,
                isVisible: viewModel.showLoadingOverlay
            )

            // Success banner
            SuccessBanner(
                message: viewModel.successMessage,
                isVisible: viewModel.showSuccessBanner
            )
        }
    }

    // MARK: - Plan Active View

    private var planActiveView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Allocation Buckets Section
            if !viewModel.budgetManager.allocationBuckets.isEmpty {
                allocationBucketsSection
            }

            // Financial Buckets
            if let summary = viewModel.summary {
                bucketsGrid(summary: summary)
            }
        }
    }

    // MARK: - Allocation Buckets Section

    private var allocationBucketsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Your Financial Plan")
                .headlineStyle(color: .white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(viewModel.budgetManager.allocationBuckets) { bucket in
                        AllocationBucketSummaryCard(
                            bucket: bucket,
                            budgetManager: viewModel.budgetManager
                        )
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xxs)
            }
        }
    }

    // MARK: - Subviews

    private func bucketsGrid(summary: AnalysisSnapshot) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DesignTokens.Spacing.md) {
            ForEach(BucketCategory.allCases, id: \.self) { bucket in
                NavigationLink {
                    CategoryDetailView(
                        category: bucket,
                        amount: summary.bucketValue(for: bucket),
                        summary: summary,
                        accounts: viewModel.accounts,
                        viewModel: viewModel
                    )
                } label: {
                    BucketCard(
                        category: bucket,
                        amount: summary.bucketValue(for: bucket),
                        isSelected: selectedBucket == bucket,
                        needsValidationCount: viewModel.needsValidationCount(for: bucket)
                    )
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
