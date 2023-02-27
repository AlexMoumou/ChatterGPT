//
//  ContentView.swift
//  ChatterGPT
//
//  Created by Alex Moumoulides on 26/02/23.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Chatlog.timestamp, ascending: true)],
        animation: .default)
    private var logs: FetchedResults<Chatlog>
    
    @State private var isPresentingConvoView = false

    var body: some View {
        NavigationView {
            List {
                ForEach(logs) { log in
                    NavigationLink {
                        VStack(alignment: .center) {
                            Text("Log at \(log.timestamp!, formatter: itemFormatter)").padding(.bottom)
                            Text("\(log.log!)")
                        }.padding()
                    } label: {
                        Text(log.timestamp!, formatter: itemFormatter)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem {
                    Button(action: { isPresentingConvoView = !isPresentingConvoView }) {
                        Label("Start Convo", systemImage: "person.wave.2.fill")
                    }
                }
            }
            .sheet(isPresented: $isPresentingConvoView) {
                NavigationView {
                    ConvoView()
                        .navigationTitle("Convo in progress...")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    isPresentingConvoView = false
                                }
                            }
                        }
                }
            }
            Text("Select a log")
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

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { logs[$0] }.forEach(viewContext.delete)

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

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
