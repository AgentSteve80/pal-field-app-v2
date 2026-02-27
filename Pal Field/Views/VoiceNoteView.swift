//
//  VoiceNoteView.swift
//  Pal Field
//
//  Reusable voice note recording component with speech-to-text transcription.
//
//  INFO.PLIST ENTRIES NEEDED:
//  - NSMicrophoneUsageDescription: "Pal Field needs microphone access to record voice notes on jobs."
//  - NSSpeechRecognitionUsageDescription: "Pal Field uses speech recognition to transcribe voice notes into text."
//

import SwiftUI
import AVFoundation
import Speech

class VoiceNoteRecorder: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var isTranscribing = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var transcribedText: String?
    @Published var errorMessage: String?
    @Published var currentFilePath: String?

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    // MARK: - Permissions

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { micGranted in
            guard micGranted else {
                DispatchQueue.main.async {
                    self.errorMessage = "Microphone access denied"
                    completion(false)
                }
                return
            }

            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status != .authorized {
                        self.errorMessage = "Speech recognition not authorized"
                    }
                    completion(status == .authorized)
                }
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        let filename = "voicenote_\(UUID().uuidString).m4a"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingDuration = 0
            currentFilePath = filename
            HapticManager.light()

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingDuration += 0.1
            }
        } catch {
            errorMessage = "Recording failed: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false

        guard let filePath = currentFilePath else { return }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(filePath)

        // Auto-transcribe
        transcribeAudio(url: fileURL)
    }

    // MARK: - Playback

    func playRecording(filePath: String) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(filePath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            errorMessage = "Audio file not found"
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
        } catch {
            errorMessage = "Playback failed: \(error.localizedDescription)"
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }

    // MARK: - Speech-to-Text

    private func transcribeAudio(url: URL) {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            errorMessage = "Speech recognition unavailable"
            return
        }

        isTranscribing = true
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isTranscribing = false
                if let result = result, result.isFinal {
                    self?.transcribedText = result.bestTranscription.formattedString
                    HapticManager.success()
                    print("🎙️ Transcription complete: \(result.bestTranscription.formattedString)")
                } else if let error = error {
                    print("🎙️ Transcription error: \(error.localizedDescription)")
                    // Don't show error to user — transcription is best-effort
                }
            }
        }
    }

    // MARK: - Cleanup

    func deleteRecording(filePath: String) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(filePath)
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - Voice Note View

struct VoiceNoteView: View {
    @StateObject private var recorder = VoiceNoteRecorder()
    @Binding var voiceNotePath: String?
    @Binding var notes: String
    @State private var permissionGranted = false

    var body: some View {
        VStack(spacing: 12) {
            if let path = voiceNotePath {
                // Playback mode
                HStack(spacing: 12) {
                    Button {
                        if recorder.isPlaying {
                            recorder.stopPlayback()
                        } else {
                            recorder.playRecording(filePath: path)
                        }
                    } label: {
                        Image(systemName: recorder.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }

                    Text("Voice Note")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        recorder.stopPlayback()
                        recorder.deleteRecording(filePath: path)
                        voiceNotePath = nil
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }

            if recorder.isRecording {
                // Recording indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .opacity(recorder.recordingDuration.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1.0 : 0.3)

                    Text(formatDuration(recorder.recordingDuration))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.red)

                    Spacer()

                    Button {
                        recorder.stopRecording()
                        voiceNotePath = recorder.currentFilePath
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                }
            } else if voiceNotePath == nil {
                // Record button
                Button {
                    if permissionGranted {
                        recorder.startRecording()
                    } else {
                        recorder.requestPermissions { granted in
                            permissionGranted = granted
                            if granted {
                                recorder.startRecording()
                            }
                        }
                    }
                } label: {
                    Label("Record Voice Note", systemImage: "mic.fill")
                        .font(.subheadline)
                }
            }

            if recorder.isTranscribing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Transcribing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let transcription = recorder.transcribedText {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcription:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(transcription)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .onAppear {
                    // Append transcription to notes
                    if !transcription.isEmpty {
                        if notes.isEmpty {
                            notes = transcription
                        } else {
                            notes += "\n\n[Voice Note] \(transcription)"
                        }
                    }
                }
            }

            if let error = recorder.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
