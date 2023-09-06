//
//  Array+Extensions.swift
//
//
//  Created by martin on 05/09/2023.
//

import Foundation

extension Array where Element == URLQueryItem {
    func value(for name: String) throws -> String? {
        let matchingQueryItems = self.filter { $0.name == name }
        guard matchingQueryItems.count <= 1 else {
            throw DeserializationError.duplicateQueryItem(name)
        }
        return matchingQueryItems.first?.value
    }
}
