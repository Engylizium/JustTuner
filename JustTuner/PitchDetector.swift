import Foundation
import AVFoundation
import Accelerate

class PitchDetector {
    private let sampleRate: Double
    private var internalBuffer: [Float] = []
    private let targetBufferSize = 8192 // ~185ms at 44.1kHz, easily enough for 20Hz
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }
    
    /// Detects the fundamental frequency using Auto-Correlation
    func detectPitch(from buffer: AVAudioPCMBuffer) -> Double? {
        guard let floatData = buffer.floatChannelData?[0] else { return nil }
        let frameCount = Int(buffer.frameLength)
        
        let newSamples = Array(UnsafeBufferPointer(start: floatData, count: frameCount))
        internalBuffer.append(contentsOf: newSamples)
        
        // Keep only the most recent 'targetBufferSize' samples
        if internalBuffer.count > targetBufferSize {
            internalBuffer.removeFirst(internalBuffer.count - targetBufferSize)
        }
        
        // Only run pitch detection if we have enough data (at least a reliable chunk)
        guard internalBuffer.count >= 4096 else { return nil }
        
        let analysisCount = internalBuffer.count
        
        // 1. Calculate Unbiased Normalized Auto-Correlation using safe vDSP_dotpr
        let minPeriod = Int(sampleRate / 2000.0)
        let maxPeriod = Int(sampleRate / 20.0)
        
        var nsdf = [Float](repeating: 0, count: maxPeriod + 2)
        
        internalBuffer.withUnsafeBufferPointer { bufferPtr in
            guard let baseAddress = bufferPtr.baseAddress else { return }
            
            for tau in 0...maxPeriod+1 {
                let length = vDSP_Length(analysisCount - tau)
                var acf: Float = 0
                
                // Blisteringly fast, 100% memory safe slide
                vDSP_dotpr(baseAddress, 1, baseAddress.advanced(by: tau), 1, &acf, length)
                
                // Unbiased normalization compensates for window decay inherently
                nsdf[tau] = acf / Float(length)
            }
        }
        
        // 2. Find absolute maximum in the valid search range
        var maxVal: Float = -1.0
        for tau in minPeriod...maxPeriod {
            if nsdf[tau] > maxVal {
                maxVal = nsdf[tau]
            }
        }
        
        // 3. McLeod Peak Picking (Find lowest true fundamental peak above threshold)
        let threshold = maxVal * 0.8
        var bestTau = -1
        
        for tau in minPeriod...maxPeriod {
            let prev = tau > 0 ? nsdf[tau - 1] : -1.0
            let next = tau < maxPeriod + 1 ? nsdf[tau + 1] : -1.0
            
            if nsdf[tau] > threshold && nsdf[tau] > prev && nsdf[tau] > next {
                bestTau = tau
                break // Pick the fundamental, ignoring massive overtones!
            }
        }
        
        // Ensure we can safely access neighboring elements for interpolation
        guard bestTau > 0 && bestTau <= maxPeriod else { return nil }
        
        // 4. Parabolic Interpolation for exact sub-sample peak
        let y1 = Double(nsdf[bestTau - 1])
        let y2 = Double(nsdf[bestTau])
        let y3 = Double(nsdf[bestTau + 1])
        
        let denominator = y1 - 2 * y2 + y3
        let delta = denominator == 0 ? 0 : 0.5 * (y1 - y3) / denominator
        let exactPeriod = Double(bestTau) + delta
        
        // 5. Convert exact period to frequency
        let frequency = sampleRate / exactPeriod
        return frequency
    }
    
    /// Maps frequency to Note name, Cent deviation, and Octave
    static func getNoteInfo(for frequency: Double, referenceA4: Double = 440.0) -> (note: String, cents: Double, octave: Int) {
        if frequency < 20.0 {
            return ("--", 0.0, 0)
        }
        
        let c0 = referenceA4 * pow(2.0, -4.75) // Frequency of C0
        let h = round(12.0 * log2(frequency / c0))
        let octave = Int(h) / 12
        let n = Int(h) % 12
        
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteName = noteNames[n >= 0 ? n : n + 12]
        
        // Calculate exact frequency of the nearest note
        let exactFrequency = c0 * pow(2.0, Double(h) / 12.0)
        let cents = 1200.0 * log2(frequency / exactFrequency)
        
        return (noteName, cents, octave)
    }
    
    /// Converts a string (either a frequency like "440" or a note like "A4", "C#3") to its frequency in Hz.
    static func frequency(from string: String, referenceA4: Double = 440.0) -> Double? {
        let input = string.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Try parsing directly as a number first (e.g., "440", "82.4")
        if let freq = Double(input) {
            return freq
        }
        
        // Try parsing as Note + Octave (e.g., "C4", "F#2", "BB3")
        let regex = try! NSRegularExpression(pattern: "^([A-G][#B]?)([0-9])$")
        guard let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else {
            return nil
        }
        
        if let noteRange = Range(match.range(at: 1), in: input),
           let octaveRange = Range(match.range(at: 2), in: input),
           let octave = Int(String(input[octaveRange])) {
            
            var noteString = String(input[noteRange])
            // Normalize flats to sharps (Bb -> A#)
            let flatToSharp: [String: String] = ["DB": "C#", "EB": "D#", "GB": "F#", "AB": "G#", "BB": "A#"]
            if let sharp = flatToSharp[noteString] {
                noteString = sharp
            }
            
            let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
            guard let noteIndex = noteNames.firstIndex(of: noteString) else {
                return nil
            }
            
            let c0 = referenceA4 * pow(2.0, -4.75)
            // h is the number of semitones above C0
            let h = Double(octave * 12 + noteIndex)
            return c0 * pow(2.0, h / 12.0)
        }
        
        return nil
    }
}
