// Source: https://github.com/peterprokop/SwiftConcurrentCollections/
// License: MIT

//
//  RWLock.swift
//  SwiftConcurrentCollections
//
//  Created by Pete Prokop on 09/02/2020.
//  Copyright © 2020 Pete Prokop. All rights reserved.
//
import Foundation

final class RWLock {
    private var lock: pthread_rwlock_t

    // MARK: Lifecycle
    deinit {
        pthread_rwlock_destroy(&lock)
    }

    public init() {
        lock = pthread_rwlock_t()
        pthread_rwlock_init(&lock, nil)
    }

    // MARK: Public
    public func writeLock() {
        pthread_rwlock_wrlock(&lock)
    }

    public func readLock() {
        pthread_rwlock_rdlock(&lock)
    }

    public func unlock() {
        pthread_rwlock_unlock(&lock)
    }
}


import Foundation

/// Thread-safe dictionary wrapper
/// - Important: Note that this is a `class`, i.e. reference (not value) type
public final class ConcurrentDictionary<Key: Hashable, Value> {

    private var container: [Key: Value] = [:]
    private let rwlock = RWLock()

    public var keys: [Key] {
        let result: [Key]
        rwlock.readLock()
        result = Array(container.keys)
        rwlock.unlock()
        return result
    }

    public var values: [Value] {
        let result: [Value]
        rwlock.readLock()
        result = Array(container.values)
        rwlock.unlock()
        return result
    }

    public init() {}

    /// Sets the value for key
    ///
    /// - Parameters:
    ///   - value: The value to set for key
    ///   - key: The key to set value for
    public func set(value: Value, forKey key: Key) {
        rwlock.writeLock()
        _set(value: value, forKey: key)
        rwlock.unlock()
    }

    @discardableResult
    public func remove(_ key: Key) -> Value? {
        let result: Value?
        rwlock.writeLock()
        result = _remove(key)
        rwlock.unlock()
        return result
    }

    public func contains(_ key: Key) -> Bool {
        let result: Bool
        rwlock.readLock()
        result = container.index(forKey: key) != nil
        rwlock.unlock()
        return result
    }

    public func value(forKey key: Key) -> Value? {
        let result: Value?
        rwlock.readLock()
        result = container[key]
        rwlock.unlock()
        return result
    }

    public func mutateValue(forKey key: Key, mutation: (Value) -> Value) {
        rwlock.writeLock()
        if let value = container[key] {
            container[key] = mutation(value)
        }
        rwlock.unlock()
    }

    // MARK: Subscript
    public subscript(key: Key) -> Value? {
        get {
            return value(forKey: key)
        }
        set {
            rwlock.writeLock()
            guard let newValue = newValue else {
                _remove(key)
                return
            }
            _set(value: newValue, forKey: key)
            rwlock.unlock()
        }
    }

    // MARK: Private
    @inline(__always)
    private func _set(value: Value, forKey key: Key) {
        self.container[key] = value
    }

    @inline(__always)
    @discardableResult
    private func _remove(_ key: Key) -> Value? {
        guard let index = container.index(forKey: key) else { return nil }

        let tuple = container.remove(at: index)
        return tuple.value
    }

}
