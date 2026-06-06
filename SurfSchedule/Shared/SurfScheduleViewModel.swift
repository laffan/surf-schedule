import Foundation
import CoreLocation
import Combine

/// Combines location, tide predictions and weather into a week of `SurfDay`s.
@MainActor
final class SurfScheduleViewModel: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published var days: [SurfDay] = []
    @Published var nearbyStations: [TideStation] = []
    @Published var selectedStation: TideStation?
    @Published var state: LoadState = .idle

    private let tideService = NOAATideService()
    private let weatherService = WeatherService()
    private let geocoder = GeocodingService()

    /// Number of days shown in the calendar.
    private let forecastDays = 7

    /// Surf window length before high tide, in seconds (2 hours).
    private let windowLength: TimeInterval = 2 * 60 * 60

    /// How many nearby beaches to offer in the picker.
    private let nearbyLimit = 12

    // MARK: - Entry points

    /// Loads nearby beaches around a coordinate (from GPS or a ZIP lookup) and
    /// builds the schedule for the closest one, preserving an existing
    /// selection if it's still in range.
    func load(around coordinate: CLLocationCoordinate2D) async {
        state = .loading
        do {
            let stations = try await tideService.nearbyStations(to: coordinate, limit: nearbyLimit)
            nearbyStations = stations

            let chosen = selectedStation.flatMap { current in
                stations.first { $0.id == current.id }
            } ?? stations.first

            selectedStation = chosen
            guard let chosen else {
                state = .failed("No tide stations found nearby.")
                return
            }
            await loadSchedule(for: chosen)
        } catch {
            state = .failed("Couldn't load nearby beaches. Pull to retry.")
        }
    }

    /// Geocodes a ZIP code and loads beaches around it.
    func load(zip: String) async {
        state = .loading
        do {
            let coordinate = try await geocoder.coordinate(forZip: zip)
            selectedStation = nil   // pick the nearest beach to the new ZIP
            await load(around: coordinate)
        } catch {
            state = .failed("Couldn't find that ZIP code.")
        }
    }

    /// Switches to a specific beach the user picked.
    func select(_ station: TideStation) async {
        selectedStation = station
        await loadSchedule(for: station)
    }

    /// Reloads the schedule for the currently selected beach (pull-to-refresh).
    func reload() async {
        guard let station = selectedStation else { return }
        await loadSchedule(for: station)
    }

    // MARK: - Schedule for one station

    private func loadSchedule(for station: TideStation) async {
        state = .loading
        let coordinate = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
        do {
            async let tidesTask = tideService.highLowPredictions(station: station, days: forecastDays)
            async let weatherTask = weatherService.dailyForecast(for: coordinate)

            let tides = try await tidesTask
            // Weather is best-effort: a tide-only schedule is still useful.
            let weather = (try? await weatherTask) ?? [:]

            days = buildDays(tides: tides, weather: weather)
            state = .loaded
        } catch {
            state = .failed("Couldn't load surf data. Pull to retry.")
        }
    }

    // MARK: - Assembly

    private func buildDays(tides: [TideEvent], weather: [Date: DailyWeather]) -> [SurfDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<forecastDays).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            var surfDay = SurfDay(date: day)

            // Surf windows = 2 hours before each daytime high tide that day.
            let highs = tides.filter {
                $0.kind == .high && calendar.isDate($0.time, inSameDayAs: day) && isDaylight($0.time)
            }
            surfDay.surfWindows = highs.map { high in
                SurfWindow(start: high.time.addingTimeInterval(-windowLength), end: high.time)
            }

            if let w = weather[day] {
                surfDay.windDescription = w.windDescription
                surfDay.conditions = w.conditions
                surfDay.lowTemp = w.lowTemp
                surfDay.highTemp = w.highTemp
            }

            return surfDay
        }
    }

    /// Rough daylight filter so we don't suggest pre-dawn high tides.
    private func isDaylight(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return (5...20).contains(hour)
    }
}
