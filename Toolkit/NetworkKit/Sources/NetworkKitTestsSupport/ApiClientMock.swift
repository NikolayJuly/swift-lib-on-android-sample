// ApiClientMock.swift

import Foundation
import FoundationExtension
import NetworkKit
import XCTest

// Will use `@unchecked Sendable` just to silence compiler for now.
public final class ApiClientTaskMock: ApiClientTask, @unchecked /*not at all*/ Sendable {

    public let progress = Progress(totalUnitCount: 1)

    public let taskIdentifier: Int = ApiClientTaskMock.incrementCount()

    public func cancel() {}

    private static let _requestsCount: Atomic<Int> = .init(wrappedValue: 0)

    static func incrementCount() -> Int {
        return _requestsCount.mutate { $0 += 1; return $0 }
    }
}

// Will use `@unchecked Sendable` just to silence compiler for now.
public final class ApiClientMock: ApiClient, @unchecked /*not at all*/ Sendable {

    public init(unhandledRequest: @escaping (RequestInfo) -> Void = { _ in }) {
        self.unhandledRequest = unhandledRequest
    }

    // MARK: API

    public func stubSuccess(result: Sendable,
                            predicate: @escaping @Sendable (RequestInfo) -> Bool = { _ in return true },
                            didHit: @escaping @Sendable () -> Void = {}) {
        let wrapper = NoParameterWrapper(closure: didHit)
        let stub = Stub(predicate: predicate, didHitWrapper: wrapper, result: .success(result))
        stubs.append(stub)
    }

    public func stubSuccess(result: Sendable,
                            predicate: @escaping @Sendable (RequestInfo) -> Bool = { _ in return true },
                            didHit: @escaping @Sendable (RequestInfo) -> Void) {
        let wrapper = WrapperWithParameter(closure: didHit)
        let stub = Stub(predicate: predicate, didHitWrapper: wrapper, result: .success(result))
        stubs.append(stub)
    }

    public func stubFailure(result: ApiClientError,
                            predicate: @escaping @Sendable (RequestInfo) -> Bool = { _ in return true },
                            didHit: @escaping @Sendable () -> Void = {}) {
        let wrapper = NoParameterWrapper(closure: didHit)
        let stub = Stub(predicate: predicate, didHitWrapper: wrapper, result: .failure(result))
        stubs.append(stub)
    }

    public func stubWait(for task: Task<Sendable, Error>,
                         predicate: @escaping @Sendable (RequestInfo) -> Bool = { _ in return true },
                         didHit: @escaping @Sendable () -> Void = {}) {
        let wrapper = NoParameterWrapper(closure: didHit)
        let stub = Stub(predicate: predicate, didHitWrapper: wrapper, result: .wait(task))
        stubs.append(stub)
    }

    public func removeAllStubs() {
        stubs.removeAll()
    }

    // MARK: ApiClient

    @discardableResult
    public func request<R: Requestable>(_ requestable: R, progress: Progress?) async throws(ApiClientError) -> R.ResponseType {
        let info = RequestInfo(requestable)
        for stub in stubs.reversed() {
            guard stub.predicate(info) else {
                continue
            }

            stub.didHitWrapper.didHit(info)

            switch stub.result {
            case let .success(response) where response is R.ResponseType:
                return response as! R.ResponseType
            case let .success(response) where response is Data:
                let response = try! R.ResponseType(statusCode: 200, headers: [:], data: response as! Data)
                return response
            case let .failure(error):
                throw error
            case let .wait(task):
                do {
                    let response = try await task.value
                    switch response {
                    case let response as R.ResponseType:
                        return response
                    case let data as Data:
                        let response = try! R.ResponseType(statusCode: 200, headers: [:], data: data)
                        return response
                    default:
                        XCTFail("We matched predicate, but Task`s value didn't match type. Expected response = \(R.ResponseType.self), actual response = \(response).")
                    }
                } catch {
                    switch error {
                    case let error as ApiClientError:
                        throw error
                    default:
                        XCTFail("Task failed with unexpected error \(error). request.url = \(info.url ?? "<nil>")")
                        throw .generalNetworkError(nil)
                    }
                }
            default:
                XCTFail("We matched predicate, but we didn't match type. Expected response = \(R.ResponseType.self), actual response = \(stub.result).")
                continue
            }
        }

        unhandledRequest(info)
        let error = ApiClientError.badStatusCode(statusCode: 404,
                                                 data: nil,
                                                 responseHeaders: [:],
                                                 request: info)
        throw error
    }

    // MARK: Private

    private let unhandledRequest: (RequestInfo) -> Void

    private struct Stub {
        enum Result: Sendable {
            case success(Sendable)
            case failure(ApiClientError)
            case wait(Task<Sendable, Error>)
        }
        let predicate: @Sendable (RequestInfo) -> Bool
        let didHitWrapper: DidHitWrapper
        let result: Result
    }

    private var stubs = [Stub]()
}

private protocol DidHitWrapper {
    func didHit(_ request: RequestInfo)
}

private final class NoParameterWrapper: DidHitWrapper {
    init(closure: @escaping @Sendable () -> Void) {
        self.closure = closure
    }

    // MARK: DidHitWrapper
    func didHit(_ request: RequestInfo) {
        closure()
    }

    // MARK: Private
    private let closure: () -> Void
}

private final class WrapperWithParameter: DidHitWrapper {
    init(closure: @escaping @Sendable (RequestInfo) -> Void) {
        self.closure = closure
    }

    // MARK: DidHitWrapper
    func didHit(_ request: RequestInfo) {
        closure(request)
    }

    // MARK: Private
    private let closure: (RequestInfo) -> Void
}
