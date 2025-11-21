import Contacts
import Foundation

enum ContactsError: LocalizedError {
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Contacts permission was denied."
        }
    }
}

final class ContactsManager {
    private let store = CNContactStore()

    func requestAccess() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard granted else {
                    continuation.resume(throwing: ContactsError.authorizationDenied)
                    return
                }
                continuation.resume()
            }
        }
    }

    func fetchContacts(limit: Int = 50) throws -> [ChallengeContact] {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault

        var gathered: [ChallengeContact] = []
        try store.enumerateContacts(with: request) { contact, stop in
            if gathered.count >= limit {
                stop.pointee = true
                return
            }
            gathered.append(ChallengeContact(contact: contact))
        }

        return gathered.sorted { $0.displayName < $1.displayName }
    }
}

private extension ChallengeContact {
    init(contact: CNContact) {
        self.init(
            id: contact.identifier,
            givenName: contact.givenName,
            familyName: contact.familyName,
            phoneNumber: contact.phoneNumbers.first?.value.stringValue,
            email: contact.emailAddresses.first?.value as String?
        )
    }
}
