import Foundation

struct UnsureItem: Codable, Hashable, Identifiable {
    var id: String { looksLike }
    let looksLike: String
    let options: [String]

    enum CodingKeys: String, CodingKey {
        case looksLike = "looks_like"
        case options
    }
}

struct Detection: Codable {
    var sure: [String]
    var unsure: [UnsureItem]
    var useFirst: [String]

    enum CodingKeys: String, CodingKey {
        case sure, unsure
        case useFirst = "use_first"
    }

    static let empty = Detection(sure: [], unsure: [], useFirst: [])
}

struct Dish: Codable, Hashable, Identifiable {
    var id: String { fancyName }
    let fancyName: String
    let plainName: String
    let menuDescription: String
    let minutes: Int
    let difficulty: String
    let uses: [String]
    let steps: [String]
    let platingTip: String
    let servings: Int?
    let nutrition: Nutrition?

    enum CodingKeys: String, CodingKey {
        case fancyName = "fancy_name"
        case plainName = "plain_name"
        case menuDescription = "menu_description"
        case minutes, difficulty, uses, steps
        case platingTip = "plating_tip"
        case servings, nutrition
    }
}

struct Nutrition: Codable, Hashable {
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
    var fiberG: Int

    enum CodingKeys: String, CodingKey {
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
    }

    static let zero = Nutrition(calories: 0, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0)

    static func + (a: Nutrition, b: Nutrition) -> Nutrition {
        Nutrition(calories: a.calories + b.calories, proteinG: a.proteinG + b.proteinG,
                  carbsG: a.carbsG + b.carbsG, fatG: a.fatG + b.fatG, fiberG: a.fiberG + b.fiberG)
    }
}

struct LoggedMeal: Codable, Identifiable, Hashable {
    var id = UUID()
    let date: Date
    let name: String
    let nutrition: Nutrition
}

struct DishesResponse: Codable {
    let dishes: [Dish]
}

struct RecipeRequest: Codable {
    let ingredients: [String]
    let useFirst: [String]
    let dietaryNotes: String
    var mealType: String = ""
    var people: Int = 0
    var flavors: [String] = []
    var guidance: String = ""

    enum CodingKeys: String, CodingKey {
        case ingredients
        case useFirst = "use_first"
        case dietaryNotes = "dietary_notes"
        case mealType = "meal_type"
        case people, flavors, guidance
    }
}

struct Health: Codable {
    let ok: Bool
    let provider: String
}
