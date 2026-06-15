// AppState.swift — top-level UI state machine

import Foundation

enum AppStage: Equatable {
    case splash, inbox, processing, detail, library
}

// MARK: - Mind filter chips

enum FilterType: String, CaseIterable {
    case all, notes, tasks, ideas, links, archived

    var label: String {
        switch self {
        case .all:      return "all"
        case .notes:    return "notes"
        case .tasks:    return "tasks"
        case .ideas:    return "ideas"
        case .links:    return "links"
        case .archived: return "archived"
        }
    }

    func matches(_ note: Note) -> Bool {
        switch self {
        case .all:      return !note.isArchived
        case .notes:    return note.type == .note && !note.isArchived
        case .tasks:    return note.type == .task && !note.isArchived
        case .ideas:    return note.type == .idea && !note.isArchived
        case .links:    return note.type == .link && !note.isArchived
        case .archived: return note.isArchived
        }
    }
}

// MARK: - Library filter chips

enum LibraryFilterType: String, CaseIterable {
    case all, video, reading, audio, social, archived

    var label: String { rawValue }

    func matches(_ kind: LinkKind) -> Bool {
        switch self {
        case .all:      return true
        case .video:    return kind == .youtube || kind == .tiktok
        case .reading:  return kind == .article
        case .audio:    return kind == .spotify
        case .social:   return kind == .instagram || kind == .tiktok
        case .archived: return false  // handled separately in displayedLinks
        }
    }
}

// MARK: - Date filter (shared by Mind + Library)

enum DateFilterOption: Equatable {
    case none, today, thisWeek, thisMonth, custom

    var isActive: Bool { self != .none }

    var label: String {
        switch self {
        case .none:      return "date"
        case .today:     return "today"
        case .thisWeek:  return "this week"
        case .thisMonth: return "this month"
        case .custom:    return "range"
        }
    }

    func matches(_ date: Date, customStart: Date, customEnd: Date) -> Bool {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .none:      return true
        case .today:     return cal.isDateInToday(date)
        case .thisWeek:  return cal.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .thisMonth: return cal.isDate(date, equalTo: now, toGranularity: .month)
        case .custom:    return date >= customStart && date <= customEnd
        }
    }
}

// MARK: - Sort order (Fix 6)

enum NoteSortOrder {
    case newest, oldest, byType
}

// MARK: - Global state

@Observable
final class AppState {
    // Fix 13: skip splash after first launch
    var stage: AppStage = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") ? .inbox : .splash
    var filter: FilterType = .all
    var libraryFilter: LibraryFilterType = .all
    var captureText: String = ""
    var activeNote: Note? = nil
    var toastVisible: Bool = false
    var isSavingToLibrary: Bool = false
    var isShowingDigestDetail: Bool = false
    var isPro: Bool = true {
        didSet { UserDefaults.standard.set(isPro, forKey: "isPro") }
    }

    // Mind keyword search
    var mindSearchText: String = ""
    var isSearching: Bool = false

    // Mind date + tag filters
    var mindDateFilter: DateFilterOption = .none
    var mindCustomStart: Date = Calendar.current.startOfDay(for: Date())
    var mindCustomEnd: Date = Date()
    var mindTagFilter: String? = nil

    // Library date + tag filters
    var libraryDateFilter: DateFilterOption = .none
    var libraryCustomStart: Date = Calendar.current.startOfDay(for: Date())
    var libraryCustomEnd: Date = Date()
    var libraryTagFilter: String? = nil

    // Fix 6: sort order
    var mindSortOrder: NoteSortOrder = .newest
    var librarySortOrder: NoteSortOrder = .newest

    // Capture experience enhancements
    var capturedTextForProcessing: String = ""
    var isQuietHours: Bool = false
    var stressMode: Bool = false

    // Corpus intelligence
    /// A past note surfaced as an "echo" beneath a freshly captured note.
    var echoNote: Note? = nil
    /// The id of the new note the current echo belongs to (gates which card shows it).
    var echoForNoteID: UUID? = nil
    /// Whether the Recall (second-mind query) space is open.
    var isRecalling: Bool = false
    /// Set when a deep link (widget) asks to open the capture bar focused.
    var shouldFocusCapture: Bool = false
    /// Whether the voice recording capture sheet is presented.
    var isRecordingVoice: Bool = false

    // Settings + appearance
    var isShowingSettings: Bool = false
    var appearance: AppearanceMode = AppearanceMode(
        rawValue: UserDefaults.standard.string(forKey: "appearance") ?? ""
    ) ?? .system {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }

    var firstNoteCeremonyShown: Bool {
        get { UserDefaults.standard.bool(forKey: "firstNoteCeremonyShown") }
        set { UserDefaults.standard.set(newValue, forKey: "firstNoteCeremonyShown") }
    }
}
