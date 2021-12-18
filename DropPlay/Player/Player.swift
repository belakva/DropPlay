//
//  Player.swift
//  DropPlay
//
//  Created by Borisov Nikita on 17.12.2021.
//

import AVFoundation
import Combine

class Player {

    @Published private(set) var isPlayerReady = false
    @Published private(set) var isPlaying = false
    @Published private(set) var meterLevel: Float = 0

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private var audioFile: AVAudioFile?
    private var needsFileScheduled = true

    init() {
        setupAudio()
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        connectVolumeTap()
        if let file = audioFile, needsFileScheduled {
            schedule(file: file)
        }
        player.play()
    }

    func pause() {
        guard isPlaying else { return }
        onPlaybackFinish()
        player.pause()
    }

    private func onPlaybackFinish() {
        isPlaying = false
        disconnectVolumeTap()
    }

    // MARK: - Setup

    private func setupAudio() {
        guard let fileURL = Bundle.main.url(forResource: "Intro", withExtension: "mp3") else {
            return
        }

        do {
            let file = try AVAudioFile(forReading: fileURL)
            audioFile = file
            configureEngine(with: file)
        } catch {
            print("Error reading the audio file: \(error.localizedDescription)")
        }
    }

    private func configureEngine(with file: AVAudioFile) {
        engine.attach(player)
        engine.connect(
            player,
            to: engine.mainMixerNode,
            format: file.processingFormat
        )
        engine.prepare()

        do {
            try engine.start()

            schedule(file: file)
            isPlayerReady = true
        } catch {
            print("Error starting the player: \(error.localizedDescription)")
        }
    }

    private func schedule(file: AVAudioFile) {
        guard let file = audioFile, needsFileScheduled else {
            return
        }

        needsFileScheduled = false
        player.scheduleFile(file, at: nil) {
            DispatchQueue.main.async {
                self.needsFileScheduled = true
                self.onPlaybackFinish()
            }
        }
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

    private func connectVolumeTap() {
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
                self.meterLevel = self.isPlaying ? meterLevel : 0
            }
        }
    }

    private func disconnectVolumeTap() {
        engine.mainMixerNode.removeTap(onBus: 0)
        meterLevel = 0
    }
}