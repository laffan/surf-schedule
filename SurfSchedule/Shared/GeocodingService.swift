import Foundation
import CoreLocation

/// Turns a ZIP / postal code into a coordinate using Apple's on-device
/// geocoder. No API key required.
struct GeocodingService {

    enum ServiceError: Error {
        case notFound
    }

    func coordinate(forZip zip: String) async throws -> CLLocationCoordinate2D {
        let trimmed = zip.trimmingCharacters(in: .whitespacesAndNewlines)
        let placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
        guard let location = placemarks.first?.location else {
            throw ServiceError.notFound
        }
        return location.coordinate
    }
}
