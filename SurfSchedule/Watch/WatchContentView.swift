import SwiftUI

struct WatchContentView: View {
    @StateObject private var location = LocationManager()
    @StateObject private var viewModel = SurfScheduleViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                case .failed(let message):
                    VStack(spacing: 8) {
                        Text(message)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                        Button("Retry") { reload() }
                    }
                case .loaded:
                    List(viewModel.days) { day in
                        WatchDayRow(day: day)
                    }
                }
            }
            .navigationTitle("Surf")
        }
        .task(id: location.location) {
            if location.location != nil {
                await reloadAsync()
            }
        }
        .onAppear { location.requestLocation() }
    }

    private func reload() {
        Task { await reloadAsync() }
    }

    private func reloadAsync() async {
        guard let coordinate = location.location?.coordinate else {
            location.requestLocation()
            return
        }
        await viewModel.load(for: coordinate)
    }
}

private struct WatchDayRow: View {
    let day: SurfDay

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.dayName)
                .font(.headline)
            if let window = day.surfWindows.first {
                Text(window.label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.blue)
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
            Text(day.weatherSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    WatchContentView()
}
