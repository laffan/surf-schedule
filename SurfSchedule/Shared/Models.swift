import Foundation

/// A high or low tide event at a given time.
struct TideEvent: Identifiable {
    enum Kind: String {
        case high = "H"
        case low = "L"
    }

    let id = UUID()
    let time: Date
    let kind: Kind
    let height: Double
}

/// The two-hour stretch before a high tide — the best window to surf.
struct SurfWindow: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date   // the moment of high tide

    /// e.g. "1–3 PM"
    var label: String {
        let f = DateFormatter()
        f.dateFormat = "h"
        let startHour = f.string(from: start)
        f.dateFormat = "h a"
        let endHour = f.string(from: end)
        return "\(startHour)–\(endHour)"
    }
}

/// Everything we want to show for a single day in the weekly calendar.
struct SurfDay: Identifiable {
    let id = UUID()
    let date: Date

    var surfWindows: [SurfWindow] = []

    var windDescription: String?   // e.g. "5 to 10 mph"
    var conditions: String?        // e.g. "Sunny"
    var lowTemp: Int?
    var highTemp: Int?

    /// e.g. "Monday"
    var dayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    /// e.g. "5 to 10 mph / Sunny"
    var weatherSummary: String {
        let wind = windDescription ?? "—"
        let cond = conditions ?? "—"
        return "\(wind) / \(cond)"
    }

    /// e.g. "Low 55° / High 75°"
    var temperatureSummary: String {
        let low = lowTemp.map { "\($0)°" } ?? "—"
        let high = highTemp.map { "\($0)°" } ?? "—"
        return "Low \(low) / High \(high)"
    }
}

/// A NOAA tide station (effectively a named beach/location for surf purposes).
struct TideStation: Identifiable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    var distanceMiles: Double? = nil

    /// e.g. "Newport · 3 mi" — used in the beach picker.
    var menuLabel: String {
        if let miles = distanceMiles {
            return "\(name) · \(Int(miles.rounded())) mi"
        }
        return name
    }
}
