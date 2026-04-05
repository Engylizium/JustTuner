import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = TunerViewModel()
    @ObservedObject private var audioManager = AudioEngine.shared
    @State private var showSideMenu = false
    @State private var showAddTuningField = false
    @State private var newTuningName = ""
    @State private var newTuningInput = ""
    @State private var newTuningTokens: [String] = []
    
    // Sleek Modern Color Palette
    let bgDark = Color(white: 0.05) // Deep, nearly pure black
    let accentColor = Color(red: 0.0, green: 0.85, blue: 0.75) // Vibrant cyan/mint for "In Tune"
    let alertColor = Color(red: 0.95, green: 0.35, blue: 0.4) // Clean coral/red for "Out of Tune"
    let textPrimary = Color.white
    let textSecondary = Color(white: 0.6)
    
    var body: some View {
        ZStack {
            // Background
            bgDark.ignoresSafeArea()
            
            // Subtle ambient glow centered on the note
            RadialGradient(
                gradient: Gradient(colors: [
                    (abs(viewModel.tunerData.cents) < 3.0 ? accentColor : alertColor).opacity(viewModel.tunerData.note != "--" ? 0.05 : 0.0),
                    .clear
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.3), value: viewModel.tunerData.cents)
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack {
                    Text("JustTuner")
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .foregroundStyle(textSecondary)
                    
                    Spacer()
                    
                    // Input Device Selector
                    Menu {
                        Picker("Input Device", selection: $audioManager.selectedDeviceUID) {
                            ForEach(audioManager.availableDevices) { device in
                                Text(device.name).tag(Optional(device.uid))
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 12))
                            
                            if let selectedUID = audioManager.selectedDeviceUID,
                               let device = audioManager.availableDevices.first(where: { $0.id == selectedUID }) {
                                Text(device.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .frame(maxWidth: 150)
                            }
                        }
                        .foregroundStyle(textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .menuIndicator(.hidden)
                    .menuStyle(.borderlessButton)
                    .padding(.trailing, 8)
                    
                    // Modern Tuning Selector Pill
                    Button(action: { showSideMenu.toggle() }) {
                        HStack(spacing: 6) {
                            Text(viewModel.selectedTuning.name)
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 40)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                Spacer()
                
                // Main Note Display - Huge, Elegant, Lightweight
                HStack(alignment: .top, spacing: 2) {
                    Text(viewModel.tunerData.note)
                        .font(.system(size: 160, weight: .ultraLight, design: .default))
                        .foregroundStyle(textPrimary)
                        .contentTransition(.interpolate)
                        .frame(height: 160) // stabilize height
                    
                    if viewModel.tunerData.note != "--" {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(viewModel.tunerData.octave)")
                                .font(.system(size: 40, weight: .light, design: .default))
                                .foregroundStyle(textSecondary)
                                .padding(.top, 24)
                            
                            Text("tgt")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(textSecondary)
                        }
                    }
                }
                
                // Clean Cents Readout
                Text(String(format: "%+.1f ¢", viewModel.tunerData.cents))
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundStyle(abs(viewModel.tunerData.cents) < 3.0 ? accentColor : textSecondary)
                    .padding(.top, 10)
                
                Spacer()
                
                // Sleek Minimalist Linear Gauge
                ModernLinearGaugeView(
                    cents: viewModel.tunerData.cents,
                    accentColor: accentColor,
                    alertColor: alertColor
                )
                .frame(height: 80)
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Bottom Control Area
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(format: "%.1f", viewModel.tunerData.frequency)) Hz")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(textPrimary)
                        Text("A4=\(String(format: "%.0f", viewModel.referenceA4))")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(textSecondary)
                    }
                    
                    Spacer()
                    
                    // Prominent Glassmorphic Start Button
                    Button(action: { viewModel.toggleListening() }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(viewModel.isListening ? alertColor : accentColor)
                                .frame(width: 8, height: 8)
                                .shadow(color: viewModel.isListening ? alertColor : accentColor, radius: 4)
                            
                            Text(viewModel.isListening ? "Listening" : "Start Tuning")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(textPrimary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ModernButtonStyle())
                }
                .padding(24)
            }
            .ignoresSafeArea(edges: .top)
            
            // Modern Blurry Side Menu
            if showSideMenu {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showSideMenu = false }
                    
                    HStack {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text("Tunings")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(textPrimary)
                                Spacer()
                                Button(action: { showAddTuningField = true }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(accentColor)
                                        .padding(.trailing, 8)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { showSideMenu = false }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.bottom, 10)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(viewModel.availableTunings) { tuning in
                                        HStack {
                                            Button(action: {
                                                viewModel.selectedTuning = tuning
                                                showSideMenu = false
                                            }) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(tuning.name)
                                                        .font(.system(size: 15, weight: viewModel.selectedTuning.id == tuning.id ? .semibold : .regular))
                                                        .foregroundStyle(viewModel.selectedTuning.id == tuning.id ? accentColor : textPrimary)
                                                    
                                                    if !tuning.stringFrequencies.isEmpty {
                                                        Text(tuning.targetNotesString)
                                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                            .foregroundStyle(textSecondary)
                                                    }
                                                }
                                                .padding(.vertical, 4)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Spacer()
                                            
                                            if tuning.isCustom {
                                                Button(action: { viewModel.deleteCustomTuning(tuning) }) {
                                                    Image(systemName: "minus.circle")
                                                        .font(.system(size: 14))
                                                        .foregroundStyle(alertColor.opacity(0.8))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        Divider().background(Color.white.opacity(0.1))
                                    }
                                }
                            }
                        }
                        .padding(30)
                        .frame(width: 300)
                        .background(Color(white: 0.12)) // Solid dark background for the menu
                        .shadow(color: .black.opacity(0.5), radius: 30, x: -10, y: 0)
                    }
                }
                .transition(.move(edge: .trailing))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSideMenu)
                .ignoresSafeArea()
            }
            
            // Custom Tuning Popup Modal
            if showAddTuningField {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture { showAddTuningField = false }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Add Custom Tuning")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(textPrimary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Name (e.g. Open G)", text: $newTuningName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15))
                                .foregroundStyle(textPrimary)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                // Token Display Area
                                if !newTuningTokens.isEmpty {
                                    CustomTokenWrappingHStack(tokens: $newTuningTokens, accentColor: accentColor, textPrimary: textPrimary)
                                }
                                
                                TextField("Enter Note (e.g. D3) or Hz (e.g. 146.8)", text: $newTuningInput)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 15))
                                    .foregroundStyle(textPrimary)
                                    .padding(12)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                    .onChange(of: newTuningInput) { newValue in
                                        if newValue.hasSuffix(",") || newValue.hasSuffix(" ") {
                                            processTuningInput()
                                        }
                                    }
                                    .onSubmit {
                                        processTuningInput()
                                    }
                            }
                        }
                        
                        HStack(spacing: 16) {
                            Button(action: { showAddTuningField = false }) {
                                Text("Cancel")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                // Process any remaining input before saving
                                processTuningInput()
                                
                                let freqs = newTuningTokens.compactMap { PitchDetector.frequency(from: $0, referenceA4: viewModel.referenceA4) }
                                if !newTuningName.isEmpty && !freqs.isEmpty {
                                    viewModel.addCustomTuning(name: newTuningName, frequencies: freqs)
                                    newTuningName = ""
                                    newTuningInput = ""
                                    newTuningTokens = []
                                    showAddTuningField = false
                                }
                            }) {
                                Text("Save")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(bgDark)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(accentColor)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                    .frame(width: 340)
                    .background(Color(white: 0.15))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAddTuningField)
                }
                .zIndex(2) // Ensure the popup is above everything else
            }
        }
    }
    
    // Helper to process input string into a valid token
    private func processTuningInput() {
        let cleanInput = newTuningInput.trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
        if !cleanInput.isEmpty {
            // Validate if it can be parsed
            if PitchDetector.frequency(from: cleanInput, referenceA4: viewModel.referenceA4) != nil {
                newTuningTokens.append(cleanInput.uppercased())
            }
        }
        newTuningInput = ""
    }
}

