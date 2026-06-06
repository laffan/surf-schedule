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
    @Published var stationName: String?
    @Published var state: LoadState = .idle

    private let tideService = NOAATideService()
    private let weatherService = WeatherService()

    /// Number of days shown in the calendar.
    private let forecastDays = 7

    /// Surf window length before high tide, in seconds (2 hours).
    private let windowLength: TimeInterval = 2 * 60 * 60

    /// Builds the weekly schedule for a coordinate.
    func load(for coordinate: CLLocationCoordinate2D) async {
        state = .loading
        do {
            let station = try await tideService.nearestStation(to: coordinate)
            stationName = station.name

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
