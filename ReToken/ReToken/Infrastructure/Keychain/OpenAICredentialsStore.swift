import Foundation
import Security

final class OpenAICredentialsStore {
    private enum Constants {
        static let service = "com.themrhinos.ReToken.openai"
        static let adminKeyAccount = "admin-key"
        static let organizationAccount = "organization-id"
        static let projectAccount = "project-id"
    }

    func loadCredentials() -> OpenAICredentials? {
        guard let adminKey = loadValue(forAccount: Constants.adminKeyAccount) else {
            return nil
        }

        return OpenAICredentials(
            adminKey: adminKey,
            organizationID: loadValue(forAccount: Constants.organizationAccount),
            projectID: loadValue(forAccount: Constants.projectAccount)
        )
    }

    func saveCredentials(_ credentials: OpenAICredentials) throws {
        try saveValue(credentials.adminKey, forAccount: Constants.adminKeyAccount)
        try setOptionalValue(credentials.organizationID, forAccount: Constants.organizationAccount)
        try setOptionalValue(credentials.projectID, forAccount: Constants.projectAccount)
    }

    func clearCredentials() throws {
        try deleteValue(forAccount: Constants.adminKeyAccount)
        try deleteValue(forAccount: Constants.organizationAccount)
        try deleteValue(forAccount: Constants.projectAccount)
    }

    private func loadValue(forAccount account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                return nil
            }

            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            return nil
        }
    }

    private func saveValue(_ value: String, forAccount account: String) throws {
        let encodedValue = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.service,
            kSecAttrAccount: account
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: encodedValue
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData] = encodedValue
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw OpenAICredentialsStoreError.keychainFailure(status: addStatus)
            }
        default:
            throw OpenAICredentialsStoreError.keychainFailure(status: updateStatus)
        }
    }

    private func setOptionalValue(_ value: String?, forAccount account: String) throws {
        guard let value, value.isEmpty == false else {
            try deleteValue(forAccount: account)
            return
        }

        try saveValue(value, forAccount: account)
    }

    private func deleteValue(forAccount account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.service,
            kSecAttrAccount: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw OpenAICredentialsStoreError.keychainFailure(status: status)
        }
    }
}

enum OpenAICredentialsStoreError: LocalizedError {
    case keychainFailure(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case let .keychainFailure(status):
            return "Keychain operation failed (\(status))"
        }
    }
}
