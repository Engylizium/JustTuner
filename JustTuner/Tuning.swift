import Foundation

/// Defines a musical tuning preset
struct Tuning: Identifiable, Hashable, Codable {
    var id = UUID()
    let name: String
    /// Frequencies of the open strings from lowest to highest pitch
    let stringFrequencies: [Double]
    let isCustom: Bool
    
    var targetNotesString: String {
        stringFrequencies.map { freq in
            let info = PitchDetector.getNoteInfo(for: freq)
            return "\(info.note)\(info.octave)"
        }.joined(separator: " ")
    }
    
    init(id: UUID = UUID(), name: String, stringFrequencies: [Double], isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.stringFrequencies = stringFrequencies
        self.isCustom = isCustom
    }
    
    /// Predefined common tunings
    static let allPresets: [Tuning] = [
        Tuning(name: "Chromatic", stringFrequencies: []),
        Tuning(name: "Guitar Standard", stringFrequencies: [82.41, 110.00, 146.83, 196.00, 246.94, 329.63]),
        Tuning(name: "Guitar Drop D", stringFrequencies: [73.42, 110.00, 146.83, 196.00, 246.94, 329.63]),
        Tuning(name: "Bass Standard", stringFrequencies: [41.20, 55.00, 73.42, 98.00]),
        Tuning(name: "Ukulele Standard", stringFrequencies: [392.00, 261.63, 329.63, 440.00]),
        Tuning(name: "Violin Standard", stringFrequencies: [196.00, 293.66, 440.00, 659.25])
    ]
}

