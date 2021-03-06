/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
@testable import Prox
import CoreLocation
import MapKit

class TravelTimesTests: XCTestCase {

    let timeout = 30.0

    let testSource = CLLocationCoordinate2D(latitude: 51.5046323, longitude: -0.0992547)
    let testDestination = CLLocationCoordinate2D(latitude: 51.5100773, longitude: -0.1257861)

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAnyTravelTimes() {

        let waitQuery = expectation(description: "Waiting for travel times to be calculated")

        TravelTimesProvider.travelTime(fromLocation: testSource, toLocation: testDestination) { travelTimes in
            XCTAssertNotNil(travelTimes)
            XCTAssertTrue(travelTimes?.walkingTime != nil || travelTimes?.drivingTime != nil || travelTimes?.publicTransportTime != nil)
            waitQuery.fulfill()
        }

        waitForExpectations(timeout: timeout)

    }

    func testWalkingTravelTimes() {

        let waitQuery = expectation(description: "Waiting for travel times to be calculated")

        TravelTimesProvider.travelTime(fromLocation: testSource, toLocation: testDestination, byTransitType: .walking) { travelTimes in
            XCTAssertNotNil(travelTimes)
            XCTAssertNotNil(travelTimes?.walkingTime)
            XCTAssertNil(travelTimes?.drivingTime)
            XCTAssertNil(travelTimes?.publicTransportTime)
            waitQuery.fulfill()
        }

        waitForExpectations(timeout: timeout)
        
    }

    func testAutomobileTravelTimes() {

        let waitQuery = expectation(description: "Waiting for travel times to be calculated")

        TravelTimesProvider.travelTime(fromLocation: testSource, toLocation: testDestination, byTransitType: .automobile) { travelTimes in
            XCTAssertNotNil(travelTimes)
            XCTAssertNil(travelTimes?.walkingTime)
            XCTAssertNotNil(travelTimes?.drivingTime)
            XCTAssertNil(travelTimes?.publicTransportTime)
            waitQuery.fulfill()
        }

        waitForExpectations(timeout: timeout)
        
    }

    func testPublicTransportTravelTimes() {

        let waitQuery = expectation(description: "Waiting for travel times to be calculated")

        TravelTimesProvider.travelTime(fromLocation: testSource, toLocation: testDestination, byTransitType: .transit) { travelTimes in
            XCTAssertNotNil(travelTimes)
            XCTAssertNil(travelTimes?.walkingTime)
            XCTAssertNil(travelTimes?.drivingTime)
            XCTAssertNotNil(travelTimes?.publicTransportTime)
            waitQuery.fulfill()
        }

        waitForExpectations(timeout: timeout)
        
    }

    func testInvalidRoute() {
        let testInvalidDestination = CLLocationCoordinate2D(latitude: 19.9542305, longitude: 155.8531072)

        let waitQuery = expectation(description: "Waiting for travel times to be calculated")

        TravelTimesProvider.travelTime(fromLocation: testSource, toLocation: testInvalidDestination) { travelTimes in
            XCTAssertNil(travelTimes)
            waitQuery.fulfill()
        }

        waitForExpectations(timeout: timeout)
    }

    func testMultipleTravelTypes() {
        let travelRoutes = [MKDirectionsTransportType.automobile, MKDirectionsTransportType.walking]

        let waitQuery = expectation(description: "Waiting for travel times to be calculated")

        TravelTimesProvider.travelTime(fromLocation: testSource, toLocation: testDestination, byTransitTypes: travelRoutes) { travelTimes in

            XCTAssertNotNil(travelTimes)
            XCTAssertNotNil(travelTimes?.walkingTime)
            XCTAssertNotNil(travelTimes?.drivingTime)
            XCTAssertNil(travelTimes?.publicTransportTime)
            waitQuery.fulfill()
        }

        waitForExpectations(timeout: timeout)
    }

    func testMultipleTravelTypesInvalidRoute() {
        let travelRoutes = [MKDirectionsTransportType.automobile, MKDirectionsTransportType.walking]
        let testInvalidDestination = CLLocationCoordinate2D(latitude: 19.9542305, longitude: 155.8531072)

        let waitQuery = expectation(description: "Waiting for travel times to be calculated")

        TravelTimesProvider.travelTime(fromLocation: testSource, toLocation: testInvalidDestination, byTransitTypes: travelRoutes) { travelTimes in
            XCTAssertNil(travelTimes)
            waitQuery.fulfill()
        }

        waitForExpectations(timeout: timeout)
    }
    
}
