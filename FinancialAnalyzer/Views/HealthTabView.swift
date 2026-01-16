import SwiftUI

/// Router view for the Health tab
/// Shows empty state until setup is complete, then shows full health report
struct HealthTabView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var showSetupFlow = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.healthReportSetupCompleted {
                    // Setup complete - show full health report
                    FinancialHealthReportView(
                        healthMetrics: viewModel.healthMetrics,
                        onSetupHealthReport: { showSetupFlow = true },
                        onDismiss: { }
                    )
                } else {
                    // Setup not complete - show empty state
                    HealthReportEmptyStateView(
                        onSetup: { showSetupFlow = true },
                        onDismiss: { }
                    )
                }
            }
            .sheet(isPresented: $showSetupFlow) {
                HealthReportSetupFlow(
                    viewModel: viewModel,
                    onComplete: {
                        showSetupFlow = false
                    }
                )
            }
        }
        .onAppear {
            // Mark as viewed to remove badge (only first time)
            if !viewModel.hasViewedHealthTab {
                viewModel.markHealthTabViewed()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct HealthTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Empty state preview
            HealthTabView(viewModel: FinancialViewModel())
                .previewDisplayName("Empty State")

            // Full report preview (would need setup completion)
            HealthTabView(viewModel: {
                let vm = FinancialViewModel()
                // In real usage, this would be set after setup
                return vm
            }())
            .previewDisplayName("After Setup")
        }
    }
}
#endif
