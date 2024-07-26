import SwiftUI
import Combine
import FirebaseAuth
import AlertToast
import Kingfisher
import WebKit
import UIKit

struct AnimalView: View {
    // MARK: - Properties
    @StateObject var cardViewModel = CardViewModel()
    @AppStorage("minimumDuration") var minimumDuration = 5

    @ObservedObject var authViewModel = AuthenticationViewModel.shared
    @ObservedObject var viewModel = AnimalViewModel.shared
    @ObservedObject var settingsViewModel = SettingsViewModel.shared
    @AppStorage("showAllAnimals") var showAllAnimals = false
    @AppStorage("secondarySortOption") var secondarySortOption = ""

    @AppStorage("filterPicker") var filterPicker: Bool = false
    @AppStorage("filter") var filter: String = "No Filter"
    @AppStorage("lastSync") var lastSync: String = ""
    @AppStorage("lastCatSync") var lastCatSync: String = ""
    @AppStorage("lastDogSync") var lastDogSync: String = ""
    @AppStorage("latestVersion") var latestVersion: String = ""
    @AppStorage("updateAppURL") var updateAppURL: String = ""
    @AppStorage("feedbackURL") var feedbackURL: String = ""
    @AppStorage("reportProblemURL") var reportProblemURL: String = ""
    @AppStorage("animalType") var animalType = AnimalType.Cat
    @AppStorage("animalMode") var animalMode = "volunteer"
    @AppStorage("volunteerVideo") var volunteerVideo: String = ""
    @AppStorage("donationURL") var donationURL: String = ""
    @AppStorage("cardsPerPage") var cardsPerPage = 30
    @AppStorage("groupOption") var groupOption = ""
    @AppStorage("adminMode") var adminMode = true
    @AppStorage("showFilterOptions") var showFilterOptions = false

    @State private var filteredCatsList: [Animal] = []
    @State private var filteredDogsList: [Animal] = []
    @State private var finalFilterCategory = "None"
    @State private var finalFilterSelections: Set<String> = []
    @State private var searchQuery = ""
    @State private var showAnimalAlert = false
    @State private var screenWidth: CGFloat = 500
    @State private var isImageLoaded = false
    @State private var shouldPresentAnimalAlert = false
    @State private var shouldPresentThankYouView = false
    @State private var showingFeedbackForm = false
    @State private var showingReportForm = false
    @State private var showTutorialQRCode = false
    @State private var showingPasswordPrompt = false
    @State private var passwordInput = ""
    @State private var showIncorrectPassword = false
    @State private var showDonateQRCode = false
    @State private var isFilterOptionsExpanded = false

    @FocusState private var focusField: Bool

    @State private var searchQueryFinished = ""
    @State private var selectedFilterAttribute = "Name"
    @State private var isSearching = false

    @AppStorage("expandedGroupsStorageCats") private var expandedGroupsStorageCats: String = ""
    @AppStorage("expandedGroupsStorageeDogs") private var expandedGroupsStorageDogs: String = ""
    @State private var expandedGroupsCats: Set<String> = []
    @State private var expandedGroupsDogs: Set<String> = []

    @State private var currentPage = 1

