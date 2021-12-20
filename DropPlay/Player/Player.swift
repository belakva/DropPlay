//
//  Player.swift
//  DropPlay
//
//  Created by Borisov Nikita on 17.12.2021.
//

import AVFoundation
import Combine

final class Player {

    typealias Output = PlayerViewModel.Input.Player

    enum PlayerError: Error {
        case readFile(errorDescription: String)
        case startPlayer(errorDescription: String)

        public var errorDescription: String? {
            switch self {
            case .readFile(let desc):       return desc
            case .startPlayer(let desc):    return desc
            }
        }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private var audioFile: AVAudioFile?
    private var needsFileScheduled = true

    private var bag = Set<AnyCancellable>()

    func bind(viewModel: PlayerViewModel) {
        let output = viewModel.input.player
        let input = viewModel.output.player

        input.load
            .receive(on: DispatchQueue.main)
            .sink
        { [weak self] url in // TODO: сделать тест на лики, может не нужен weak
            do {
                let file = try AVAudioFile(forReading: url)
                output.didStartPreparing.send()
                self?.audioFile = file
                self?.configureEngine(with: file, output: output)
            } catch {
                output.errors.send(.readFile(errorDescription: error.localizedDescription))
            }
        }.store(in: &bag)

        input.play
            .receive(on: DispatchQueue.main)
            .sink
        { [weak self] in
            self?.play(output: output)
        }.store(in: &bag)

        input.pause
            .receive(on: DispatchQueue.main)
            .sink
        { [weak self] in
            self?.pause(output: output)
        }.store(in: &bag)
    }

    // MARK: - Load

    private func configureEngine(with file: AVAudioFile, output: Output) {
        engine.attach(player)
        engine.connect(
            player,
            to: engine.mainMixerNode,
            format: file.processingFormat
        )
        engine.prepare()

        do {
            try engine.start()

            schedule(file: file, output: output)
            output.readyToPlay.send()

            play(output: output)
        } catch {
            output.errors.send(.startPlayer(errorDescription: error.localizedDescription))
        }
    }

    private func schedule(file: AVAudioFile, output: Output) {
        guard let file = audioFile, needsFileScheduled else {
            return
        }

        needsFileScheduled = false
        player.scheduleFile(file, at: nil) {
            DispatchQueue.main.async {
                self.needsFileScheduled = true
                self.disconnectVolumeTap()
                output.didReachEnd.send()
            }
        }
    }

    // MARK: - Playback

    func play(output: Output) {
        connectVolumeTap(output: output)
        if let file = audioFile, needsFileScheduled {
            schedule(file: file, output: output)
        }
        player.play()
        output.didStartPlayback.send()
    }

    func pause(output: Output) {
        disconnectVolumeTap()
        player.pause()
        output.paused.send()
    }

    // MARK: - VU Meter

    private func scaledPower(power: Float) -> Float {
        guard power.isFinite else { return 0 }

        let minDb: Float = -80

        if power < minDb {
            return 0.0
        } else if power >= 1.0 {
            return 1.0
        } else {
            return (abs(minDb) - abs(power)) / abs(minDb)
        }
    }

    private func connectVolumeTap(output: Output) {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)

        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { buffer, _ in
            guard let channelData = buffer.floatChannelData else {
                return
            }

            let channelDataValue = channelData.pointee
            let channelDataValueArray = stride(
                from: 0,
                to: Int(buffer.frameLength),
                by: buffer.stride
            )
                .map { channelDataValue[$0] }

            let rms = sqrt(channelDataValueArray.map {
                return $0 * $0
            }
                            .reduce(0, +) / Float(buffer.frameLength))

            let avgPower = 20 * log10(rms)
            let meterLevel = self.scaledPower(power: avgPower)

            DispatchQueue.main.async {
                output.meterLevel.send(meterLevel)
            }
        }
    }

    private func disconnectVolumeTap() {
        engine.mainMixerNode.removeTap(onBus: 0)
        // TODO: нужно ли сбрасывать метер? meterLevel = 0
    }
}
