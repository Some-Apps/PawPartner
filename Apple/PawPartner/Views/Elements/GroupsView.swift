import SwiftUI
import AlertToast
import FirebaseFirestore

struct GroupsView: View {
    var title: String
    var animals: [Animal]
    let columns: [GridItem]
    let cardViewModel: CardViewModel
//    let playcheck: (Animal) -> Bool
    let cardView: (Animal) -> CardView
    
    @State private var showLoading = false
    
    var body: some View {
        ScrollView {
            LazyVStack {
                BulkOutlineButton(viewModel: cardViewModel, animals: animals, showLoading: $showLoading)
                AnimalGridView(animals: animals, columns: columns, cardViewModel: cardViewModel, cardView: cardView)

            }
            
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        
    }
}

struct BulkOutlineButton: View {
    let viewModel: CardViewModel
    @ObservedObject var animalViewModel = AnimalViewModel.shared
    var animals: [Animal]
//    let playcheck: (Animal) -> Bool
    @Binding var showLoading: Bool
    @AppStorage("minimumDuration") var minimumDuration = 5
    @AppStorage("showAllAnimals") var showAllAnimals = false

    @State private var progress: CGFloat = 0
    @AppStorage("filterPicker") var filterPicker: Bool = false
    @AppStorage("filter") var filter: String = "No Filter"
    @State private var timer: Timer? = nil
    @State private var tickCount: CGFloat = 0
    @State private var lastEaseValue: CGFloat = 0
    @State private var isPressed: Bool = false
    @AppStorage("lastSync") var lastSync: String = ""
    @AppStorage("lastLastSync") var lastLastSync: String = ""
    @State private var feedbackPress = UIImpactFeedbackGenerator(style: .rigid)
    @State private var feedbackRelease = UIImpactFeedbackGenerator(style: .light)
    @State private var tickCountPressing: CGFloat = 0
    @State private var tickCountNotPressing: CGFloat = 75 // Starts from the end.
    
    @AppStorage("societyID") var storedSocietyID: String = ""
    @AppStorage("lastCatSync") var lastCatSync: String = ""
    @AppStorage("lastDogSync") var lastDogSync: String = ""
    @AppStorage("requireName") var requireName = false
    
    @State private var takeAllOut = false
    @State private var putAllBack = false


    let width: CGFloat = 100
    let height: CGFloat = 100
    let lineWidth: CGFloat = 25 // Adjust this value to increase the thickness of the stroke
    
    var majorityActionText: String {
        var filteredAnimals: [Animal] = []

        for animal in animals {
            if animal.canPlay {
                filteredAnimals.append(animal)
            } else if showAllAnimals {
                filteredAnimals.append(animal)
            }
        }
        let inCageCount = filteredAnimals.filter { $0.inCage }.count
        let notInCageCount = filteredAnimals.count - inCageCount
        return inCageCount > notInCageCount ? "Take Out" : "Put Back"
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.2), lineWidth: lineWidth)
                .frame(width: width, height: height)
                
            Circle()
                .trim(from: 0, to: progress)
                .stroke(majorityActionText == "Take Out" ? .orange : .blue, style: StrokeStyle(lineWidth: lineWidth))
                .frame(width: width, height: height)
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(.white)
                .scaledToFill()
                .frame(width: width, height: height)
                .clipShape(Circle())
                .scaleEffect(isPressed ? 1 : 1.025)
                .brightness(isPressed ? -0.05 : 0)
                .shadow(color: isPressed ? Color.black.opacity(0.2) : Color.black.opacity(0.5), radius: isPressed ? 0.075 : 2, x: 0.5, y: 1)
            
            Text(majorityActionText)
                .frame(width: width, height: height)
                .multilineTextAlignment(.center)
                .font(.title)
                .bold()
                .padding()
        }
        .confirmationDialog("Confirm", isPresented: $takeAllOut) {
            Button("Yes") {
                handleAnimalStateChanges()
                print(showLoading)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    print(showLoading)
                }
            }
        } message: {
            Text("You are about to take out all of the animals in the group. Are you sure you want to continue?")
        }
        .confirmationDialog("Confirm", isPresented: $putAllBack) {
            Button("Yes") {
                handleAnimalStateChanges()
            }
        } message: {
            Text("You are about to put all of the animals in the group back. Are you sure you want to continue?")
        }
        .padding(5)
        
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            if pressing {
                isPressed = true
                feedbackPress.impactOccurred()
                tickCountPressing = 0
                lastEaseValue = easeIn(t: 0)
                timer?.invalidate() // invalidate any existing timer
                timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
                    let t = tickCountPressing / 75 // total duration is now 75 ticks
                    let currentEaseValue = easeIn(t: t)
                    let increment = currentEaseValue - lastEaseValue
                    progress += increment
                    lastEaseValue = currentEaseValue
                    tickCountPressing += 1

                    if progress >= 1 {
                        timer?.invalidate()
                        progress = 0
                        print("Hold completed")
                        if majorityActionText == "Take Out" {
                            takeAllOut = true
                        } else {
                            putAllBack = true
                        }
                    } else if progress > 0.97 {
                        progress = 1
                    }
                }
            } else {
                isPressed = false
                feedbackRelease.impactOccurred()
                tickCountNotPressing = 75 // This starts decrement from the end.
                lastEaseValue = easeIn(t: 1)
                timer?.invalidate() // invalidate the current timer
                timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
                    let t = tickCountNotPressing / 75
                    let currentEaseValue = easeIn(t: t)
                    let decrement = lastEaseValue - currentEaseValue
                    progress -= decrement
                    lastEaseValue = currentEaseValue
                    tickCountNotPressing -= 1

                    if progress <= 0 {
                        progress = 0
                        timer?.invalidate() // stop the timer when progress is zero
                    }
                }
            }
        }, perform: {})
       
    }
    

    
    func handleAnimalStateChanges() {
        showLoading = true
        let db = Firestore.firestore()
        let batch = db.batch()
        
        var filteredAnimals: [Animal] = []

        for animal in animals {
            if animal.canPlay {
                filteredAnimals.append(animal)
            } else if showAllAnimals {
                filteredAnimals.append(animal)
            }
        }
        let inCageCount = filteredAnimals.filter { $0.inCage }.count
        let notInCageCount = filteredAnimals.count - inCageCount
        let majorityInCage = inCageCount > notInCageCount
        
        for animal in filteredAnimals {
            let animalRef = db.collection("Societies").document(storedSocietyID).collection("\(animal.animalType)s").document(animal.id)
            if majorityInCage {
                if animal.inCage && animal.canPlay && animal.alert.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
                    batch.updateData(["inCage": false, "startTime": Date().timeIntervalSince1970], forDocument: animalRef)
                }
            } else {
                if !animal.inCage {
                    batch.updateData(["inCage": true], forDocument: animalRef)
                    let components = Calendar.current.dateComponents([.minute], from: Date(timeIntervalSince1970: animal.startTime), to: Date())
                    if components.minute ?? 0 >= self.minimumDuration {
                        viewModel.createLog(for: animal)
                    }
                }
            }
        }
        
        batch.commit { error in
            showLoading = false
            if let error = error {
                print("Error updating animals: \(error.localizedDescription)")
            } else {
                print("Batch update successful")
            }
        }
    }

    func easeIn(t: CGFloat) -> CGFloat {
        return t * t
    }
}

