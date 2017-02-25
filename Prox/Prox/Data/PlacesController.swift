/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import AFNetworking
import Deferred
import FirebaseRemoteConfig
import Foundation

/*
 * Delegate methods for updating places asynchronously.
 * All methods on the delegate will be called on the main thread.
 */
protocol PlacesProviderDelegate: class {
    func placesProvider(_ controller: PlacesProvider, didUpdatePlaces places: [Place])
}

private let ratingWeight: Float = 1
private let reviewWeight: Float = 2

class PlacesProvider {
    weak var delegate: PlacesProviderDelegate?

    private let database = FirebasePlacesDatabase()

    private lazy var radius: Double = {
        return RemoteConfigKeys.searchRadiusInKm.value
    }()

    private var allPlaces = [Place]()

    private var displayedPlaces = [Place]()
    fileprivate var placeKeyMap = [String: Int]()

    /// Protects allPlaces, displayedPlaces, and placeKeyMap.
    fileprivate let placesLock = NSLock()

    private(set) var enabledFilters: Set<PlaceFilter> = Set([ .discover ])
    private(set) var topRatedOnly = false

    init() {}

    convenience init(places: [Place]) {
        self.init()
        self.displayedPlaces = places
        var placesMap = [String: Int]()
        for (index, place) in displayedPlaces.enumerated() {
            placesMap[place.id] = index
        }
        self.placeKeyMap = placesMap
    }

    func place(forKey key: String, callback: @escaping (Place?) -> ()) {
        database.getPlace(forKey: key).upon { callback($0.successResult() )}
    }

    func place(withKey placeKey: String, forEventWithKey eventKey: String, callback: @escaping (Place?) -> ()) {
        let eventProvider = EventsProvider()
        var placeWithEvent: Place?
        var eventForPlace: Event?
        let lock = NSLock()
        var placeReturned = false
        var eventReturned = false
        place(forKey: placeKey) { place in
            defer {
                lock.unlock()
            }
            lock.lock()
            placeReturned = true
            guard let foundPlace = place,
                let event = eventForPlace else {
                    placeWithEvent = place
                    if (eventReturned) {
                        callback(nil)
                    }
                    return
            }
            foundPlace.events.append(event)
            callback(foundPlace)
        }

        eventProvider.event(forKey: eventKey) { event in
            defer {
                lock.unlock()
            }
            lock.lock()
            eventReturned = true
            guard let foundEvent = event,
                let place = placeWithEvent else {
                    eventForPlace = event
                    if (placeReturned) {
                        callback(nil)
                    }
                    return
            }
            place.events.append(foundEvent)
            callback(place)
        }
    }

    func updatePlaces(forLocation location: CLLocation) {
        // Fetch a stable list of places from firebase.
        database.getPlaces(forLocation: location, withRadius: radius).upon { results in
            let places = results.flatMap { $0.successResult() }
            self.didFinishFetchingPlaces(places: places, forLocation: location)
        }
    }

    func filterPlaces(enabledFilters: Set<PlaceFilter>, topRatedOnly: Bool) -> [Place] {
        return placesLock.withReadLock {
            return filterPlacesLocked(enabledFilters: enabledFilters, topRatedOnly: topRatedOnly)
        }
    }

    /// Callers must acquire a read lock before calling this method!
    /// TODO: Terrible name, terrible pattern. Fix this with #529.
    private func filterPlacesLocked(enabledFilters: Set<PlaceFilter>, topRatedOnly: Bool) -> [Place] {
        var reviewCounts = [Int]()

        let distanceSortedPlaces = allPlaces.filter { place in
            guard let firstFilter = place.categories.ids.flatMap({ CategoriesUtil.categoryToFilter[$0] }).first,
                  enabledFilters.contains(firstFilter) else { return false }

            reviewCounts.append(place.yelpProvider.totalReviewCount ?? 0)
            return true
        }

        guard topRatedOnly else { return distanceSortedPlaces }

        let maxReviews = distanceSortedPlaces.reduce(0) { max($0, ($1.yelpProvider.totalReviewCount ?? 0) + ($1.tripAdvisorProvider?.totalReviewCount ?? 0)) }
        let logMaxReviews = log10(Float(maxReviews))

        let sorted = distanceSortedPlaces.sorted { a, b in
            return proxRating(forPlace: a, logMaxReviews: logMaxReviews) > proxRating(forPlace: b, logMaxReviews: logMaxReviews)
        }

        return sorted
    }

