/*
 * Copyright (C) 2015 - 2017, Daniel Dahan and CosmicMind, Inc. <http://cosmicmind.com>.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *	*	Redistributions of source code must retain the above copyright notice, this
 *		list of conditions and the following disclaimer.
 *
 *	*	Redistributions in binary form must reproduce the above copyright notice,
 *		this list of conditions and the following disclaimer in the documentation
 *		and/or other materials provided with the distribution.
 *
 *	*	Neither the name of CosmicMind nor the names of its
 *		contributors may be used to endorse or promote products derived from
 *		this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import EventKit

@objc(RemindersAuthorizationStatus)
public enum RemindersAuthorizationStatus: Int {
    case authorized
    case denied
}

@objc(RemindersPriority)
public enum RemindersPriority: Int {
    case none
    case high = 1
    case medium = 5
    case low = 9
}

@objc(RemindersDelegate)
public protocol RemindersDelegate {
    /**
     A delegation method that is executed when the Reminders status is updated.
     - Parameter reminders: A reference to the Reminders.
     - Parameter status: A reference to the ReminderAuthorizationStatus.
     */
    @objc
    optional func reminders(reminders: Reminders, status: RemindersAuthorizationStatus)
    
    /**
     A delegation method that is executed when reminders authorization is authorized.
     - Parameter reminders: A reference to the Reminders.
     */
    @objc
    optional func reminders(authorized reminders: Reminders)
    
    /**
     A delegation method that is executed when reminders authorization is denied.
     - Parameter reminders: A reference to the Reminders.
     */
    @objc
    optional func reminders(denied reminders: Reminders)
    
    /**
     A delegation method that is executed when a new calendar is created
     - Parameter reminders: A reference to the Reminders.
     - Parameter calendar: An optional reference to the calendar created.
     - Parameter error: An optional error if the calendar failed to be created.
     */
    @objc
    optional func reminders(reminders: Reminders, createdCalendar calendar: EKCalendar?, error: Error?)
    
    /**
     A delegation method that is executed when a new calendar is created.
     - Parameter reminders: A reference to the Reminder.
     - Parameter removed calendar: A reference to the calendar created.
     - Parameter error: An optional error if the calendar failed to be removed.
     */
    @objc
    optional func reminders(reminders: Reminders, removedCalendar calendar: EKCalendar, error: Error?)
    
    /**
     A delegation method that is executed when a new reminder is created.
     - Parameter reminders: A reference to the Reminders.
     - Parameter calendar: An optional reference to the reminder created.
     - Parameter error: An optional error if the reminder failed to be created.
     */
    @objc
    optional func reminders(reminders: Reminders, createdReminder reminder: EKReminder?, error: Error?)
    
    /**
     A delegation method that is executed when a new Reminders list is created
     - Parameter reminders: A reference to the Reminder.
     - Parameter deleted: A boolean describing if the operation succeeded or not.
     - Parameter error: An optional error if the reminder failed to be removed.
     */
    @objc
    optional func reminders(reminders: Reminders, removedReminder reminder: EKReminder, error: Error?)
}

@objc(Reminders)
open class Reminders: NSObject {
    /// A reference to the eventStore.
    fileprivate let eventStore = EKEventStore()
    
    /// The current ReminderAuthorizationStatus.
    open var authorizationStatus: RemindersAuthorizationStatus {
        return .authorized == EKEventStore.authorizationStatus(for: .reminder) ? .authorized : .denied
    }
    
    /// A reference to a RemindersDelegate.
    open weak var delegate: RemindersDelegate?
    
    open func requestAuthorization(_ completion: ((RemindersAuthorizationStatus) -> Void)? = nil) {
        eventStore.requestAccess(to: .reminder) { [weak self, completion = completion] (isAuthorized, _) in
            DispatchQueue.main.async { [weak self, completion = completion] in
                guard let s = self else {
                    return
                }
                
                guard isAuthorized else {
                    completion?(.denied)
                    s.delegate?.reminders?(reminders: s, status: .denied)
                    s.delegate?.reminders?(denied: s)
                    return
                }
                
                completion?(.authorized)
                s.delegate?.reminders?(reminders: s, status: .authorized)
                s.delegate?.reminders?(authorized: s)
            }
        }
    }
}

