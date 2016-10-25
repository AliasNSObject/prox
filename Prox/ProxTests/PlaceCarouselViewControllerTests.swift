/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
import CoreLocation
import MapKit

@testable import Prox

class PlaceCarouselViewControllerTests: XCTestCase {

    var placeCarouselVC: PlaceCarouselViewController!
    
    override func setUp() {
        super.setUp()
        placeCarouselVC = PlaceCarouselViewController()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func placesList(number: Int) -> [Place] {
        var places = [Place]()
        for index in 0..<number {
            let placeID = index + 1
            places.append(Place(id: "\(placeID)", name: "Place \(placeID)", summary: "Here is a summary of Place \(placeID)", latLong: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)))
        }

        return places
    }
    
}

// PlaceDataSource implementation tests
extension PlaceCarouselViewControllerTests {

    func testPlaceDataSourceReturnsCorrectNumberOfPlaces() {
        let places = placesList(number: 4)
        placeCarouselVC.places = places

        XCTAssertEqual(placeCarouselVC.numberOfPlaces(), places.count)
    }

    func testPlaceDataSourceReturnsCorrectPlaceForIndex() {
        let places = placesList(number: 4)
        placeCarouselVC.places = places

        let requestedIndex = 2

        let thirdPlace = try? placeCarouselVC.place(forIndex: requestedIndex)
        XCTAssertNotNil(thirdPlace)

        XCTAssertEqual(thirdPlace!.id, "\(requestedIndex + 1)")
    }

    func testPlaceDataSourceThrowsErrorOnOutOfBoundsIndex() {
        let places = placesList(number: 4)
        placeCarouselVC.places = places

        XCTAssertThrowsError(try placeCarouselVC.place(forIndex: 4))
    }

    func testPlaceDataSourceReturnsCorrectNextPlace() {
        let places = placesList(number: 4)
        placeCarouselVC.places = places

        // test with known next place
        var requestedIndex = 0
        var currentPlace = places[requestedIndex]
        // should be 1
        XCTAssertEqual(currentPlace.id, "\(requestedIndex + 1)")
        var nextPlace = placeCarouselVC.nextPlace(forPlace: currentPlace)
        // should be 2
        XCTAssertNotNil(nextPlace)
        XCTAssertEqual(nextPlace!.id, "\(requestedIndex + 2)")

        // test with known no next place
        requestedIndex = 3
        currentPlace = places[requestedIndex]
        nextPlace = placeCarouselVC.nextPlace(forPlace: currentPlace)
        XCTAssertNil(nextPlace)
    }

    func testPlaceDataSourceReturnsCorrectPreviousPlace() {
        let places = placesList(number: 4)
        placeCarouselVC.places = places

        // test with known next place
        var requestedIndex = 3
        var currentPlace = places[requestedIndex]
        // should be 4
        XCTAssertEqual(currentPlace.id, "\(requestedIndex + 1)")
        var previousPlace = placeCarouselVC.previousPlace(forPlace: currentPlace)
        XCTAssertNotNil(previousPlace)
        // should be 3
        XCTAssertEqual(previousPlace!.id, "\(requestedIndex)")

        // test with known no next place
        requestedIndex = 0
        currentPlace = places[requestedIndex]
        previousPlace = placeCarouselVC.previousPlace(forPlace: currentPlace)
        XCTAssertNil(previousPlace)
    }

}