    let columns = [
        GridItem(.adaptive(minimum: 330))
    ]

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "Unknown Version"
    }

    var buildNumber: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return build
        }
        return "Unknown Build"
    }
    
    var filterSelectionOptions: [String] {
        var options: [String] = []
        
        var animals: [Animal]
        if animalType == .Cat {
            animals = viewModel.sortedCats
        } else {
            animals = viewModel.sortedDogs
        }
        
        if finalFilterCategory == "Color" {
            for animal in animals {
                if let colorGroup = animal.colorGroup, !options.contains(colorGroup) {
                    options.append(colorGroup)
                }
            }
        } else if finalFilterCategory == "Building" {
            for animal in animals {
                if let buildingGroup = animal.buildingGroup, !options.contains(buildingGroup) {
                    options.append(buildingGroup)
                }
            }
        } else if finalFilterCategory == "Behavior" {
            for animal in animals {
                if let behaviorGroup = animal.behaviorGroup, !options.contains(behaviorGroup) {
                    options.append(behaviorGroup)
                }
            }
        }
        
        print("Filter options for category \(finalFilterCategory): \(options)")
        return options
    }
    
    var filterTitle: String {
        var title = ""
        if finalFilterCategory != "None" {
            title += "\(finalFilterCategory)"
            if !finalFilterSelections.isEmpty {
                let selections = finalFilterSelections.sorted().joined(separator: " or ")
                title += " is \(selections)"
            }
        }
        return title
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    HStack {
                        Button {
                            showingFeedbackForm = true
                        } label: {
                            HStack {
                                Image(systemName: "text.bubble.fill")
                                Text("Give Feedback")
                            }
                        }
                        .sheet(isPresented: $showingFeedbackForm) {
                            if let feedbackURL = URL(string: "\(feedbackURL)/?societyid=\(authViewModel.shelterID)") {
                                WebView(url: feedbackURL)
                            }
                        }
                        Spacer()

                        if !adminMode && authViewModel.accountType == "admin" {
                            Button("Switch To Admin") {
                                showingPasswordPrompt = true
                            }
                            .sheet(isPresented: $showingPasswordPrompt) {
                                PasswordPromptView(isShowing: $showingPasswordPrompt, passwordInput: $passwordInput, showIncorrectPassword: $showIncorrectPassword) {
                                    authViewModel.verifyPassword(password: passwordInput) { isCorrect in
                                        if isCorrect {
                                            adminMode = true
                                        } else {
                                            print("Incorrect Password")
                                            showIncorrectPassword.toggle()
                                            passwordInput = ""
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }

                        Button {
                            showingReportForm = true
                        } label: {
                            HStack {
                                Text("Report Problem")
                                Image(systemName: "exclamationmark.bubble.fill")
                            }
                        }
                        .sheet(isPresented: $showingReportForm) {
                            if let reportProblemURL = URL(string: "\(reportProblemURL)/?societyid=\(authViewModel.shelterID)") {
                                WebView(url: reportProblemURL)
                            }
                        }
                    }
                    .padding([.horizontal, .top])
                    .font(UIDevice.current.userInterfaceIdiom == .phone ? .caption : .body)

                    CollapsibleSection(searchQuery: $searchQuery, searchQueryFinished: $searchQueryFinished, selectedFilterAttribute: $selectedFilterAttribute, isSearching: $isSearching, onSearch: {
                        updateFilteredAnimals()
                        currentPage = 1 // Reset to page 1 only when a new search is performed
                    })

                    if !(viewModel.dogs.isEmpty || viewModel.cats.isEmpty) {
                        Picker("Animal Type", selection: $animalType) {
                            Text("Cats").tag(AnimalType.Cat)
                            Text("Dogs").tag(AnimalType.Dog)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding([.horizontal, .top])
                        .onChange(of: animalType) { newValue in
                            print("Animal type changed to: \(newValue)")
                            UserDefaults.standard.set(newValue.rawValue, forKey: "animalType")
                            updateFilteredAnimals()
                            currentPage = 1 // Reset to page 1 when animal type is changed
                            print(filteredCatsList.count)
                        }
                    }
                    
                    if !searchQueryFinished.isEmpty {
                        Text("Results for: \(selectedFilterAttribute) contains \(searchQueryFinished)")
                            .bold()
                            .foregroundStyle(.red)
                            .padding()

                    }
                    if showFilterOptions {
                        DisclosureGroup(isExpanded: $isFilterOptionsExpanded) {
                            AnimalFilterView(finalFilterCategory: $finalFilterCategory, finalFilterSelections: $finalFilterSelections, currentPage: $currentPage, animals: animalType == .Cat ? viewModel.sortedCats : viewModel.sortedDogs)
                        } label: {
                            HStack {
                                Text("User Filter: ")
                                    .bold()
                                Text(filterTitle)
                            }
                            .foregroundStyle(Color(uiColor: .systemGray))
                            .font(.title2)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 20).fill(.regularMaterial))
                        .padding()
                        .onChange(of: finalFilterSelections) { _ in
                            updateFilteredAnimals()
                        }
                    }
                    if animalType == .Cat ? (!viewModel.sortedCats.isEmpty) : (!viewModel.sortedDogs.isEmpty) {
                        PageNavigationElement(currentPage: $currentPage, totalPages: totalPages(animalType == .Cat ? filteredCatsList : filteredDogsList))
                    }
                    switch animalType {
                    case .Dog:
                        if groupOption == "" {
                            AnimalGridView(
                                allAnimals: viewModel.dogs,
                                animals: paginatedAnimals(filteredDogsList),

                                columns: columns,
                                cardViewModel: cardViewModel,
                                cardView: { CardView(animal: $0, showAnimalAlert: $showAnimalAlert, viewModel: cardViewModel) }
                            )
                        } else {
                            GroupAnimalGridView(
                                species: animalType.rawValue,
                                allAnimals: viewModel.dogs,
                                animals: paginatedAnimals(filteredDogsList),

                                columns: columns,
                                cardViewModel: cardViewModel,
                                cardView: { CardView(animal: $0, showAnimalAlert: $showAnimalAlert, viewModel: cardViewModel) }, expandedGroups: $expandedGroupsDogs
                            )
                        }
                    case .Cat:
                        if groupOption == "" {
                            AnimalGridView(
                                allAnimals: viewModel.cats,
                                animals: paginatedAnimals(filteredCatsList),

                                columns: columns,
                                cardViewModel: cardViewModel,
                                cardView: { CardView(animal: $0, showAnimalAlert: $showAnimalAlert, viewModel: cardViewModel) }
                            )
                        } else {
                            GroupAnimalGridView(
                                species: animalType.rawValue,
                                allAnimals: viewModel.cats,
                                animals: paginatedAnimals(filteredCatsList),

                                columns: columns,
                                cardViewModel: cardViewModel,
                                cardView: { CardView(animal: $0, showAnimalAlert: $showAnimalAlert, viewModel: cardViewModel) }, expandedGroups: $expandedGroupsCats
                            )
                        }
                    }

                    if animalType == .Cat ? (!viewModel.sortedCats.isEmpty) : (!viewModel.sortedDogs.isEmpty) {
                        PageNavigationElement(currentPage: $currentPage, totalPages: totalPages(animalType == .Cat ? filteredCatsList : filteredDogsList))

                        if authViewModel.accountType == "Admin" {
                            Button {
                                showTutorialQRCode = true
                            } label: {
                                HStack {
                                    Image(systemName: "qrcode")
                                    Text("Tutorials")
                                }
                                .padding()
                                .fontWeight(.black)
                            }
                        } else {
                            Link(destination: URL(string: "https://shelterpartner.org/tutorials")!) {
                                Label("Tutorials", systemImage: "globe")
                            }

                        }
                    }

                    Image("textLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 100)
                        .id("bottom")  // Identifier for scroll-to-bottom

                }
            }

            .overlay(
                AnimalAlertView(animal: viewModel.animal)
                    .opacity(viewModel.showAnimalAlert ? 1 : 0)
            )
        }
        .onChange(of: lastSync) { sync in
            let cache = KingfisherManager.shared.cache
            try? cache.diskStorage.removeAll()
            cache.memoryStorage.removeAll()
            print("Cache removed")
        }
        .onChange(of: viewModel.showLogCreated) { newValue in
            if newValue {
                self.shouldPresentThankYouView = true
            } else {
                self.isImageLoaded = false
                self.shouldPresentThankYouView = false
            }
        }
        .onChange(of: expandedGroupsCats) { newValue in
            expandedGroupsStorageCats = newValue.joined(separator: ",")
            updateFilteredAnimals()
        }

        .onChange(of: expandedGroupsDogs) { newValue in
            expandedGroupsStorageDogs = newValue.joined(separator: ",")
            updateFilteredAnimals()
        }

        .onChange(of: isImageLoaded) { _ in
            updatePresentationState()
        }
        .onChange(of: viewModel.showAddNote) { _ in
            print(viewModel.showAddNote)
        }
        .onDisappear {
            viewModel.removeListeners()
        }
        .onAppear {
            expandedGroupsCats = Set(expandedGroupsStorageCats.split(separator: ",").map { String($0) })
            expandedGroupsDogs = Set(expandedGroupsStorageDogs.split(separator: ",").map { String($0) })

            if viewModel.cats.isEmpty {
                animalType = .Dog
            } else if viewModel.dogs.isEmpty {
                animalType = .Cat
            }
            if authViewModel.filterOptions.isEmpty {
                filterPicker = false
            }
            if authViewModel.shelterID == "" && Auth.auth().currentUser?.uid != nil {
                viewModel.fetchSocietyID(forUser: Auth.auth().currentUser!.uid) { (result) in
                    switch result {
                    case .success(let id):
                        authViewModel.shelterID = id
                        viewModel.listenForSocietyLastSyncUpdate(societyID: id)
                    case .failure(let error):
                        print(error)
                    }
                }
            }
            viewModel.fetchCatData { _ in
                updateFilteredAnimals() // Ensure initial animals are displayed
            }
            viewModel.fetchDogData { _ in
                updateFilteredAnimals() // Ensure initial animals are displayed
            }
            viewModel.fetchLatestVersion()
            if authViewModel.shelterID.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                viewModel.postAppVersion(societyID: authViewModel.shelterID, installedVersion: "\(appVersion) (\(buildNumber))")
            }
        }
        .present(isPresented: $shouldPresentThankYouView, type: .alert, duration: 60, closeOnTap: false) {
            ThankYouView(animal: viewModel.animal)
        }
        .toast(isPresenting: $showIncorrectPassword) {
            AlertToast(type: .error(.red), title: "Incorrect Password")
        }
        .toast(isPresenting: $viewModel.toastAddNote) {
            AlertToast(type: .complete(.green), title: "Note added!")
        }
        .toast(isPresenting: $isSearching) {
            AlertToast(displayMode: .alert, type: .loading, title: "Searching")
        }
        .sheet(isPresented: $viewModel.showQRCode) {
            QRCodeView(animal: viewModel.animal)
        }
        .sheet(isPresented: $showTutorialQRCode) {
            Image(uiImage: generateQRCode(from: "https://shelterpartner.org/tutorials"))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 500)
        }
        .present(isPresented: $viewModel.showRequireName, type: .alert, duration: 60, closeOnTap: false, closeOnTapOutside: false) {
            RequireNameView(animal: viewModel.animal)
        }
        .present(isPresented: $viewModel.showRequireReason, type: .alert, duration: 60, closeOnTap: false, closeOnTapOutside: false) {
            RequireReasonView(animal: viewModel.animal)
        }
        .present(isPresented: $viewModel.showRequireLetOutType, type: .alert, duration: 60, closeOnTap: false, closeOnTapOutside: false) {
            RequireLetOutTypeView(animal: viewModel.animal)
        }
        .sheet(isPresented: $viewModel.showAddNote) {
            AddNoteView(animal: viewModel.animal)
        }
    }

    private func updatePresentationState() {
        shouldPresentThankYouView = viewModel.showLogCreated && isImageLoaded
    }
    
    private func updateFilteredAnimals() {
        let searchQueryMatches: (Animal) -> Bool = { animal in
            searchQueryFinished.isEmpty || animal.matchesSearch(query: searchQueryFinished, attribute: selectedFilterAttribute)
        }

        let filterCategoryMatches: (Animal) -> Bool = { animal in
            finalFilterCategory == "None" || finalFilterSelections.isEmpty ||
            (finalFilterCategory == "Color" && finalFilterSelections.contains(animal.colorGroup ?? "")) ||
            (finalFilterCategory == "Building" && finalFilterSelections.contains(animal.buildingGroup ?? "")) ||
            (finalFilterCategory == "Behavior" && finalFilterSelections.contains(animal.behaviorGroup ?? ""))
        }

        filteredCatsList = viewModel.sortedGroupCats.filter { animal in
            let group = groupOption == "Color" ? (animal.colorGroup ?? "Unknown Group") :
                        groupOption == "Building" ? (animal.buildingGroup ?? "Unknown Group") :
                        groupOption == "Behavior" ? (animal.behaviorGroup ?? "Unknown Group") : "Unknown Group"
            
            let isInExpandedGroup = expandedGroupsCats.contains(group)

            return isInExpandedGroup && searchQueryMatches(animal) && filterCategoryMatches(animal)
        }

        filteredDogsList = viewModel.sortedGroupDogs.filter { animal in
            let group = groupOption == "Color" ? (animal.colorGroup ?? "Unknown Group") :
                        groupOption == "Building" ? (animal.buildingGroup ?? "Unknown Group") :
                        groupOption == "Behavior" ? (animal.behaviorGroup ?? "Unknown Group") : "Unknown Group"
            
            let isInExpandedGroup = expandedGroupsDogs.contains(group)

            return isInExpandedGroup && searchQueryMatches(animal) && filterCategoryMatches(animal)
        }

        // Ensure each group has at least one placeholder animal if it is empty
        func addPlaceholderAnimalIfEmpty(filteredAnimals: inout [Animal], sortedGroupAnimals: [Animal]) {
            let groups = Set(sortedGroupAnimals.map { animal in
                groupOption == "Color" ? (animal.colorGroup ?? "Unknown Group") :
                groupOption == "Building" ? (animal.buildingGroup ?? "Unknown Group") :
                groupOption == "Behavior" ? (animal.behaviorGroup ?? "Unknown Group") : "Unknown Group"
            })

            for group in groups {
                if !filteredAnimals.contains(where: { animal in
                    (groupOption == "Color" && animal.colorGroup == group) ||
                    (groupOption == "Building" && animal.buildingGroup == group) ||
                    (groupOption == "Behavior" && animal.behaviorGroup == group)
                }) {
                    var placeholderAnimal = Animal.dummyAnimal // Create a placeholder animal as per your implementation
                    placeholderAnimal.name = "placeholderanimal"
                    switch groupOption {
                    case "Color":
                        placeholderAnimal.colorGroup = group
                    case "Building":
                        placeholderAnimal.buildingGroup = group
                    case "Behavior":
                        placeholderAnimal.behaviorGroup = group
                    default:
                        placeholderAnimal.colorGroup = group
                    }
                    filteredAnimals.append(placeholderAnimal)
                }
            }
        }

        addPlaceholderAnimalIfEmpty(filteredAnimals: &filteredCatsList, sortedGroupAnimals: viewModel.sortedGroupCats)
        addPlaceholderAnimalIfEmpty(filteredAnimals: &filteredDogsList, sortedGroupAnimals: viewModel.sortedGroupDogs)

        // Remove placeholder animals if there are other animals in the group
        func removePlaceholderIfNecessary(filteredAnimals: inout [Animal]) {
            var groupsToRemovePlaceholder: Set<String> = []

            for animal in filteredAnimals {
                let group = groupOption == "Color" ? (animal.colorGroup ?? "Unknown Group") :
                            groupOption == "Building" ? (animal.buildingGroup ?? "Unknown Group") :
                            groupOption == "Behavior" ? (animal.behaviorGroup ?? "Unknown Group") : "Unknown Group"

                if animal.name != "placeholderanimal" {
                    groupsToRemovePlaceholder.insert(group)
                }
            }

            filteredAnimals.removeAll { animal in
                let group = groupOption == "Color" ? (animal.colorGroup ?? "Unknown Group") :
                            groupOption == "Building" ? (animal.buildingGroup ?? "Unknown Group") :
                            groupOption == "Behavior" ? (animal.behaviorGroup ?? "Unknown Group") : "Unknown Group"

                return animal.name == "placeholderanimal" && groupsToRemovePlaceholder.contains(group)
            }
        }

        removePlaceholderIfNecessary(filteredAnimals: &filteredCatsList)
        removePlaceholderIfNecessary(filteredAnimals: &filteredDogsList)

        // Ensure pagination is consistent
        let allFilteredAnimals: [Animal] = animalType == .Cat ? filteredCatsList : filteredDogsList
        let totalPageCount = totalPages(allFilteredAnimals)
        currentPage = min(currentPage, max(1, totalPageCount))
    }






    private func totalPages(_ animals: [Animal]) -> Int {
        let animalCount = animals.count
        let pages = Double(animalCount) / Double(cardsPerPage)
        return max(1, Int(ceil(pages)))
    }

    private func paginatedAnimals(_ animals: [Animal]) -> [Animal] {
        let startIndex = max(0, (currentPage - 1) * cardsPerPage)
        let endIndex = min(startIndex + cardsPerPage, animals.count)

        guard startIndex < animals.count else {
            print("Start index \(startIndex) out of bounds for array of size \(animals.count)")
            return []
        }
        return Array(animals[startIndex..<endIndex])
    }

    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")

        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

