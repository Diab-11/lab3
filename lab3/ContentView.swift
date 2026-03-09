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

extension String {
    var htmlDecoded: String {
        guard let data = data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return (try? NSAttributedString(data: data, options: options, documentAttributes: nil))?.string ?? self
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
                if let question = viewModel.currentQuestion {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Question \(viewModel.currentIndex + 1) of \(viewModel.questions.count)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            ProgressView(value: viewModel.progress)
                                .tint(.blue)
                        }
                        .padding(.horizontal)

                        Text(question.question.htmlDecoded)
                            .font(.title3)
                            .bold()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(question.allAnswers, id: \.self) { answer in
                                Button {
                                    viewModel.submitAnswer(answer)
                                } label: {
                                    Text(answer.htmlDecoded)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                    .padding(.top)
                }
            case .finished:
                Text("Finished!")
            }
        }
        .task {
            await viewModel.loadQuestions()
        }
    }
}
