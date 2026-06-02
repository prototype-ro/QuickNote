// CalendarService.swift — adds detected events to the user's Apple Calendar.
//
// Thin EventKit wrapper. Requests write-only access (iOS 17+) and creates an
// EKEvent. Used by the Pro "add to calendar" affordance on event-bearing notes.

import Foundation
import EventKit

public enum CalendarError: Error, LocalizedError {
    case accessDenied
    case saveFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .accessDenied:       return "Calendar access was not granted"
        case .saveFailed(let e):  return "Couldn't save event: \(e.localizedDescription)"
        }
    }
}

public actor CalendarService {
    public static let shared = CalendarService()
    private let store = EKEventStore()

    private init() {}

    /// Requests write access if needed. Uses the iOS 17 write-only API.
    private func ensureAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess, .writeOnly:
            return
        case .notDetermined:
            let granted = try await store.requestWriteOnlyAccessToEvents()
            if !granted { throw CalendarError.accessDenied }
        default:
            throw CalendarError.accessDenied
        }
    }

    /// Creates a calendar event and returns its identifier.
    /// - Parameters:
    ///   - title: event name
    ///   - date: start date/time
    ///   - hasTime: when false, an all-day event is created
    ///   - notes: optional body (e.g. the originating note text)
    public func addEvent(title: String, date: Date, hasTime: Bool,
                         notes: String? = nil) async throws -> String {
        try await ensureAccess()

        let event = EKEvent(eventStore: store)
        event.title = title
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents

        if hasTime {
            event.startDate = date
            event.endDate = date.addingTimeInterval(60 * 60) // default 1h
        } else {
            event.isAllDay = true
            event.startDate = Calendar.current.startOfDay(for: date)
            event.endDate = event.startDate
        }

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            throw CalendarError.saveFailed(error)
        }
        return event.eventIdentifier
    }
}
