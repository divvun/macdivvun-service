// Swift wrapper around DivvunRuntime's C FFI.

import Foundation

public struct DivvunRuntimeError: Error, LocalizedError {
    public let message: String
    public var errorDescription: String? { message }
}

// MARK: - Error capture (serialized global)

private let drtErrorLock = NSLock()
nonisolated(unsafe) private var drtLastError: DivvunRuntimeError?

@_cdecl("__macDivvunDrtErrorCallback")
private func macDivvunDrtErrorCallback(errorPtr: UnsafeMutableRawPointer?, errorLen: UInt) {
    guard let ptr = errorPtr else {
        drtLastError = DivvunRuntimeError(message: "Unknown error")
        return
    }
    let data = Data(bytes: ptr, count: Int(errorLen))
    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
    drtLastError = DivvunRuntimeError(message: message)
}

private let drtErrorCallback: error_callback_t = macDivvunDrtErrorCallback

private func runFFI<T>(_ body: () -> T?) throws -> T {
    drtErrorLock.lock()
    defer { drtErrorLock.unlock() }
    drtLastError = nil
    if let result = body() {
        return result
    }
    throw drtLastError ?? DivvunRuntimeError(message: "Unknown FFI failure")
}

// MARK: - Slice helpers

private func withRustSlice<T>(_ string: String, _ body: (rust_slice_t) throws -> T) rethrows -> T {
    var data = string.data(using: .utf8)!
    return try data.withUnsafeMutableBytes { bytes in
        let slice = rust_slice_t(data: bytes.baseAddress, len: rust_usize_t(bytes.count))
        return try body(slice)
    }
}

private func dataFromSlice(_ slice: rust_slice_t) -> Data {
    guard let ptr = slice.data, slice.len > 0 else { return Data() }
    return Data(bytes: ptr, count: Int(slice.len))
}

// MARK: - Response protocol

public protocol PipelineResponseConvertible {
    static func from(data: Data) throws -> Self
}

extension Data: PipelineResponseConvertible {
    public static func from(data: Data) throws -> Data { data }
}

extension String: PipelineResponseConvertible {
    public static func from(data: Data) throws -> String {
        guard let s = String(data: data, encoding: .utf8) else {
            throw DivvunRuntimeError(message: "Failed to decode UTF-8 string from response")
        }
        return s
    }
}

extension Array: PipelineResponseConvertible where Element == String {
    public static func from(data: Data) throws -> [String] {
        try JSONDecoder().decode([String].self, from: data)
    }
}

extension Dictionary: PipelineResponseConvertible where Key == String, Value == Any {
    public static func from(data: Data) throws -> [String: Any] {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any] else {
            throw DivvunRuntimeError(message: "Response is not a JSON object")
        }
        return dict
    }
}

extension PipelineResponseConvertible where Self: Decodable {
    public static func from(data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }
}

// MARK: - Bundle

public final class Bundle {
    private let handle: bundle_handle_t

    private init(handle: bundle_handle_t) {
        self.handle = handle
    }

    deinit {
        DRT_Bundle_drop(handle)
    }

    public static func fromPath(_ path: String) throws -> Bundle {
        let handle = try withRustSlice(path) { slice in
            try runFFI { DRT_Bundle_fromPath(slice, drtErrorCallback) }
        }
        return Bundle(handle: handle)
    }

    public static func fromBundle(_ bundlePath: String) throws -> Bundle {
        let handle = try withRustSlice(bundlePath) { slice in
            try runFFI { DRT_Bundle_fromBundle(slice, drtErrorCallback) }
        }
        return Bundle(handle: handle)
    }

    public func create(config: [String: Any] = [:]) throws -> PipelineHandle {
        let configData = try JSONSerialization.data(withJSONObject: config, options: [])
        let configString = String(data: configData, encoding: .utf8) ?? "{}"
        let myHandle = handle
        let pipelineHandle = try withRustSlice(configString) { slice in
            try runFFI { DRT_Bundle_create(myHandle, slice, drtErrorCallback) }
        }
        return PipelineHandle(handle: pipelineHandle)
    }
}

// MARK: - PipelineHandle

public final class PipelineHandle {
    private let handle: pipeline_handle_t

    fileprivate init(handle: pipeline_handle_t) {
        self.handle = handle
    }

    deinit {
        DRT_PipelineHandle_drop(handle)
    }

    public func forward<T: PipelineResponseConvertible>(_ input: String, as type: T.Type = Data.self) throws -> T {
        let myHandle = handle
        var outputSlice = rust_slice_t(data: nil, len: 0)
        let callError: DivvunRuntimeError? = withRustSlice(input) { slice in
            drtErrorLock.lock()
            defer { drtErrorLock.unlock() }
            drtLastError = nil
            outputSlice = DRT_PipelineHandle_forward(myHandle, slice, drtErrorCallback)
            return drtLastError
        }
        defer { DRT_Vec_drop(outputSlice) }
        if let err = callError { throw err }
        let data = dataFromSlice(outputSlice)
        return try T.from(data: data)
    }

    public func forwardBytes(_ input: String) throws -> Data {
        try forward(input, as: Data.self)
    }

    public func forwardString(_ input: String) throws -> String {
        try forward(input, as: String.self)
    }

    public func forwardJSON(_ input: String) throws -> [String: Any] {
        try forward(input, as: [String: Any].self)
    }

    public func forwardJSON<T: Decodable>(_ input: String, as type: T.Type) throws -> T {
        let data: Data = try forward(input)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
