//
//  URLRequestExtension.swift
//  NetworkKit
//

import Foundation
import NetworkKitAPI

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension URLRequest {
    var requestInfo: RequestInfo {
        RequestInfo(url: url?.absoluteString,
                    httpMethod: httpMethod,
                    headers: allHTTPHeaderFields,
                    body: httpBody)
    }
}
