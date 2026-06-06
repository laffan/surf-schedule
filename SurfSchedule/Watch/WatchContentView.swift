import SwiftUI

struct WatchContentView: View {
    @StateObject private var location = LocationManager()
    @StateObject private var viewModel = SurfScheduleViewModel()

    @State private var didInitialLoad = false

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
                        Button("Retry") { Task { await viewModel.reload() } }
                    }
                case .loaded:
                    List {
                        if !viewModel.nearbyStations.isEmpty {
                            NavigationLink {
                                BeachPicker(viewModel: viewModel)
                            } label: {
                                Label(viewModel.selectedStation?.name ?? "Choose beach",
                                      systemImage: "mappin.and.ellipse")
                                    .font(.footnote)
                            }
                        }
                        ForEach(viewModel.days) { day in
                            WatchDayRow(day: day)
                        }
                    }
                }
            }
            .navigationTitle("Surf")
        }
        .task(id: location.location) {
            guard !didInitialLoad, let coordinate = location.location?.coordinate else { return }
            didInitialLoad = true
            await viewModel.load(around: coordinate)
        }
        .onAppear { location.requestLocation() }
    }
}

/// A scrollable list of nearby beaches; tapping one reloads and pops back.
private struct BeachPicker: View {
    @ObservedObject var viewModel: SurfScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(viewModel.nearbyStations) { station in
            Button {
                Task { await viewModel.select(station) }
                dismiss()
            } label: {
                HStack {
                    Text(station.menuLabel)
                    Spacer()
                    if station.id == viewModel.selectedStation?.id {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
        .navigationTitle("Beaches")
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
