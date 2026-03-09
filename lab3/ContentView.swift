import SwiftUI

struct QuizResponse: Codable {
    let results: [Question]
}

struct Question: Codable, Identifiable {
    let id = UUID()
    let question: String
    let correctAnswer: String
    let incorrectAnswers: [String]

    enum CodingKeys: String, CodingKey {
        case question
        case correctAnswer = "correct_answer"
        case incorrectAnswers = "incorrect_answers"
    }

    var allAnswers: [String] {
        (incorrectAnswers + [correctAnswer]).shuffled()
    }
}

enum QuizState {
    case loading
    case playing
    case error(String)
    case finished
}

struct ContentView: View {
    var body: some View {
        Text("Quiz App")
    }
}
