import Foundation
import Testing
@testable import DeveloperNews

// The digest repeats on a calendar trigger that reads only hour and minute, so
// the stored value is a minute of the day rather than a date. These pin the two
// conversions the picker and the scheduler sit on either side of.
@Suite struct DigestTimeTests {
    @Test func minuteOfDaySplitsIntoHourAndMinute() {
        let time = DigestTime(minuteOfDay: 7 * 60 + 30)

        #expect(time.hour == 7)
        #expect(time.minute == 30)
    }

    // A DatePicker hands back a whole date. Only the clock part survives.
    @Test func aPickedDateKeepsOnlyItsClockTime() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 14
        components.hour = 21
        components.minute = 5
        let picked = Calendar.current.date(from: components)!

        let time = DigestTime(from: picked)

        #expect(time.minuteOfDay == 21 * 60 + 5)
    }

    @Test func theTimeRoundTripsThroughADate() {
        let time = DigestTime(minuteOfDay: 6 * 60 + 45)

        let restored = DigestTime(from: time.date(on: .now))

        #expect(restored == time)
    }

    // A stored value can only have come from this app, but a number read back
    // out of UserDefaults is still a number — clamping keeps a nonsense one from
    // reaching the calendar trigger.
    @Test func aValueOutsideTheDayIsClamped() {
        #expect(DigestTime(minuteOfDay: -30).minuteOfDay == 0)
        #expect(DigestTime(minuteOfDay: 5_000).minuteOfDay == 24 * 60 - 1)
    }

    @Test func theDefaultIsNineInTheMorning() {
        #expect(DigestTime.default.hour == 9)
        #expect(DigestTime.default.minute == 0)
    }
}
