import SwiftUI

struct ContentView: View {
    @StateObject private var location = LocationManager()
    @StateObject private var viewModel = SurfScheduleViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Finding surf…")
                case .failed(let message):
                    VStack(spacing: 12) {
                        Text(message)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Retry") { reload() }
                    }
                    .padding()
                case .loaded:
                    List(viewModel.days) { day in
                        DayRow(day: day)
                    }
                    .listStyle(.plain)
                    .refreshable { await reloadAsync() }
                }
            }
            .navigationTitle("Surf")
            .toolbar {
                if let station = viewModel.stationName {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text(station)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
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

/// One day in the weekly calendar, matching the requested layout.
private struct DayRow: View {
    let day: SurfDay

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.dayName)
                .font(.headline)

            if day.surfWindows.isEmpty {
                Text("No daytime high tide")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(day.surfWindows) { window in
                    Text(window.label)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }

            Text(day.weatherSummary)
                .font(.subheadline)
            Text(day.temperatureSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ContentView()
}
