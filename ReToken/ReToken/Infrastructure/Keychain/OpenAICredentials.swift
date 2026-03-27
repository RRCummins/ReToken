import Foundation

struct OpenAICredentials {
    let adminKey: String
    let organizationID: String?
    let projectID: String?

    func resolved(with environment: [String: String]) -> OpenAICredentials {
        OpenAICredentials(
            adminKey: adminKey,
            organizationID: normalized(organizationID) ?? normalized(environment["OPENAI_ORGANIZATION"]),
            projectID: normalized(projectID) ?? normalized(environment["OPENAI_PROJECT"])
        )
    }

    static func from(environment: [String: String]) -> OpenAICredentials? {
        guard let adminKey = normalized(environment["OPENAI_ADMIN_KEY"]) else {
            return nil
        }

        return OpenAICredentials(
            adminKey: adminKey,
            organizationID: normalized(environment["OPENAI_ORGANIZATION"]),
            projectID: normalized(environment["OPENAI_PROJECT"])
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false else {
            return nil
        }

        return trimmed
    }

    private func normalized(_ value: String?) -> String? {
        Self.normalized(value)
    }
}