struct AnimalGridView<Animal>: View where Animal: Identifiable {
    let allAnimals: [Animal]
    let animals: [Animal]
    let columns: [GridItem]
    let cardViewModel: CardViewModel
    let cardView: (Animal) -> CardView

    var body: some View {
        if allAnimals.isEmpty {
            VStack {
                ProgressView()
            }
            .frame(maxWidth: .infinity)
        } else {
            LazyVGrid(columns: columns) {
                ForEach(animals, id: \.id) { animal in
                    cardView(animal)
                        .padding(2)
                }
            }
            .padding()
        }
    }
}

struct GroupAnimalGridView: View {
    let species: String
    let allAnimals: [Animal]
    let animals: [Animal]
    let columns: [GridItem]
    let cardViewModel: CardViewModel
    let cardView: (Animal) -> CardView
    @Binding var expandedGroups: Set<String>
    @AppStorage("groupOption") var groupOption = ""

    var body: some View {
        if allAnimals.isEmpty {
            VStack {
                ProgressView()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(groupAnimals().sorted(by: { $0.key < $1.key }), id: \.key) { group, animals in
                        Section(
                            header: NavigationLink {
                                GroupsView(species: species, groupCategory: groupOption, groupSelection: group, columns: columns, cardViewModel: cardViewModel, cardView: cardView)
                            } label: {
                                HStack {
                                    Text(group)
                                    Button {
                                        if expandedGroups.contains(group) {
                                            expandedGroups.remove(group)
                                        } else {
                                            expandedGroups.insert(group)
                                        }
                                    } label: {
                                        Image(systemName: expandedGroups.contains(group) ? "chevron.down" : "chevron.right")
                                    }
                                }
                                .foregroundStyle(.black)
                                .fontWeight(.bold)
                                .font(.title)
                                .padding([.leading, .trailing, .top])
                            }
                        ) {
                            if expandedGroups.contains(group) {
                                LazyVGrid(columns: columns) {
                                    ForEach(animals, id: \.id) { animal in
                                        cardView(animal)
                                            .padding(2)
                                    }
                                }
                                .padding(.horizontal)
                                .id(animals)  // Force UI update
                            }
                        }
                    }
                }
            }
        }
    }

    private func groupAnimals() -> [String: [Animal]] {
        let groupedAnimals: [String: [Animal]]
        switch groupOption {
        case "Color":
            groupedAnimals = Dictionary(grouping: animals, by: { $0.colorGroup ?? "Unknown Group" })
        case "Building":
            groupedAnimals = Dictionary(grouping: animals, by: { $0.buildingGroup ?? "Unknown Group" })
        case "Behavior":
            groupedAnimals = Dictionary(grouping: animals, by: { $0.behaviorGroup ?? "Unknown Group" })
        default:
            groupedAnimals = Dictionary(grouping: animals, by: { _ in "Unknown Group" })
        }

        // Ensure all groups are included
        let allGroups: Set<String> = Set(groupedAnimals.keys).union(
            Set(animals.compactMap { animal in
                switch groupOption {
                case "Color":
                    return animal.colorGroup ?? "Unknown Group"
                case "Building":
                    return animal.buildingGroup ?? "Unknown Group"
                case "Behavior":
                    return animal.behaviorGroup ?? "Unknown Group"
                default:
                    return "Unknown Group"
                }
            })
        )

        var result: [String: [Animal]] = [:]
        for group in allGroups.sorted() {
            result[group] = groupedAnimals[group] ?? []
        }

        return result
    }
}


