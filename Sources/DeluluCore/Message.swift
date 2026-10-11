import Foundation

public enum MessageMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case outreach, offer
    public var id: String { rawValue }
    public var title: String { self == .outreach ? "First hello" : "The offer" }
    public var symbol: String { self == .outreach ? "bubble.left.and.bubble.right" : "envelope.open" }
}

public struct DreamProfile: Codable, Equatable, Sendable {
    public var name: String
    public var role: String
    public var strength: String
    public var compensation: String
    public var location: String

    public init(name: String = "Alex", role: String = "Product Designer",
                strength: String = "making complex things feel simple", compensation: String = "",
                location: String = "Remote") {
        self.name = name
        self.role = role
        self.strength = strength
        self.compensation = compensation
        self.location = location
    }

    public var normalized: Self {
        Self(name: name.cleaned, role: role.cleaned,
             strength: strength.cleaned, compensation: compensation.cleaned, location: location.cleaned)
    }

    public var validationError: String? {
        let p = normalized
        if p.name.isEmpty || p.role.isEmpty { return "Add your name and dream role." }
        if [p.name, p.role, p.compensation, p.location].contains(where: { $0.count > 100 }) {
            return "Keep each short field under 100 characters."
        }
        if p.strength.count > 240 { return "Keep your standout skill under 240 characters." }
        return nil
    }
}

extension String {
    fileprivate var cleaned: String { split(whereSeparator: \.isWhitespace).joined(separator: " ") }
}

public struct RecruiterMessage: Codable, Equatable, Sendable {
    public var mode: MessageMode
    public var company: String
    public var recruiter: String
    public var subject: String
    public var body: String

    public var notificationTitle: String { "\(recruiter) · \(company)" }
    public var notificationSubtitle: String { subject }
    public var copyText: String {
        "[Fictional message from Delulu]\n\(notificationTitle)\n\(subject)\n\n\(body)"
    }
}

public enum MessageGenerator {
    public static let variantCount = 5

    public static func generate(profile: DreamProfile, mode: MessageMode, variant: Int) -> RecruiterMessage {
        let p = profile.normalized
        let index = ((variant % variantCount) + variantCount) % variantCount
        let company = ["Orbit", "Northstar Studio", "Daylight Labs", "Fieldwork", "Kindred Works"][index]
        let recruiter = ["Maya Chen", "Jamie Morgan", "Sam Rivera", "Robin Ellis", "Taylor Brooks"][index]
        let skill = p.strength.isEmpty ? "your thoughtful approach to your work" : "your talent for \(p.strength)"
        let workplace = p.location.isEmpty ? "" : "\nWork setup: \(p.location)"
        let compensation = p.compensation.isEmpty ? "" : "\nCompensation: \(p.compensation)"
        let subjects: [String]
        let paragraphs: [String]

        switch mode {
        case .outreach:
            subjects = ["A role with your name on it", "Your work caught our eye", "Let's talk about \(company)",
                        "A little out of the blue…", "Room for your next big thing"]
            paragraphs = [
                "I came across your work and kept coming back to \(skill). We're looking for a \(p.role) at \(company), and I'd love to explore whether it could be your next chapter.\n\nWould you be open to a quick, informal chat this week?",
                "Your name came up as we were talking about the kind of person we'd love to bring to \(company). Specifically, \(skill) really stood out.\n\nWe're hiring a \(p.role). I think there's something interesting here. Would you have 20 minutes to talk?",
                "I'm helping build the team at \(company), and your profile stopped my scroll. We have a \(p.role) opening that feels like a lovely match for \(skill).\n\nI'd be happy to share more. Is there a good time for a conversation?",
                "I know the best opportunities don't always arrive when you're looking. We're putting together something exciting at \(company), and I'd love to talk with you about our \(p.role) role.\n\nWhat caught our attention was \(skill). Curious to hear what you'd want from your next move.",
                "We're looking for a \(p.role) who can bring a fresh perspective to \(company). After seeing your work, I wanted to reach out personally.\n\nWe really value \(skill). If you're curious, I'd love to tell you what we're working on."
            ]
        case .offer:
            subjects = ["We'd love you on the team", "The answer is yes", "Your next chapter, at \(company)",
                        "Some very good news", "Let's make it official"]
            paragraphs = [
                "I'm so happy to share this: we'd love to offer you the \(p.role) position at \(company).\n\nThe team loved \(skill). We can already picture what we'll create together.",
                "Good news! We'd like to offer you the \(p.role) role at \(company). Everyone left our conversations excited about what you'd bring to the team.\n\nIn particular, \(skill) made a real impression.",
                "It's a pleasure to invite you to join \(company) as our next \(p.role). We were looking for someone with your perspective, and the team is excited to work with you.\n\nYour next chapter is looking bright.",
                "This is my favorite kind of message to send. We'd love to welcome you to \(company) as a \(p.role).\n\nYour ideas stayed with the team long after the conversation ended. We think you'd feel right at home here.",
                "We've made our decision, and it's you. We'd like to offer you the \(p.role) position at \(company).\n\nYour experience and \(skill) are exactly what we hoped to find. We'd be thrilled to have you with us."
            ]
        }
        let details = mode == .offer ? "\(compensation)\(workplace)" : ""
        let ending = mode == .offer ? "\n\nTake a moment to enjoy this. I'd love to walk you through the next steps." : ""
        return RecruiterMessage(mode: mode, company: company, recruiter: recruiter, subject: subjects[index],
                                body: "Hi \(p.name),\n\n\(paragraphs[index])\(details)\(ending)\n\n\(recruiter)\nTalent team · \(company)")
    }
}

public enum DeliveryCadence: String, Codable, CaseIterable, Identifiable, Sendable {
    case minute, fiveMinutes, fifteenMinutes, hour, threeHours
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .minute: "Every minute"
        case .fiveMinutes: "Every 5 minutes"
        case .fifteenMinutes: "Every 15 minutes"
        case .hour: "Every hour"
        case .threeHours: "Every 3 hours"
        }
    }
    public var interval: TimeInterval {
        switch self {
        case .minute: 60
        case .fiveMinutes: 300
        case .fifteenMinutes: 900
        case .hour: 3600
        case .threeHours: 10800
        }
    }
}

public struct RecurringSchedule: Codable, Equatable, Sendable {
    public static let notificationID = "delulu.recurring"
    public var message: RecruiterMessage
    public var cadence: DeliveryCadence
    public var soundEnabled: Bool

    public init(message: RecruiterMessage, cadence: DeliveryCadence, soundEnabled: Bool) {
        self.message = message
        self.cadence = cadence
        self.soundEnabled = soundEnabled
    }
}
