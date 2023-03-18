//
//  ConvoView.swift
//  ChatterGPT
//
//  Created by Alex Moumoulides on 26/02/23.
//

import SwiftUI
import OpenAISwift
import Charts

let numberOfSamples: Int = 12

struct BarView: View {
   // 1
    var value: CGFloat

    var body: some View {
        ZStack {
           // 2
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(gradient: Gradient(colors: [.purple, .blue]),
                                     startPoint: .top,
                                     endPoint: .bottom))
                // 3
                .frame(width: (UIScreen.main.bounds.width - CGFloat(numberOfSamples) * 4) / CGFloat(numberOfSamples), height: value)
        }
    }
}
enum Constants {
    static let updateInterval = 0.03
    static let barAmount = 40
    static let magnitudeLimit: Float = 32
}

struct ConvoView: View {
    @Environment(\.presentationMode) var presentation
    @Environment(\.managedObjectContext) private var viewContext
    
    let timer = Timer.publish(
            every: Constants.updateInterval,
            on: .main,
            in: .common
        ).autoconnect()
    let openAI = OpenAISwift(authToken: "your-token") //Put yout OpenAI token here
    @StateObject var speechRecognizer = SpeechRecognizer()
    @State private var latestAnswer: String = ""
    
    @State var data: [Float] = Array(repeating: 0, count: Constants.barAmount)
            .map { _ in Float.random(in: 1 ... Constants.magnitudeLimit) }
    
    @State var isAsking: Bool = false
    
    private func normalizeSoundLevel(level: Float) -> CGFloat {
        let level = max(0.2, CGFloat(level) + 50) / 2 // between 0.1 and 25
        return CGFloat(level * (500 / 25)) // scaled to max at 300 (our height of our bar)
    }
    
    var body: some View {
        
        VStack(alignment: .center) {
            Toggle("Asking question:", isOn: $isAsking)
            VStack(alignment: .center) {
                
                if #available(iOS 16.0, *) {
                    Chart(Array(data.enumerated()), id: \.0) { index, magnitude in
                        BarMark(
                            x: .value("Frequency", String(index)),
                            y: .value("Magnitude", magnitude)
                        )
                        .foregroundStyle(
                            Color(
                                hue: 0.3 - Double((magnitude / Constants.magnitudeLimit) / 5),
                                saturation: 1,
                                brightness: 1,
                                opacity: 0.7
                            )
                        )
                    }
                    .onReceive(timer, perform: updateData)
                    .chartYScale(domain: 0 ... Constants.magnitudeLimit)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                } else {
                    HStack(spacing: 4) {
                        ForEach(speechRecognizer.fftMagnitudes, id: \.hashValue) { level in
                            BarView(value: self.normalizeSoundLevel(level: level))
                        }
                    }.frame(alignment: .top)
                }
            }
            .padding()
            Text("Latest question: \(speechRecognizer.transcript)").padding(.bottom)
            Text("Latest answer: \(latestAnswer)")
        }
        .padding()
        .onChange(of: isAsking, perform: { isAsking in
            if isAsking {
               speechRecognizer.reset()
               speechRecognizer.transcribe()
            } else {
                speechRecognizer.stopTranscribing()
                print("End detected...executing end process")
                
                let aString = speechRecognizer.transcript
                let question = aString + "?"
                
                openAI.sendCompletion(with: question, model: .gpt3(.davinci), maxTokens: 2040) { result in // Result<OpenAI, OpenAIError>
                    print(result)
                    switch result {
                    case .success(let ai):
                        latestAnswer = ai.choices.first?.text ?? ""
                        
                    case .failure(let error):
                        print("Error: \(error)")
                        latestAnswer = error.localizedDescription
                    }
                }
            }
        })
        .onDisappear {
            speechRecognizer.stopTranscribing()
            addItem(log: "Latest question: \(speechRecognizer.transcript)\n Latest answer: \(latestAnswer)")
        }
    }
    
    func updateData(_: Date) {
        withAnimation(.easeOut(duration: 0.08)) {
            data = speechRecognizer.fftMagnitudes.map {
                        min($0, Constants.magnitudeLimit)
            }
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