struct CollapsibleSection: View {
    @State private var isExpanded: Bool = false
    @Binding var searchQuery: String
    @Binding var searchQueryFinished: String
    @Binding var selectedFilterAttribute: String
    @Binding var isSearching: Bool
    
    let filterAttributes = ["Name", "Location", "Notes", "Breed"]
    let onSearch: () -> Void

    @AppStorage("groupOption") var groupOption = ""
    @AppStorage("groupsFullyEnabled") var groupsFullyEnabled = false
    @AppStorage("showSearchBar") var showSearchBar = false


    @ObservedObject var settingsViewModel = SettingsViewModel.shared

    var body: some View {
        VStack {
            Button(action: {
                withAnimation {
                    resignFirstResponder()
                    isExpanded.toggle()
                }
            }) {
                if showSearchBar {
                    HStack {
                        Text("Additional Options")
                            .foregroundStyle(.black)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                }
            }

            if isExpanded {

                Form {
                    Section {
                        HStack {
                            TextField("Search", text: $searchQuery)
                            Picker("", selection: $selectedFilterAttribute) {
                                ForEach(filterAttributes, id: \.self) { attribute in
                                    Text(attribute).tag(attribute)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedFilterAttribute) { filter in
                                isSearching = true
                                isSearching = false
                                searchQueryFinished = searchQuery
                                onSearch()
                            }
                        }
                    }
                    Section {
                            Button("Search") {
                                resignFirstResponder()
                                isSearching = true
                                isSearching = false
                                searchQueryFinished = searchQuery
                                onSearch()
                            }
                            Button("Reset") {
                                resignFirstResponder()
                                searchQuery = ""
                                searchQueryFinished = ""
                                onSearch()
                            }
                        }
                    }
                .frame(height: 200)
                .overlay(
                    VStack {
                        Spacer()
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.15)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 25)
                    }
                        .allowsHitTesting(false)
                )
            }
        }
        .padding([.horizontal, .top])
    }
    
