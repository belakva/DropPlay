//
//  Extensions.swift
//  DropPlay
//
//  Created by Borisov Nikita on 19.12.2021.
//

import Combine

extension Publisher {
    /// Wraps this publisher with a type eraser.
    public func erase() -> AnyPublisher<Self.Output, Self.Failure> {
        self.eraseToAnyPublisher()
    }
}
