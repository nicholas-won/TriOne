import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    
    @Published var isAuthorized = false
    @Published var currentLocation: CLLocation?
    @Published var totalDistance: Double = 0
    @Published var currentSpeed: Double = 0
    @Published var locationError: String?
    
    private var previousLocation: CLLocation?
    private var isTracking = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 5 meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        checkAuthorization()
    }
    
    private func checkAuthorization() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
        case .denied, .restricted:
            isAuthorized = false
            locationError = "Location access denied"
        case .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startTracking() {
        guard isAuthorized else {
            requestAuthorization()
            return
        }
        
        isTracking = true
        totalDistance = 0
        previousLocation = nil
        currentSpeed = 0
        locationManager.startUpdatingLocation()
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }
    
    func resetDistance() {
        totalDistance = 0
        previousLocation = nil
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last, isTracking else { return }
            
            currentLocation = location
            currentSpeed = max(0, location.speed)
            
            if let previous = previousLocation {
                let distance = location.distance(from: previous)
                if distance < 100 { // Ignore jumps > 100m
                    totalDistance += distance
                }
            }
            
            previousLocation = location
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationError = error.localizedDescription
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            checkAuthorization()
        }
    }
}

