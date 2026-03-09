import SwiftUI
import Combine
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

@MainActor
class QuizViewModel: ObservableObject {
    @Published var questions: [Question] = []
    @Published var currentIndex: Int = 0
    @Published var score: Int = 0
    @Published var state: QuizState = .loading

    func loadQuestions() async {
        state = .loading
        guard let url = URL(string: "https://opentdb.com/api.php?amount=10&type=multiple") else {
            state = .error("Invalid URL")
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(QuizResponse.self, from: data)
            questions = decoded.results
            currentIndex = 0
            score = 0
            state = .playing
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    var currentQuestion: Question? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }

    func submitAnswer(_ answer: String) {
        guard let question = currentQuestion else { return }
        if answer == question.correctAnswer {
            score += 1
        }
        if currentIndex + 1 < questions.count {
            currentIndex += 1
        } else {
            state = .finished
        }
    }

    func restart() {
        Task {
            await loadQuestions()
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = QuizViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading questions...")
                        .foregroundColor(.gray)
                }
            case .error(let message):
                VStack(spacing: 20) {
                    Text("Something went wrong")
                        .font(.title2)
                        .bold()
                    Text(message)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Try Again") {
                        viewModel.restart()
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .playing:
                Text("Playing...")
            case .finished:
                Text("Finished!")
            }
        }
        .task {
            await viewModel.loadQuestions()
        }
    }
}
