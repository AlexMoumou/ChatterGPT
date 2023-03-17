/*
See SpeechRecognizerLicense.txt file for this sample’s licensing information.
*/

import AVFoundation
import Foundation
import Speech
import SwiftUI
import Accelerate

/// A helper for transcribing speech to text using SFSpeechRecognizer and AVAudioEngine.
class SpeechRecognizer: ObservableObject {
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }
    
    @Published var transcript: String = ""
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    private let bufferSize = 1024
    
    @Published var fftMagnitudes: [Float] = []
    
    /**
     Initializes a new speech recognizer. If this is the first time you've used the class, it
     requests access to the speech recognizer and the microphone.
     */
    init() {
        recognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "el-GR"))
        
        Task(priority: .background) {
            do {
                guard recognizer != nil else {
                    throw RecognizerError.nilRecognizer
                }
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                    throw RecognizerError.notPermittedToRecord
                }
            } catch {
                speakError(error)
            }
        }
    }
    
    deinit {
        reset()
    }
    
    /**
        Begin transcribing audio.
     
        Creates a `SFSpeechRecognitionTask` that transcribes speech to text until you call `stopTranscribing()`.
        The resulting transcription is continuously written to the published `transcript` property.
     */
    func transcribe() {
        DispatchQueue(label: "Speech Recognizer Queue", qos: .background).async { [weak self] in
            guard let self = self, let recognizer = self.recognizer, recognizer.isAvailable else {
                self?.speakError(RecognizerError.recognizerIsUnavailable)
                return
            }
            
            do {
                let (audioEngine, request) = try self.prepareEngine()
                self.audioEngine = audioEngine
                self.request = request
                self.task = recognizer.recognitionTask(with: request, resultHandler: self.recognitionHandler(result:error:))
            } catch {
                self.reset()
                self.speakError(error)
            }
        }
    }
    
    /// Stop transcribing audio.
    func stopTranscribing() {
        reset()
    }
    
    /// Reset the speech recognizer.
    func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
    }
    
    private func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        
        let fftSetup = vDSP_DFT_zop_CreateSetup(nil, UInt(1024), vDSP_DFT_Direction.FORWARD)
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            request.append(buffer)
            let channelData = buffer.floatChannelData?[0]
            DispatchQueue.main.async {
                self.fftMagnitudes = self.fft(data: channelData!, setup: fftSetup!)
            }
        }
        audioEngine.prepare()
        try audioEngine.start()
        
        return (audioEngine, request)
    }
    
    func fft(data: UnsafeMutablePointer<Float>, setup: OpaquePointer) -> [Float] {
        var realIn = [Float](repeating: 0, count: bufferSize)
        var imagIn = [Float](repeating: 0, count: bufferSize)
        var realOut = [Float](repeating: 0, count: bufferSize)
        var imagOut = [Float](repeating: 0, count: bufferSize)
            
        for i in 0 ..< bufferSize {
            realIn[i] = data[i]
        }
        
        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
        
        var magnitudes = [Float](repeating: 0, count: Constants.barAmount)
        
        realOut.withUnsafeMutableBufferPointer { realBP in
            imagOut.withUnsafeMutableBufferPointer { imagBP in
                var complex = DSPSplitComplex(realp: realBP.baseAddress!, imagp: imagBP.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, UInt(Constants.barAmount))
            }
        }
        
        var normalizedMagnitudes = [Float](repeating: 0.0, count: Constants.barAmount)
        var scalingFactor = Float(1)
        vDSP_vsmul(&magnitudes, 1, &scalingFactor, &normalizedMagnitudes, 1, UInt(Constants.barAmount))
            
        return normalizedMagnitudes
    }
    
    private func recognitionHandler(result: SFSpeechRecognitionResult?, error: Error?) {
        let receivedFinalResult = result?.isFinal ?? false
        let receivedError = error != nil
        
        if receivedFinalResult || receivedError {
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        
        if let result = result {
            speak(result.bestTranscription.formattedString)
        }
    }
    
    private func speak(_ message: String) {
        transcript = message
    }
    
    private func speakError(_ error: Error) {
        var errorMessage = ""
        if let error = error as? RecognizerError {
            errorMessage += error.message
        } else {
            errorMessage += error.localizedDescription
        }
        transcript = "<< \(errorMessage) >>"
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
