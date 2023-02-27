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
    @Environment(\.managedObjectContext) private var viewContext
    
    let openAI = OpenAISwift(authToken: "YOUR_TOKEN") //Put yout OpenAI token here
    @StateObject var speechRecognizer = SpeechRecognizer()
    @State private var latestAnswer: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Latest question: \(speechRecognizer.transcript)").padding(.bottom)
            Text("Latest answer: \(latestAnswer)")
        }
        .padding()
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
                        
                    case .failure(let error):
                        print("Error: \(error)")
                        
                    }
                }
            }
        })
        .onAppear {

            speechRecognizer.reset()
            speechRecognizer.transcribe()
        }
        .onDisappear {
            speechRecognizer.stopTranscribing()
            addItem(log: "Latest question: \(speechRecognizer.transcript)\n Latest answer: \(latestAnswer)")
        }
    }
    
    private func addItem(log: String) {
        withAnimation {
            let newItem = Chatlog(context: viewContext)
            newItem.timestamp = Date()
            newItem.log = log

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ConvoView_Previews: PreviewProvider {
    static var previews: some View {
        ConvoView()
    }
}
