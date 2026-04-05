import Foundation

/// Business logic that converts Hz to Notes and calculates the deviation in cents.
struct TunerModel {
    let frequency: Double
    let note: String
    let octave: Int
    let cents: Double
    
    init(frequency: Double = 0, note: String = "--", octave: Int = 0, cents: Double = 0.0) {
        self.frequency = frequency
        self.note = note
        self.octave = octave
        self.cents = cents
    }
}
