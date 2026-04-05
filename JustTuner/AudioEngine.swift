import Foundation
import AVFoundation
import CoreAudio

struct AudioInputDevice: Hashable, Identifiable {
    var id: String { uid }
    let uid: String
    let name: String
}

/// Singleton or dedicated service responsible for starting/stopping the audio stream and managing input devices.
class AudioEngine: ObservableObject {
    static let shared = AudioEngine()
    
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    
    @Published var microphonePermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var availableDevices: [AudioInputDevice] = []
    @Published var selectedDeviceUID: String? {
        didSet {
            // Restart audio engine if it's already running and we changed the device
            if audioEngine.isRunning {
                stop()
                try? start()
            }
            UserDefaults.standard.set(selectedDeviceUID, forKey: "selected_audio_device_uid")
        }
    }
    
    // Callback to pass audio buffers to the pitch detector
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    private init() {
        if let savedUID = UserDefaults.standard.string(forKey: "selected_audio_device_uid") {
            selectedDeviceUID = savedUID
        }
        checkPermissions()
        discoverDevices()
    }
    
    func checkPermissions() {
        microphonePermissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                self.checkPermissions()
                self.discoverDevices()
                completion(granted)
            }
        }
    }
    
    func discoverDevices() {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        
        DispatchQueue.main.async {
            self.availableDevices = session.devices.map { device in
                AudioInputDevice(uid: device.uniqueID, name: device.localizedName)
            }
            
            // If the selected device no longer exists or isn't set, default to the first one
            if self.selectedDeviceUID == nil || !self.availableDevices.contains(where: { $0.uid == self.selectedDeviceUID }) {
                self.selectedDeviceUID = self.availableDevices.first?.uid
            }
        }
    }
    
    private func getAudioDeviceID(from uid: String) -> AudioDeviceID? {
        var deviceID: AudioDeviceID = 0
        var uidString = uid as CFString
        var translation = AudioValueTranslation(
            mInputData: &uidString,
            mInputDataSize: UInt32(MemoryLayout<CFString>.size),
            mOutputData: &deviceID,
            mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        var size = UInt32(MemoryLayout<AudioValueTranslation>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = withUnsafeMutablePointer(to: &translation) { ptr in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &size,
                ptr
            )
        }

        return status == noErr ? deviceID : nil
    }
    
    func start() throws {
        // On macOS, AVAudioSession doesn't exist. We use the engine's input node directly.
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else { return }
        
        // Try to set the specific audio device if one is selected
        if let uid = selectedDeviceUID, let deviceID = getAudioDeviceID(from: uid), let audioUnit = inputNode.audioUnit {
            var idToSet = deviceID
            let size = UInt32(MemoryLayout<AudioDeviceID>.size)
            AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &idToSet,
                size
            )
        }
        
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        
        // Remove any existing taps to prevent crashes on restart
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] (buffer, _) in
            self?.onAudioBuffer?(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    func stop() {
        audioEngine.stop()
        inputNode?.removeTap(onBus: 0)
        inputNode = nil
    }
}

