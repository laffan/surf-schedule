import Foundation
import CoreLocation

/// Per-day weather distilled from the National Weather Service forecast.
struct DailyWeather {
    var windDescription: String?
    var conditions: String?
    var lowTemp: Int?
    var highTemp: Int?
}

/// Fetches wind, conditions and temperatures from NOAA's National Weather
/// Service API: https://api.weather.gov
struct WeatherService {

    enum ServiceError: Error {
        case badResponse
    }

    private let session = URLSession.shared

    /// The NWS API requires a descriptive User-Agent on every request.
    private var request: (URL) -> URLRequest = { url in
        var req = URLRequest(url: url)
        req.setValue("SurfSchedule/1.0 (github.com/laffan/surf-schedule)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        return req
    }

    /// Returns weather keyed by the start-of-day date for each forecast day.
    func dailyForecast(for coordinate: CLLocationCoordinate2D) async throws -> [Date: DailyWeather] {
        // 1. Resolve the grid forecast URL for this point.
        let pointsURL = URL(string: "https://api.weather.gov/points/\(coordinate.latitude),\(coordinate.longitude)")!
        let (pointsData, pointsResponse) = try await session.data(for: request(pointsURL))
        guard (pointsResponse as? HTTPURLResponse)?.statusCode == 200 else {
            throw ServiceError.badResponse
        }
        let points = try JSONDecoder().decode(PointsResponse.self, from: pointsData)

        // 2. Fetch the 12-hour-period forecast.
        guard let forecastURL = URL(string: points.properties.forecast) else {
            throw ServiceError.badResponse
        }
        let (forecastData, forecastResponse) = try await session.data(for: request(forecastURL))
        guard (forecastResponse as? HTTPURLResponse)?.statusCode == 200 else {
            throw ServiceError.badResponse
        }
        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: forecastData)

        // 3. Collapse day/night periods into one entry per calendar day.
        let isoFormatter = ISO8601DateFormatter()
        let calendar = Calendar.current
        var result: [Date: DailyWeather] = [:]

        for period in forecast.properties.periods {
            guard let start = isoFormatter.date(from: period.startTime) else { continue }
            let day = calendar.startOfDay(for: start)
            var entry = result[day] ?? DailyWeather()

            if period.isDaytime {
                entry.highTemp = period.temperature
                entry.windDescription = period.windSpeed
                entry.conditions = period.shortForecast
            } else {
                entry.lowTemp = period.temperature
                // Use daytime conditions if we have them; otherwise fall back.
                if entry.conditions == nil { entry.conditions = period.shortForecast }
                if entry.windDescription == nil { entry.windDescription = period.windSpeed }
            }

            result[day] = entry
        }

        return result
    }

    // MARK: - Wire types

    private struct PointsResponse: Decodable {
        let properties: Properties
        struct Properties: Decodable { let forecast: String }
    }

    private struct ForecastResponse: Decodable {
        let properties: Properties
        struct Properties: Decodable { let periods: [Period] }
        struct Period: Decodable {
            let startTime: String
            let isDaytime: Bool
            let temperature: Int
            let windSpeed: String
            let shortForecast: String
        }
    }
}
