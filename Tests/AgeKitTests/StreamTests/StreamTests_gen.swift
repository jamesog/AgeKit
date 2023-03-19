import XCTest
@testable import AgeKit

class StreamTests: XCTestCase {
    func testRoundTrip_Length_0_Step_512() throws {
        try roundTrip(stepSize: 512, length: 0)
    }
    func testRoundTrip_Length_1000_Step_512() throws {
        try roundTrip(stepSize: 512, length: 1000)
    }
    func testRoundTrip_Length_chunkSize_Step_512() throws {
        try roundTrip(stepSize: 512, length: chunkSize)
    }
    func testRoundTrip_Length_chunkSizePlus100_Step_512() throws {
        try roundTrip(stepSize: 512, length: chunkSize+100)
    }
    func testRoundTrip_Length_0_Step_600() throws {
        try roundTrip(stepSize: 600, length: 0)
    }
    func testRoundTrip_Length_1000_Step_600() throws {
        try roundTrip(stepSize: 600, length: 1000)
    }
    func testRoundTrip_Length_chunkSize_Step_600() throws {
        try roundTrip(stepSize: 600, length: chunkSize)
    }
    func testRoundTrip_Length_chunkSizePlus100_Step_600() throws {
        try roundTrip(stepSize: 600, length: chunkSize+100)
    }
    func testRoundTrip_Length_0_Step_1000() throws {
        try roundTrip(stepSize: 1000, length: 0)
    }
    func testRoundTrip_Length_1000_Step_1000() throws {
        try roundTrip(stepSize: 1000, length: 1000)
    }
    func testRoundTrip_Length_chunkSize_Step_1000() throws {
        try roundTrip(stepSize: 1000, length: chunkSize)
    }
    func testRoundTrip_Length_chunkSizePlus100_Step_1000() throws {
        try roundTrip(stepSize: 1000, length: chunkSize+100)
    }
    func testRoundTrip_Length_0_Step_chunkSize() throws {
        try roundTrip(stepSize: chunkSize, length: 0)
    }
    func testRoundTrip_Length_1000_Step_chunkSize() throws {
        try roundTrip(stepSize: chunkSize, length: 1000)
    }
    func testRoundTrip_Length_chunkSize_Step_chunkSize() throws {
        try roundTrip(stepSize: chunkSize, length: chunkSize)
    }
    func testRoundTrip_Length_chunkSizePlus100_Step_chunkSize() throws {
        try roundTrip(stepSize: chunkSize, length: chunkSize+100)
    }
}
