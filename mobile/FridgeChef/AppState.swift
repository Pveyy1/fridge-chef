import SwiftUI
import Observation

enum Stage {
    case snap, review, menu, recipe, card
}

@Observable
final class AppState {
    var stage: Stage = .snap

    var photos: [UIImage] = []

    var detection: Detection = .empty
    var unsureChoice: [String: String] = [:]
    var unsureOther: [String: String] = [:]
    var selected: Set<String> = []
    var chipOrder: [String] = []
    var extraText: String = ""
    var dietaryNotes: String = ""

    var mealType: String = ""
    var people: Int = 2
    var flavors: Set<String> = []
    var guidance: String = ""

    static let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack", "Dessert"]
    static let flavorOptions = ["Savory", "Salty", "Sweet", "Spicy", "Fresh & light", "Comfort food", "High protein"]

    var mealWord: String { mealType.isEmpty ? "eat" : mealType.lowercased() }
    var courseLabel: String {
        switch mealType {
        case "Dessert": return "DESSERT"
        case "Snack": return "SMALL PLATE"
        case "Breakfast": return "BREAKFAST"
        case "Lunch": return "LUNCH"
        default: return "MAIN COURSE"
        }
    }
    var whenLabel: String {
        ["Breakfast", "Lunch", "Snack"].contains(mealType) ? "TODAY AT" : "TONIGHT AT"
    }

    var dishes: [Dish] = []
    var chosen: Dish?
    var checkedSteps: Set<Int> = []

    var isLoading = false
    var loadingText = ""
    var errorMessage: String?

    static let defaultServerURL = "https://fridge-chef-22i8.onrender.com"

    private static let urlKey = "serverURL.v2"

    var serverURL: String {
        get {
            let saved = UserDefaults.standard.string(forKey: Self.urlKey) ?? ""
            return saved.isEmpty ? Self.defaultServerURL : saved
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.urlKey) }
    }

    static let commonItems = ["eggs", "butter", "milk", "onion", "garlic", "rice", "pasta", "cheese", "tomatoes", "bread"]
    static let skip = "__skip"
    static let other = "__other"

    private var api: APIClient { APIClient(baseURL: serverURL) }

    func findIngredients() async {
        guard !photos.isEmpty else {
            errorMessage = "Add at least one photo first — or type your ingredients instead."
            return
        }
        await run("Peeking behind the leftovers…") {
            let result = try await self.api.detect(images: self.photos)
            self.startReview(with: result)
        }
    }

    func typeInstead() {
        startReview(with: .empty)
    }

    func startReview(with detection: Detection) {
        self.detection = detection
        unsureChoice = [:]
        unsureOther = [:]
        selected = Set(detection.sure)
        var order = detection.sure
        for item in Self.commonItems where !order.contains(item) { order.append(item) }
        chipOrder = order
        stage = .review
    }

    var finalIngredients: [String] {
        var list = chipOrder.filter { selected.contains($0) }
        for item in detection.unsure {
            guard let choice = unsureChoice[item.looksLike] else { continue }
            if choice == Self.skip { continue }
            if choice == Self.other {
                let typed = (unsureOther[item.looksLike] ?? "").trimmingCharacters(in: .whitespaces).lowercased()
                if !typed.isEmpty { list.append(typed) }
            } else {
                list.append(choice)
            }
        }
        let extras = extraText
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        list.append(contentsOf: extras)
        var seen = Set<String>()
        return list.filter { seen.insert($0).inserted }
    }

    func planMenu() async {
        let ingredients = finalIngredients
        guard ingredients.count >= 2 else {
            errorMessage = "Pick at least two ingredients so the chef has something to work with."
            return
        }
        await run("The chef is writing tonight's menu…") {
            let req = RecipeRequest(ingredients: ingredients,
                                    useFirst: self.detection.useFirst.filter { ingredients.contains($0) },
                                    dietaryNotes: self.dietaryNotes,
                                    mealType: self.mealType.lowercased(),
                                    people: self.people,
                                    flavors: self.flavors.sorted().map { $0.lowercased() },
                                    guidance: self.guidance)
            self.dishes = try await self.api.recipes(req)
            self.stage = .menu
        }
    }

    func cook(_ dish: Dish) {
        chosen = dish
        checkedSteps = []
        stage = .recipe
    }

    var mealLog: [LoggedMeal] = AppState.loadLog()

    var todaysMeals: [LoggedMeal] {
        mealLog.filter { Calendar.current.isDateInToday($0.date) }
    }

    var todaysTotal: Nutrition {
        todaysMeals.reduce(.zero) { $0 + $1.nutrition }
    }

    func madeIt() {
        if let dish = chosen, let n = dish.nutrition {
            mealLog.append(LoggedMeal(date: Date(), name: dish.plainName.capitalizedFirst, nutrition: n))
            saveLog()
        }
        stage = .card
    }

    func removeMeal(_ meal: LoggedMeal) {
        mealLog.removeAll { $0.id == meal.id }
        saveLog()
    }

    private func saveLog() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
        mealLog = mealLog.filter { $0.date >= cutoff }
        if let data = try? JSONEncoder().encode(mealLog) {
            UserDefaults.standard.set(data, forKey: "mealLog")
        }
    }

    private static func loadLog() -> [LoggedMeal] {
        guard let data = UserDefaults.standard.data(forKey: "mealLog"),
              let log = try? JSONDecoder().decode([LoggedMeal].self, from: data) else { return [] }
        return log
    }

    func startOver() {
        photos = []
        detection = .empty
        selected = []
        chipOrder = []
        extraText = ""
        dietaryNotes = ""
        guidance = ""
        dishes = []
        chosen = nil
        stage = .snap
    }

    private func run(_ text: String, _ work: @escaping () async throws -> Void) async {
        isLoading = true
        loadingText = text
        defer { isLoading = false }
        do {
            try await work()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