    private func resignFirstResponder() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension Animal {
    func matchesSearch(query: String, attribute: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        switch attribute {
        case "Name":
            return self.name.lowercased().contains(lowercasedQuery)
        case "Location":
            return self.fullLocation?.lowercased().contains(lowercasedQuery) ?? self.location.lowercased().contains(lowercasedQuery)
        case "Notes":
            var allNotes = ""
            for note in self.notes {
                if note.note == "Added animal to the app" {
                    continue
                }
                allNotes.append("\(note.note) ")
            }
            return allNotes.lowercased().contains(lowercasedQuery)
        case "Breed":
            if let breed = breed {
                return breed.lowercased().contains(lowercasedQuery)
            } else {
                return false
            }
        default:
            return false
        }
    }
}


@propertyWrapper
struct UserDefaultSetString: DynamicProperty {
    let key: String
    let defaultValue: Set<String>

    var wrappedValue: Set<String> {
        get {
            let savedString = UserDefaults.standard.string(forKey: key) ?? ""
            let items = savedString.split(separator: ",").map { String($0) }
            return Set(items)
        }
        set {
            let savedString = newValue.joined(separator: ",")
            UserDefaults.standard.set(savedString, forKey: key)
        }
    }

    init(key: String, defaultValue: Set<String> = []) {
        self.key = key
        self.defaultValue = defaultValue
    }
}
