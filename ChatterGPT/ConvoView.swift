//
//  ConvoView.swift
//  ChatterGPT
//
//  Created by Alex Moumoulides on 26/02/23.
//

import SwiftUI
import OpenAISwift

struct ConvoView: View {
    @Environment(\.presentationMode) var presentation
    let openAI = OpenAISwift(authToken: "YOUR_TOKEN") //Put yout OpenAI token here
    @StateObject var speechRecognizer = SpeechRecognizer()
    @State private var latestQuestion: String = ""
    @State private var latestAnswer: String = ""
    
    var body: some View {
        VStack {
            Text($latestQuestion.wrappedValue)
            Text("Latest question: \(speechRecognizer.transcript)").padding()
            Text("Latest answer: \($latestAnswer.wrappedValue)").padding()
        }
        .onChange(of: speechRecognizer.transcript, perform: { transcript in
            if transcript.hasSuffix(" Τέλος") || transcript.hasSuffix(" Τελος") || transcript.hasSuffix(" τέλος") || transcript.hasSuffix(" τελος") {
                print("End detected...executing end process")
                speechRecognizer.stopTranscribing()
                
                let aString = transcript
                let question = aString.replacingOccurrences(of: " Τέλος", with: "?", options: .literal, range: nil).replacingOccurrences(of: " τέλος", with: "?", options: .literal, range: nil).replacingOccurrences(of: " Τελος", with: "?", options: .literal, range: nil).replacingOccurrences(of: " τελος", with: "?", options: .literal, range: nil)
                
                openAI.sendCompletion(with: question, model: .gpt3(.davinci), maxTokens: 2040) { result in // Result<OpenAI, OpenAIError>
                    print(result)
                    switch result {
                    case .success(let ai):
                        latestAnswer = ai.choices.first?.text ?? ""
                        print(ai.choices)
                        print(ai.model)
                        print(ai.object)
                        
                    case .failure(let error):
                        print("Error: \(error)")
                        
                    }
                }
//                self.presentation.wrappedValue.dismiss()
            }
        })
        .onAppear {

            speechRecognizer.reset()
            speechRecognizer.transcribe()
        }
        .onDisappear {
            speechRecognizer.stopTranscribing()
//            let newHistory = History(attendees: scrum.attendees, lengthInMinutes: scrum.timer.secondsElapsed / 60, transcript: speechRecognizer.transcript)
        }
    }
}

struct ConvoView_Previews: PreviewProvider {
    static var previews: some View {
        ConvoView()
    }
}
