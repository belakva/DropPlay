//
//  PlayerViewModel.swift
//  DropPlay
//
//  Created by Borisov Nikita on 17.12.2021.
//

import SwiftUI
import Combine

final class PlayerViewModel {

    struct Input {
        let play = PassthroughSubject<Void, Never>()
        let pause = PassthroughSubject<Void, Never>()
    }

    struct Output {
        let isPlayButtonEnabled: AnyPublisher<Bool, Never>
        let isPlaying: AnyPublisher<Bool, Never>
        let meterLevel: AnyPublisher<CGFloat, Never>
    }

    let input = Input()
    let output: Output

    private let player: Player

    private var bag = Set<AnyCancellable>()

    init(player: Player = Player()) {

        self.player = player

        output = Output(
            isPlayButtonEnabled: player.$isPlayerReady.eraseToAnyPublisher(),
            isPlaying: player.$isPlaying.eraseToAnyPublisher(),
            meterLevel: player.$meterLevel.map { CGFloat($0) }.eraseToAnyPublisher()
        )

        input.play.sink { [weak self] in
            self?.player.play()
        }.store(in: &bag)

        input.pause.sink { [weak self] in
            self?.player.pause()
        }.store(in: &bag)
    }
}