extension Reminders {
    /**
     Creates a predicate for the reminders Array of calendars.
     - Parameter in calendars: An optional Array of EKCalendars.
     */
    open func predicateForReminders(in calendars: [EKCalendar]) -> NSPredicate {
        return eventStore.predicateForReminders(in: calendars)
    }
    
    /**
     Creates a predicate for the reminders Array of calendars that
     are incomplete and have a given start and end date.
     - Parameter starting: A Date.
     - Parameter ending: A Date.
     - Parameter calendars: An optional Array of [EKCalendar].
     */
    open func predicateForIncompleteReminders(starting: Date, ending: Date, calendars: [EKCalendar]? = nil) -> NSPredicate {
        return eventStore.predicateForIncompleteReminders(withDueDateStarting: starting, ending: ending, calendars: calendars)
    }
    
    /**
     Creates a predicate for the reminders Array of calendars that
     are completed and have a given start and end date.
     - Parameter starting: A Date.
     - Parameter ending: A Date.
     - Parameter calendars: An optional Array of [EKCalendar].
     */
    open func predicateForCompletedReminders(starting: Date, ending: Date, calendars: [EKCalendar]? = nil) -> NSPredicate {
        return eventStore.predicateForCompletedReminders(withCompletionDateStarting: starting, ending: ending, calendars: calendars)
    }
}

extension Reminders {
    /**
     A method for retrieving reminder calendars in alphabetical order.
     - Parameter completion: A completion call back
     */
    open func calendars(completion: @escaping ([EKCalendar]) -> Void) {
        DispatchQueue.global(qos: .default).async { [weak self, completion = completion] in
            guard let s = self else {
                return
            }
            
            let calendar = s.eventStore.calendars(for: .reminder).sorted(by: { (a, b) -> Bool in
                return a.title < b.title
            })
            
            DispatchQueue.main.async { [calendar = calendar, completion = completion] in
                completion(calendar)
            }
        }
    }
    
    /**
     A method for retrieving events with a predicate in date sorted order.
     - Parameter predicate: A NSPredicate.
     - Parameter completion: A completion call back.
     - Returns: A fetch reminders request identifier.
     */
    @discardableResult
    open func reminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]) -> Void) -> Any {
        return eventStore.fetchReminders(matching: predicate, completion: { [completion = completion] (reminders) in
            DispatchQueue.main.async { [completion = completion] in
                completion(reminders ?? [])
            }
        })
    }
    
    /**
     Fetch all the reminders in a given Array of calendars.
     - Parameter in calendars: An Array of EKCalendars.
     - Parameter completion: A completion call back.
     - Returns: A fetch reminders request identifier.
     */
    @discardableResult
    open func reminders(in calendars: [EKCalendar], completion: @escaping ([EKReminder]) -> Void) -> Any {
        return reminders(matching: predicateForReminders(in: calendars), completion: completion)
    }
    
    /**
     Fetch all the reminders in a given Array of calendars that
     are incomplete, given a start and end date.
     - Parameter starting: A Date.
     - Parameter ending: A Date.
     - Parameter calendars: An Array of EKCalendars.
     - Parameter completion: A completion call back.
     - Returns: A fetch reminders request identifier.
     */
    @discardableResult
    open func incomplete(starting: Date, ending: Date, calendars: [EKCalendar]? = nil, completion: @escaping ([EKReminder]) -> Void) -> Any {
        return reminders(matching: predicateForIncompleteReminders(starting: starting, ending: ending, calendars: calendars), completion: completion)
    }
    
    /**
     Fetch all the reminders in a given Array of calendars that
     are completed, given a start and end date.
     - Parameter starting: A Date.
     - Parameter ending: A Date.
     - Parameter calendars: An Array of EKCalendars.
     - Parameter completion: A completion call back.
     - Returns: A fetch reminders request identifier.
     */
    @discardableResult
    open func completed(starting: Date, ending: Date, calendars: [EKCalendar]? = nil, completion: @escaping ([EKReminder]) -> Void) -> Any {
        return reminders(matching: predicateForCompletedReminders(starting: starting, ending: ending, calendars: calendars), completion: completion)
    }
    
    /**
     Cancels an active reminders request.
     - Parameter _ identifier: An identifier.
     */
    open func cancel(_ identifier: Any) {
        eventStore.cancelFetchRequest(identifier)
    }
}

