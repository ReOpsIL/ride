import Foundation

struct TabState: Codable, Equatable {
    var path: String
    var caretByte: UInt32
    var scrollLine: UInt32
    var folds: [UInt32]

    init(path: String, caretByte: UInt32, scrollLine: UInt32, folds: [UInt32]) {
        self.path = path
        self.caretByte = caretByte
        self.scrollLine = scrollLine
        self.folds = folds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        path = try c.decode(String.self, forKey: .path)
        caretByte = try c.decodeIfPresent(UInt32.self, forKey: .caretByte) ?? 0
        scrollLine = try c.decodeIfPresent(UInt32.self, forKey: .scrollLine) ?? 1
        folds = try c.decodeIfPresent([UInt32].self, forKey: .folds) ?? []
    }

    func clamped(toUtf8Count count: Int) -> TabState {
        var next = self
        next.caretByte = min(caretByte, UInt32(max(0, count)))
        next.scrollLine = max(1, scrollLine)
        next.folds = folds.filter { Int($0) < count }
        return next
    }

    func folds(keeping valid: Set<UInt32>) -> [UInt32] {
        folds.filter { valid.contains($0) }
    }
}

struct WorkspaceState: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var tabs: [TabState]
    var focusedPath: String?
    var layout: LayoutState
    var split: SplitState?
    var runConfigs: [RunConfig]
    var selectedTarget: String?
    var profile: String?
    var breakpoints: Breakpoints
    var watches: [String]

    init(
        version: Int = currentVersion,
        tabs: [TabState],
        focusedPath: String?,
        layout: LayoutState,
        split: SplitState? = nil,
        runConfigs: [RunConfig] = [],
        selectedTarget: String? = nil,
        profile: String? = nil,
        breakpoints: Breakpoints = Breakpoints(),
        watches: [String] = []
    ) {
        self.version = version
        self.tabs = tabs
        self.focusedPath = focusedPath
        self.layout = layout
        self.split = split
        self.runConfigs = runConfigs
        self.selectedTarget = selectedTarget
        self.profile = profile
        self.breakpoints = breakpoints
        self.watches = watches
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 0
        tabs = try c.decodeIfPresent([TabState].self, forKey: .tabs) ?? []
        focusedPath = try c.decodeIfPresent(String.self, forKey: .focusedPath)
        layout = try c.decodeIfPresent(LayoutState.self, forKey: .layout) ?? .defaults
        split = try c.decodeIfPresent(SplitState.self, forKey: .split)
        runConfigs = try c.decodeIfPresent([RunConfig].self, forKey: .runConfigs) ?? []
        selectedTarget = try c.decodeIfPresent(String.self, forKey: .selectedTarget)
        profile = try c.decodeIfPresent(String.self, forKey: .profile)
        breakpoints = try c.decodeIfPresent(Breakpoints.self, forKey: .breakpoints) ?? Breakpoints()
        watches = try c.decodeIfPresent([String].self, forKey: .watches) ?? []
    }

    static func decode(_ data: Data) -> WorkspaceState? {
        guard let state = try? JSONDecoder().decode(WorkspaceState.self, from: data),
              state.version == currentVersion
        else {
            return nil
        }
        return state
    }
}
