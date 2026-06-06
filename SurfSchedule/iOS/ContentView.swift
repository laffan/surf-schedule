import SwiftUI

struct ContentView: View {
    @StateObject private var location = LocationManager()
    @StateObject private var viewModel = SurfScheduleViewModel()

    @AppStorage("savedZip") private var zip = ""
    @State private var didInitialLoad = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controls
                Divider()
                schedule
            }
            .navigationTitle("Surf")
        }
        // Restore a saved ZIP on launch instead of using GPS.
        .task {
            guard !didInitialLoad, !zip.isEmpty else { return }
            didInitialLoad = true
            await viewModel.load(zip: zip)
        }
        // First GPS fix (only if we didn't restore a ZIP).
        .task(id: location.location) {
            guard !didInitialLoad, let coordinate = location.location?.coordinate else { return }
            didInitialLoad = true
            await viewModel.load(around: coordinate)
        }
        .onAppear { location.requestLocation() }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("ZIP code", text: $zip)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { lookupZip() }

                Button("Go", action: lookupZip)
                    .buttonStyle(.borderedProminent)
                    .disabled(zip.trimmingCharacters(in: .whitespaces).count < 5)

                Button {
                    useCurrentLocation()
                } label: {
                    Image(systemName: "location.fill")
                }
                .buttonStyle(.bordered)
            }

            if !viewModel.nearbyStations.isEmpty {
                Picker("Beach", selection: stationBinding) {
                    ForEach(viewModel.nearbyStations) { station in
                        Text(station.menuLabel).tag(Optional(station))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }

    // MARK: - Schedule

    @ViewBuilder
    private var schedule: some View {
        switch viewModel.state {
        case .idle, .loading:
            Spacer()
            ProgressView("Finding surf…")
            Spacer()
        case .failed(let message):
            Spacer()
            VStack(spacing: 12) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await viewModel.reload() } }
            }
            .padding()
            Spacer()
        case .loaded:
            List(viewModel.days) { day in
                DayRow(day: day)
            }
            .listStyle(.plain)
            .refreshable { await viewModel.reload() }
        }
    }

    // MARK: - Actions

    /// Two-way binding for the beach picker that reloads on change.
    private var stationBinding: Binding<TideStation?> {
        Binding(
            get: { viewModel.selectedStation },
            set: { newValue in
                if let station = newValue {
                    Task { await viewModel.select(station) }
                }
            }
        )
    }

    private func lookupZip() {
        let trimmed = zip.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 5 else { return }
        Task { await viewModel.load(zip: trimmed) }
    }

    private func useCurrentLocation() {
        zip = ""
        viewModel.selectedStation = nil
        if let coordinate = location.location?.coordinate {
            Task { await viewModel.load(around: coordinate) }
        } else {
            location.requestLocation()
        }
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
