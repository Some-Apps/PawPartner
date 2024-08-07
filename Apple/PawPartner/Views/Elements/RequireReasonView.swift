import SwiftUI
import FirebaseFirestore

struct RequireReasonView: View {
    
    @ObservedObject var cardViewModel = CardViewModel()
    @ObservedObject var viewModel = AnimalViewModel.shared
    @ObservedObject var authViewModel = AuthenticationViewModel.shared
    @FocusState private var focusField: Bool
    let animal: Animal

    var body: some View {
        VStack {
            Text("Please select the reason you put this animal back before the minimum duration.")
            
            if authViewModel.earlyReasons.isEmpty {
                Text("No reasons available.")
                    .foregroundColor(.red)
            } else {
                Picker("Reason", selection: $cardViewModel.shortReason) {
                    Text("").tag("")
                    ForEach(authViewModel.earlyReasons, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.wheel)
            }
            
            HStack {
                Button("Nevermind") {
                    viewModel.showRequireReason = false
                    focusField = false
                    cardViewModel.shortReason = ""
                }
                .italic()
                .tint(.accentColor)
                
                Button("Submit") {
                    cardViewModel.putBack(animal: animal)
                    viewModel.showRequireReason = false
                    focusField = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        cardViewModel.shortReason = ""
                    }
                }
                .tint(.green)
                .disabled(cardViewModel.shortReason.isEmpty)
                .bold()
            }
            .buttonStyle(.bordered)
            .font(.title)
        }
        .padding()
        .frame(maxWidth: 500)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(radius: 8)
        )
        .padding()
    }
}