    private func proxRating(forPlace place: Place, logMaxReviews: Float) -> Float {
        let yelpCount = Float(place.yelpProvider.totalReviewCount ?? 0)
        let taCount = Float(place.tripAdvisorProvider?.totalReviewCount ?? 0)
        let yelpRating = place.yelpProvider.rating ?? 0
        let taRating = place.tripAdvisorProvider?.rating ?? 0
        let ratingScore = (yelpRating * yelpCount + taRating * taCount) / (yelpCount + taCount)
        let reviewScore = log10(yelpCount + taCount) / logMaxReviews * 5
        return (ratingScore * ratingWeight + reviewScore * reviewWeight) / (ratingWeight + reviewWeight)
    }

    /// Applies the current set of filters to all places, setting `displayedPlaces` to the result.
    /// Callers must acquire a write lock before calling this method!
    fileprivate func updateDisplayedPlaces() {
        displayedPlaces = filterPlacesLocked(enabledFilters: enabledFilters, topRatedOnly: topRatedOnly)

        var placesMap = [String: Int]()
        for (index, place) in displayedPlaces.enumerated() {
            placesMap[place.id] = index
        }
        placeKeyMap = placesMap
    }

    /**
     * displayPlaces merges found places with events with places we have found nearby, giving us a combined list of
     * all the places that we need to show to the user.
     **/
    private func displayPlaces(places: [Place], forLocation location: CLLocation) {
        return PlaceUtilities.sort(places: places, byTravelTimeFromLocation: location, ascending: true, completion: { sortedPlaces in
            self.placesLock.withWriteLock {
                self.allPlaces = sortedPlaces
                self.updateDisplayedPlaces()
            }
            DispatchQueue.main.async {
                var displayedPlaces: [Place]!
                self.placesLock.withReadLock {
                    displayedPlaces = self.displayedPlaces
                }
                self.delegate?.placesProvider(self, didUpdatePlaces: displayedPlaces)
            }

        })
    }

    private func didFinishFetchingPlaces(places: [Place], forLocation location: CLLocation) {
        let eventsProvider = EventsProvider()
        eventsProvider.getEventsWithPlaces(forLocation: location, usingPlacesDatabase: self.database) { placesWithEvents in
            let placesSet = Set<Place>(places)
            let eventPlacesSet = Set<Place>(placesWithEvents)
            let union = eventPlacesSet.union(placesSet)

            // TODO refactor for a more incremental load, and therefore
            // insertion sort approach to ranking. We shouldn't do too much of this until
            // we have the waiting states implemented.
            self.displayPlaces(places: Array(union), forLocation: location)
        }
    }

    func nextPlace(forPlace place: Place) -> Place? {
        return self.placesLock.withReadLock {
            // if the place isn't in the list, make the first item in the list the next item
            guard let currentPlaceIndex = self.placeKeyMap[place.id] else {
                return displayedPlaces.count > 0 ? displayedPlaces[displayedPlaces.startIndex] : nil
            }

            guard currentPlaceIndex + 1 < displayedPlaces.endIndex else { return nil }

            return displayedPlaces[displayedPlaces.index(after: currentPlaceIndex)]
        }
    }

    func previousPlace(forPlace place: Place) -> Place? {
        return self.placesLock.withReadLock {
            guard let currentPlaceIndex = self.placeKeyMap[place.id],
                currentPlaceIndex > displayedPlaces.startIndex else { return nil }

            return displayedPlaces[displayedPlaces.index(before: currentPlaceIndex)]
        }
    }

    func numberOfPlaces() -> Int {
        return self.placesLock.withReadLock {
            return displayedPlaces.count
        }
    }

    func place(forIndex index: Int) throws -> Place {
        return try self.placesLock.withReadLock {
            guard index < displayedPlaces.endIndex,
                index >= displayedPlaces.startIndex else {
                    throw PlaceDataSourceError(message: "There is no place at index: \(index)")
            }

            return displayedPlaces[index]
        }
    }

    func index(forPlace place: Place) -> Int? {
        return self.placesLock.withReadLock {
            return placeKeyMap[place.id]
        }
    }

    func refresh(enabledFilters: Set<PlaceFilter>, topRatedOnly: Bool) {
        assert(Thread.isMainThread)

        var displayedPlaces: [Place]!
        placesLock.withWriteLock {
            self.enabledFilters = enabledFilters
            self.topRatedOnly = topRatedOnly
            updateDisplayedPlaces()
            displayedPlaces = self.displayedPlaces
        }

        delegate?.placesProvider(self, didUpdatePlaces: displayedPlaces)
    }

    func getDisplayedPlacesCopy() -> [Place] {
        var placesCopy: [Place] = []
        placesLock.withReadLock {
            placesCopy = Array(self.displayedPlaces)
        }
        return placesCopy
    }
}