// ---------------------------------------------------------
// UI Components
// ---------------------------------------------------------

// A simple wrapping line view for tokens
struct CustomTokenWrappingHStack: View {
    @Binding var tokens: [String]
    let accentColor: Color
    let textPrimary: Color
    
    var body: some View {
        // We use a ScrollView here to prevent complex geometric layouts, ensuring horizontal overflow is scrollable
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                    HStack(spacing: 4) {
                        Text(token)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(textPrimary)
                        
                        Button(action: {
                            tokens.remove(at: index)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(textPrimary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accentColor.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(accentColor, lineWidth: 1)
                    )
                    .cornerRadius(6)
                }
            }
        }
    }
}

// Modern Button Interaction
struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Minimalist Linear Gauge
struct ModernLinearGaugeView: View {
    let cents: Double
    let accentColor: Color
    let alertColor: Color
    
    var body: some View {
        GeometryReader { geo in
            let isInTune = abs(cents) < 3.0
            let activeColor = isInTune ? accentColor : alertColor
            
            ZStack(alignment: .center) {
                // Background Track
                Capsule()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 4)
                
                // Center Notch (Perfect Pitch)
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 2, height: 20)
                
                // Active Marker Indicator (Glowing Orb)
                Circle()
                    .fill(activeColor)
                    .frame(width: 16, height: 16)
                    .shadow(color: activeColor.opacity(0.6), radius: 8)
                    // The gauge represents -50 to +50 cents across the width
                    .offset(x: CGFloat(cents / 50.0) * (geo.size.width / 2.0))
                    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: cents)
            }
            // Align to exact vertical center of the container
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
