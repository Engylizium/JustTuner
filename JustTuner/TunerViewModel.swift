import Foundation
import Combine

/// Prepares data for the UI, applying smoothing/averaging algorithms to prevent UI jitter.
class TunerViewModel: ObservableObject {
    @Published var isListening = false
    @Published var tunerData = TunerModel()
    @Published var referenceA4: Double = 440.0
    
    // Tuning presets
    @Published var availableTunings: [Tuning] = []
    @Published var selectedTuning: Tuning = Tuning.allPresets[0] {
        didSet {
            centsHistory.removeAll()
            tunerData = TunerModel()
            saveLastTuning()
        }
    }
    
    private let audioManager = AudioEngine.shared
    private var detector: PitchDetector?
    private let customTuningsKey = "custom_tunings"
    private let selectedTuningKey = "selected_tuning_id"
    
    // Smoothing buffer for cents
    private var centsHistory: [Double] = []
    private let smoothingFactor = 5
    
    init() {
        loadTunings()
    }
    
    private func loadTunings() {
        var tunings = Tuning.allPresets
        
        if let data = UserDefaults.standard.data(forKey: customTuningsKey),
           let custom = try? JSONDecoder().decode([Tuning].self, from: data) {
            tunings.append(contentsOf: custom)
        }
        
        self.availableTunings = tunings
        
        if let savedIdString = UserDefaults.standard.string(forKey: selectedTuningKey),
           let savedId = UUID(uuidString: savedIdString),
           let matched = tunings.first(where: { $0.id == savedId }) {
            self.selectedTuning = matched
        } else {
            self.selectedTuning = tunings[0]
        }
    }
    
    func addCustomTuning(name: String, frequencies: [Double]) {
        print("ADD CUSTOM TUNING: \(name) with frequencies: \(frequencies)")
        let newTuning = Tuning(name: name, stringFrequencies: frequencies, isCustom: true)
        var currentCustom: [Tuning] = []
        
        if let data = UserDefaults.standard.data(forKey: customTuningsKey),
           let custom = try? JSONDecoder().decode([Tuning].self, from: data) {
            currentCustom = custom
        }
        
        currentCustom.append(newTuning)
        
        if let encoded = try? JSONEncoder().encode(currentCustom) {
            UserDefaults.standard.set(encoded, forKey: customTuningsKey)
        }
        
        loadTunings()
        selectedTuning = newTuning
    }
    
    func deleteCustomTuning(_ tuning: Tuning) {
        guard tuning.isCustom else { return }
        
        if let data = UserDefaults.standard.data(forKey: customTuningsKey),
           var custom = try? JSONDecoder().decode([Tuning].self, from: data) {
            custom.removeAll(where: { $0.id == tuning.id })
            
            if let encoded = try? JSONEncoder().encode(custom) {
                UserDefaults.standard.set(encoded, forKey: customTuningsKey)
            }
        }
        
        if selectedTuning.id == tuning.id {
            selectedTuning = Tuning.allPresets[0]
        }
        
        loadTunings()
    }
    
    private func saveLastTuning() {
        UserDefaults.standard.set(selectedTuning.id.uuidString, forKey: selectedTuningKey)
    }
    
    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    private func startListening() {
        audioManager.requestPermissions { [weak self] granted in
            guard let self = self, granted else { return }
            
            do {
                self.audioManager.onAudioBuffer = { [weak self] buffer in
                    guard let self = self else { return }
                    
                    if self.detector == nil {
                        self.detector = PitchDetector(sampleRate: buffer.format.sampleRate)
                    }
                    
                    if let freq = self.detector?.detectPitch(from: buffer) {
                        
                        var targetNote = ""
                        var targetCents = 0.0
                        var targetOctave = 0
                        
                        // Check if we are in a strict tuning mode (not chromatic)
                        if !self.selectedTuning.stringFrequencies.isEmpty {
                            // Find the closest string frequency in the selected tuning
                            if let closestStringFreq = self.selectedTuning.stringFrequencies.min(by: { abs($0 - freq) < abs($1 - freq) }) {
                                // Calculate cents offset relative to the closest string frequency
                                let n = 1200.0 * log2(freq / closestStringFreq)
                                targetCents = n
                                
                                let info = PitchDetector.getNoteInfo(for: closestStringFreq, referenceA4: self.referenceA4)
                                targetNote = info.note
                                targetOctave = info.octave
                            }
                        } else {
                            // Standard chromatic detection
                            let info = PitchDetector.getNoteInfo(for: freq, referenceA4: self.referenceA4)
                            targetNote = info.note
                            targetCents = info.cents
                            targetOctave = info.octave
                        }
                        
                        // Apply smoothing to cents
                        self.centsHistory.append(targetCents)
                        if self.centsHistory.count > self.smoothingFactor {
                            self.centsHistory.removeFirst()
                        }
                        
                        let smoothedCents = self.centsHistory.reduce(0, +) / Double(self.centsHistory.count)
                        
                        DispatchQueue.main.async {
                            self.tunerData = TunerModel(frequency: freq, note: targetNote, octave: targetOctave, cents: smoothedCents)
                        }
                    } else {
                         // Optional: Clear or fade out if no pitch detected, to indicate silence
                    }
                }
                try self.audioManager.start()
                DispatchQueue.main.async {
                    self.isListening = true
                }
            } catch {
                print("Failed to start audio engine: \(error)")
            }
        }
    }
    
    private func stopListening() {
        audioManager.stop()
        isListening = false
        centsHistory.removeAll()
    }
}


