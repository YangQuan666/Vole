import Foundation

enum SiteConfiguration {
    static let defaultBaseURL = "https://edge.v2ex.com"
    private static let presetBaseURLs = [
        defaultBaseURL,
        "https://www.v2ex.com",
        "https://global.v2ex.co",
    ]

    private static let baseURLsKey = "siteBaseURLs"
    private static let selectedBaseURLKey = "selectedSiteBaseURL"
    private static let defaultSiteMigrationKey = "didMigrateDefaultSiteToEdge"

    static let didChangeNotification = NSNotification.Name(
        "SiteConfiguration.didChange"
    )

    static var endpointV1: String {
        selectedBaseURL + "/api/"
    }

    static var endpointV2: String {
        selectedBaseURL + "/api/v2/"
    }

    static var selectedBaseURL: String {
        loadState().selectedBaseURL
    }

    static var cacheKeySuffix: String {
        let allowed = CharacterSet.alphanumerics
        return selectedBaseURL.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
    }

    static func makeSiteURL(from path: String) -> URL? {
        if path.hasPrefix("http") {
            return URL(string: path)
        }

        return URL(string: path, relativeTo: URL(string: selectedBaseURL))
    }

    static func matchesCurrentSite(host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }

        let currentHost = URL(string: selectedBaseURL)?.host?.lowercased()
        let knownHosts = Set(
            ["v2ex.com", "www.v2ex.com", currentHost].compactMap { $0 }
        )

        return knownHosts.contains(host)
    }

    static func normalizeBaseURL(_ rawValue: String) -> String? {
        var normalized = rawValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalized.isEmpty else { return nil }

        if !normalized.contains("://") {
            normalized = "https://" + normalized
        }

        guard var components = URLComponents(string: normalized),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            components.host?.isEmpty == false
        else {
            return nil
        }

        components.scheme = scheme
        components.host = components.host?.lowercased()
        components.query = nil
        components.fragment = nil

        while components.path.count > 1 && components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        if components.path == "/" {
            components.path = ""
        }

        return components.url?.absoluteString
    }

    static func persist(baseURLs: [String], selectedBaseURL: String?) {
        let state = resolveState(
            baseURLs: baseURLs,
            selectedBaseURL: selectedBaseURL
        )

        UserDefaults.standard.set(state.baseURLs, forKey: baseURLsKey)
        UserDefaults.standard.set(state.selectedBaseURL, forKey: selectedBaseURLKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func loadState() -> (baseURLs: [String], selectedBaseURL: String) {
        let storedSelection = UserDefaults.standard.string(
            forKey: selectedBaseURLKey
        )
        let selection: String?
        if !UserDefaults.standard.bool(forKey: defaultSiteMigrationKey) {
            let oldDefault = "https://www.v2ex.com"
            selection = storedSelection.flatMap { selected in
                selected.caseInsensitiveCompare(oldDefault) == .orderedSame
                    ? defaultBaseURL
                    : selected
            }
            UserDefaults.standard.set(true, forKey: defaultSiteMigrationKey)
        } else {
            selection = storedSelection
        }

        return resolveState(
            baseURLs: UserDefaults.standard.stringArray(forKey: baseURLsKey) ?? [],
            selectedBaseURL: selection
        )
    }

    private static func resolveState(
        baseURLs: [String],
        selectedBaseURL: String?
    ) -> (baseURLs: [String], selectedBaseURL: String) {
        let normalizedBaseURLs = normalizeBaseURLs(baseURLs + presetBaseURLs)
        let finalBaseURLs =
            normalizedBaseURLs.isEmpty ? normalizeBaseURLs(presetBaseURLs) : normalizedBaseURLs
        let normalizedSelected = selectedBaseURL.flatMap(normalizeBaseURL)
        let finalSelected =
            normalizedSelected.flatMap { selected in
                finalBaseURLs.first {
                    $0.caseInsensitiveCompare(selected) == .orderedSame
                }
            } ?? finalBaseURLs[0]

        return (finalBaseURLs, finalSelected)
    }

    private static func normalizeBaseURLs(_ rawValues: [String]) -> [String] {
        var normalizedURLs: [String] = []
        var seen = Set<String>()

        for rawValue in rawValues {
            guard let normalized = normalizeBaseURL(rawValue) else { continue }
            let key = normalized.lowercased()
            if seen.insert(key).inserted {
                normalizedURLs.append(normalized)
            }
        }

        return normalizedURLs
    }
}

enum SiteConfigurationError: LocalizedError {
    case invalidBaseURL

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "请输入有效的站点地址，例如 https://edge.v2ex.com"
        }
    }
}

@MainActor
final class SiteConfigurationStore: ObservableObject {
    static let shared = SiteConfigurationStore()

    @Published private(set) var baseURLs: [String] = []
    @Published private(set) var selectedBaseURL: String = SiteConfiguration.defaultBaseURL

    private init() {
        reload()
        SiteConfiguration.persist(
            baseURLs: baseURLs,
            selectedBaseURL: selectedBaseURL
        )
    }

    func reload() {
        let state = SiteConfiguration.loadState()
        baseURLs = state.baseURLs
        selectedBaseURL = state.selectedBaseURL
    }

    private func persist(baseURLs: [String]? = nil, selectedBaseURL: String? = nil) {
        SiteConfiguration.persist(
            baseURLs: baseURLs ?? self.baseURLs,
            selectedBaseURL: selectedBaseURL ?? self.selectedBaseURL
        )
        let state = SiteConfiguration.loadState()
        self.baseURLs = state.baseURLs
        self.selectedBaseURL = state.selectedBaseURL
    }

    func select(_ baseURL: String) {
        persist(selectedBaseURL: baseURL)
    }

    @discardableResult
    func add(_ rawValue: String) throws -> String {
        guard let normalized = SiteConfiguration.normalizeBaseURL(rawValue) else {
            throw SiteConfigurationError.invalidBaseURL
        }

        var updated = baseURLs
        if !updated.contains(where: {
            $0.caseInsensitiveCompare(normalized) == .orderedSame
        }) {
            updated.append(normalized)
        }

        persist(baseURLs: updated, selectedBaseURL: normalized)
        return normalized
    }

    func remove(_ baseURL: String) {
        persist(baseURLs: baseURLs.filter {
            $0.caseInsensitiveCompare(baseURL) != .orderedSame
        })
    }

    func canDelete(_ baseURL: String) -> Bool {
        baseURLs.count > 1
            || baseURL.caseInsensitiveCompare(SiteConfiguration.defaultBaseURL)
                != .orderedSame
    }
}
