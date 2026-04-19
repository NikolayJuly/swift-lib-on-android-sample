// JSONDecodableResponse.swift

import Foundation

public struct JSONDecodableResponse<Response: Decodable & Sendable>: ParsableFromUrlResponse {

    public let response: Response

    public init(statusCode: Int, headers: [String: String], data: Data) throws {

        let decoder = JSONDecoder()

        decoder.dateDecodingStrategy = .secondsSince1970

        response = try decoder.decode(Response.self, from: data)
    }

    // MARK: Test support

    public init(response: Response) {
        self.response = response
    }
}
