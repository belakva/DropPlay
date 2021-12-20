//
//  PlayerViewModel.swift
//  DropPlay
//
//  Created by Borisov Nikita on 17.12.2021.
//

import SwiftUI
import Combine

final class PlayerViewModel {

    // Из вьюхи во вьюмодель приходят события
    // Вьюмодель подготавливает их и посылает плееру
    // Плеер посылает во вьюмодель события, которые с ним случаются
    // Вьюмодель мапит их в стэйт вьюхи

    struct Input {
        struct View {
            let load = PassthroughSubject<Data?, Never>()
            let play = PassthroughSubject<Void, Never>()
            let pause = PassthroughSubject<Void, Never>()
            let errors = PassthroughSubject<Error, Never>()
        }
        struct Player {
            let didStartPreparing = PassthroughSubject<Void, Never>()
            let readyToPlay = PassthroughSubject<Void, Never>()
            let didStartPlayback = PassthroughSubject<Void, Never>()
            let paused = PassthroughSubject<Void, Never>()
            let didReachEnd = PassthroughSubject<Void, Never>()
            let errors = PassthroughSubject<DropPlay.Player.PlayerError, Never>()
            let meterLevel = PassthroughSubject<Float, Never>()
        }
        let view = View()
        let player = Player()
    }

    struct Output {
        struct View {
            let isFileLoaded: AnyPublisher<Bool, Never>
            let isPlayButtonEnabled: AnyPublisher<Bool, Never>
            let isPlaying: AnyPublisher<Bool, Never>
            let errorText: AnyPublisher<String, Never>
            let meterLevel: AnyPublisher<CGFloat, Never>
        }
        struct Player {
            let load: AnyPublisher<URL, Never>
            let play: AnyPublisher<Void, Never>
            let pause: AnyPublisher<Void, Never>
        }
        let view: View
        let player: Player
    }

    private enum State {
        case empty
        case preparing
        case readyToPlay
        case playing
        case paused
    }

    enum URLParseError: Error, LocalizedError {
        case loadData(errorDescription: String)
        case noData
        case convertDataToString
        case buildURLFromString

        public var errorDescription: String? {
            let commonPart = "File URL parsing failed: "
            switch self {
            case .loadData(let desc):   return "Load Data Failed: " + desc
            case .noData:               return commonPart + "No Data."
            case .convertDataToString:  return commonPart + "Data to String conversion failed."
            case .buildURLFromString:   return commonPart + "Failed building URL form String."
            }
        }
    }

    let input = Input()
    let output: Output

    private let player: Player

    init(player: Player) {

        self.player = player

        let loadErrors = PassthroughSubject<URLParseError, Never>()

        let load = input.view.load.map { data -> URL? in

            guard let data = data else {
                loadErrors.send(.noData)
                return nil
            }

            guard let string = String(data: data, encoding: .utf8) else {
                loadErrors.send(.convertDataToString)
                return nil
            }

            guard let url = URL(string: string) else {
                loadErrors.send(.buildURLFromString)
                return nil
            }

            return url
        }.compactMap { $0 }.erase()

        let errorMessages = loadErrors.map { $0.localizedDescription }.merge(with:
            input.player.errors.map { $0.localizedDescription },
            input.view.errors.map { URLParseError.loadData(errorDescription: $0.localizedDescription) }.map { $0.localizedDescription }
        )

        let state = Self.state(input: input.player)

        output = Output(
            view: Output.View(
                isFileLoaded: state.map { $0 != .empty }.erase(),
                isPlayButtonEnabled: state.map { $0 != .empty && $0 != .preparing }.erase(),
                isPlaying: state.map { $0 == .playing }.erase(),
                errorText: errorMessages.erase(),
                meterLevel: input.player.meterLevel.map { CGFloat ($0) }.erase()
            ),
            player: Output.Player(
                load: load,
                play: input.view.play.erase(),
                pause: input.view.pause.erase()
            )
        )
    }

    private static func state(input: Input.Player) -> AnyPublisher<State, Never> {

        enum StateChange {
            case preparing
            case readyToPlay
            case playing
            case paused
            case didReachEnd
            case error
        }

        let didStartPreparing = input.didStartPreparing.map { StateChange.preparing }
        let readyToPlay = input.readyToPlay.map { StateChange.readyToPlay }
        let didStartPlayback = input.didStartPlayback.map { StateChange.playing }
        let paused = input.paused.map { StateChange.paused }
        let didReachEnd = input.didReachEnd.map { StateChange.didReachEnd }
        let error = input.errors.map { _ in StateChange.error }

        let stateChange = didStartPreparing.merge(with: readyToPlay, didStartPlayback, paused, didReachEnd, error)

        return stateChange.scan(.empty) { state, action in
            switch action {
            case .preparing:    return .preparing
            case .readyToPlay:  return .readyToPlay
            case .playing:      return .playing
            case .paused:       return .paused
            case .error, .didReachEnd:  return .empty
            }
        }.erase()
    }
}

