import Foundation
import CoreLocation
import ImageIO
import UIKit

/// Extracts GPS coordinates from photo EXIF data and reports tech location to Convex
class PhotoLocationReporter {
    static let shared = PhotoLocationReporter()
    
    /// Extract GPS coordinates from image data
    func extractGPS(from imageData: Data) -> CLLocationCoordinate2D? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
              let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
              let lng = gps[kCGImagePropertyGPSLongitude as String] as? Double,
              let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let lngRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String
        else { return nil }
        
        let latitude = latRef == "S" ? -lat : lat
        let longitude = lngRef == "W" ? -lng : lng
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// Extract GPS from UIImage (uses JPEG representation)
    func extractGPS(from image: UIImage) -> CLLocationCoordinate2D? {
        guard let data = image.jpegData(compressionQuality: 1.0) else { return nil }
        return extractGPS(from: data)
    }
    
    /// Report tech location to Convex
    func reportLocation(lat: Double, lng: Double, jobId: String?, token: String?) {
        guard let token = token else { return }
        
        let url = URL(string: "https://brazen-seal-477.convex.cloud/api/mutation")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var args: [String: Any] = [
            "lat": lat,
            "lng": lng,
            "timestamp": Date().timeIntervalSince1970 * 1000
        ]
        if let jobId = jobId { args["jobId"] = jobId }
        
        let body: [String: Any] = [
            "path": "techLocations:record",
            "args": args
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("⚠️ PhotoLocationReporter: Failed to report location: \(error.localizedDescription)")
            } else {
                print("✅ PhotoLocationReporter: Location reported (\(lat), \(lng))")
            }
        }.resume()
    }
}
