import Foundation

struct TargetAppContext: Equatable, Sendable {
    let localizedName: String?
    let bundleIdentifier: String?

    var displayName: String {
        let name = localizedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty {
            return name
        }

        let bundleID = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !bundleID.isEmpty {
            return bundleID
        }

        return "Unknown app"
    }

    static let unknown = TargetAppContext(localizedName: nil, bundleIdentifier: nil)
}
