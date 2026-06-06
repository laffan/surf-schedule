import Foundation
import CoreLocation

/// Fetches tide stations and high/low tide predictions from NOAA's
/// Tides & Currents API: https://api.tidesandcurrents.noaa.gov
struct NOAATideService {

    enum ServiceError: Error {
        case badResponse
        case noStationsFound
    }

    private let session = URLSession.shared

    // MARK: - Nearby stations

    /// Returns the `limit` nearest tide-prediction stations to a coordinate,
    /// closest first, each tagged with its distance in miles.
    func nearbyStations(to coordinate: CLLocationCoordinate2D, limit: Int) async throws -> [TideStation] {
        let url = URL(string: "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=tidepredictions")!
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(StationListResponse.self, from: data)
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let sorted = decoded.stations
            .map { station -> (TideStation, Double) in
                let meters = CLLocation(latitude: station.lat, longitude: station.lng).distance(from: here)
                let tide = TideStation(
                    id: station.id,
                    name: station.name,
                    latitude: station.lat,
                    longitude: station.lng,
                    distanceMiles: meters / 1609.344
                )
                return (tide, meters)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)

        guard !sorted.isEmpty else { throw ServiceError.noStationsFound }
        return Array(sorted)
    }

    // MARK: - Predictions

    /// High/low tide events for `days` days starting today, at the given station.
    func highLowPredictions(station: TideStation, days: Int) async throws -> [TideEvent] {
        let begin = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: begin) ?? begin

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"

        var components = URLComponents(string: "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter")!
        components.queryItems = [
            URLQueryItem(name: "product", value: "predictions"),
            URLQueryItem(name: "application", value: "SurfSchedule"),
            URLQueryItem(name: "begin_date", value: fmt.string(from: begin)),
            URLQueryItem(name: "end_date", value: fmt.string(from: end)),
            URLQueryItem(name: "datum", value: "MLLW"),
            URLQueryItem(name: "station", value: station.id),
            URLQueryItem(name: "time_zone", value: "lst_ldt"),
            URLQueryItem(name: "units", value: "english"),
            URLQueryItem(name: "interval", value: "hilo"),
            URLQueryItem(name: "format", value: "json"),
        ]

        let (data, response) = try await session.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(PredictionsResponse.self, from: data)

        // NOAA returns local station time (no offset), e.g. "2026-06-06 14:30".
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        timeFormatter.timeZone = .current

        return decoded.predictions.compactMap { p in
            guard let date = timeFormatter.date(from: p.t),
                  let kind = TideEvent.Kind(rawValue: p.type),
                  let height = Double(p.v) else { return nil }
            return TideEvent(time: date, kind: kind, height: height)
        }
    }

    // MARK: - Wire types

    private struct StationListResponse: Decodable {
        let stations: [Station]
        struct Station: Decodable {
            let id: String
            let name: String
            let lat: Double
            let lng: Double
        }
    }

    private struct PredictionsResponse: Decodable {
        let predictions: [Prediction]
        struct Prediction: Decodable {
            let t: String   // time, e.g. "2026-06-06 14:30"
            let v: String   // height
            let type: String // "H" or "L"
        }
    }
}