extension Reminders {
    /**
     A method for creating new Reminder calendar.
     - Parameter calendar title: the name of the list.
     - Parameter completion: An optional completion call back.
     */
    open func create(calendar title: String, completion: ((EKCalendar?, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, completion = completion] in
            guard let s = self else {
                return
            }
            
            let calendar = EKCalendar(for: .reminder, eventStore: s.eventStore)
            calendar.title = title
            
            calendar.source = s.eventStore.defaultCalendarForNewReminders().source
                    
            var success = false
            var error: Error?
            
            do {
                try s.eventStore.saveCalendar(calendar, commit: true)
                success = true
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self, completion = completion] in
                guard let s = self else {
                    return
                }
                
                completion?(success ? calendar : nil, error)
                s.delegate?.reminders?(reminders: s, createdCalendar: success ? calendar : nil, error: error)
            }
        }
    }
    
    /**
     A method for removing existing calendar,
     - Parameter calendar identifier: The EKCalendar identifier String.
     - Parameter completion: An optional completion call back.
     */
    open func remove(calendar identifier: String, completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, completion = completion] in
            guard let s = self else {
                return
            }
            
            var success = false
            var error: Error?
            
            guard let calendar = s.eventStore.calendar(withIdentifier: identifier) else {
                var userInfo = [String: Any]()
                userInfo[NSLocalizedDescriptionKey] = "[Material Error: Cannot fix remove calendar with identifier \(identifier).]"
                userInfo[NSLocalizedFailureReasonErrorKey] = "[Material Error: Cannot fix remove calendar with identifier \(identifier).]"
                error = NSError(domain: "com.cosmicmind.material.reminders", code: 0001, userInfo: userInfo)
                
                completion?(success, error)
                return
            }
            
            do {
                try s.eventStore.removeCalendar(calendar, commit: true)
                success = true
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self, completion = completion] in
                guard let s = self else {
                    return
                }
                
                completion?(success, error)
                s.delegate?.reminders?(reminders: s, removedCalendar: calendar, error: error)
            }
        }
    }
}

extension Reminders {    
    // FIX ME: Should we use the calendar identifier here instead of the title for finding the right cal?
    /**
     A method for adding a new reminder to an optionally existing list.
     if the list does not exist it will be added to the default reminders list.
     - Parameter completion: optional A completion call back
     */
    open func create(reminder title: String, calendar: EKCalendar, startDateComponents: DateComponents? = nil, dueDateComponents: DateComponents? = nil, priority: RemindersPriority? = .none, notes: String?, completion: ((EKReminder?, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, calendar = calendar, completion = completion] in
            guard let s = self else {
                return
            }
            
            let reminder = EKReminder(eventStore: s.eventStore)
            reminder.title = title
            reminder.calendar = calendar
            reminder.startDateComponents = startDateComponents
            reminder.dueDateComponents = dueDateComponents
            reminder.priority = priority?.rawValue ?? RemindersPriority.none.rawValue
            reminder.notes = notes
            
            var success = false
            var error: Error?
            
            do {
                try s.eventStore.save(reminder, commit: true)
                success = true
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let s = self else {
                    return
                }
                
                completion?(success ? reminder : nil, error)
                s.delegate?.reminders?(reminders: s, createdReminder: success ? reminder : nil, error: error)
            }
        }
    }

    /**
     A method for removing existing reminder,
     - Parameter reminder identifier: The EKReminder identifier String.
     - Parameter completion: An optional completion call back.
     */
    open func remove(reminder identifier: String, completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, completion = completion] in
            guard let s = self else {
                return
            }
            
            var success = false
            var error: Error?
            
            guard let reminder = s.eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
                var userInfo = [String: Any]()
                userInfo[NSLocalizedDescriptionKey] = "[Material Error: Cannot fix remove calendar with identifier \(identifier).]"
                userInfo[NSLocalizedFailureReasonErrorKey] = "[Material Error: Cannot fix remove calendar with identifier \(identifier).]"
                error = NSError(domain: "com.cosmicmind.material.reminders", code: 0001, userInfo: userInfo)
                
                completion?(success, error)
                return
            }
            
            do {
                try s.eventStore.remove(reminder, commit: true)
                success = true
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self, completion = completion] in
                guard let s = self else {
                    return
                }
                
                completion?(success, error)
                s.delegate?.reminders?(reminders: s, removedReminder: reminder, error: error)
            }
        }
    }
}