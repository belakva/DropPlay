//
//  DropPlayTests.swift
//  DropPlayTests
//
//  Created by Borisov Nikita on 20.12.2021.
//

import XCTest
@testable import DropPlay

class DropPlayTests: XCTestCase {

    // Один простой тест проверяет, что при биндинге не произошло утечек
    // (если убрать [weak self] в замыканиях в player.bind(viewModel:), тест упадёт)

    func testHasNoMemoryLeaks() throws {
        weak var weakPlayer: Player?
        weak var weakViewModel: PlayerViewModel?
        autoreleasepool {
            let player = Player()
            let viewModel = PlayerViewModel(player: player)
            player.bind(viewModel: viewModel)

            weakViewModel = viewModel
            weakPlayer = player
        }
        let allReleased = weakPlayer == nil && weakViewModel == nil
        XCTAssertTrue(allReleased)
    }
}
