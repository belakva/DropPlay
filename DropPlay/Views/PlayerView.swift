//
//  ContentView.swift
//  DropPlay
//
//  Created by Borisov Nikita on 17.12.2021.
//

import SwiftUI

struct PlayerView: View {

    let viewModel: PlayerViewModel

    // Так как в этом приложении всего один MVVM модуль, я собираю его здесь, чтобы не усложнять
    // Обычно сборкой занимается координатор
    init() {
        let player = Player()
        viewModel = PlayerViewModel(player: player)
        player.bind(viewModel: viewModel)
    }

    var body: some View {
        VStack {
            Spacer()
            CentralView(viewModel: viewModel)
            Spacer()
            PlayPauseView(viewModel: viewModel)
        }
        .background(Color.black)
    }

    struct CentralView: View {
        let viewModel: PlayerViewModel

        @State private var isFileLoaded = false

        @ViewBuilder
        var body: some View {
            if isFileLoaded {
                VUMeterView(viewModel: viewModel)
            } else {
                DropItemView(viewModel: viewModel)
                    .onReceive(viewModel.output.view.isFileLoaded) { isFileLoaded = $0 }
            }
        }
    }

    struct DropItemView: View {
        let viewModel: PlayerViewModel
        let type = "public.file-url"

        @State private var isDraggedOver = false
        @State private var text = "Feed Me"

        var body: some View {
            Text(text)
            .onDrop(of: [type], isTargeted: $isDraggedOver)
            { providers -> Bool in
                providers.first?.loadDataRepresentation(
                    forTypeIdentifier: type,
                    completionHandler: { (data, error) in
                        if let error = error {
                            viewModel.input.view.errors.send(error)
                        } else {
                            viewModel.input.view.load.send(data)
                        }
                })
                return true
            }
            .multilineTextAlignment(.center)
            .frame(width: 200)
            .padding(40)
            .border(isDraggedOver ? Color.white : Color.clear)
            .onReceive(viewModel.output.view.errorText) { text = errorText($0) }
        }

        func errorText(_ text: String) -> String {
            return "Error: \n \(text). \n Try another file."
        }
    }

    struct VUMeterView: View {
        let viewModel: PlayerViewModel

        @State private var meterLevel: CGFloat = 0

        var body: some View {
            Color.white
            .frame(
                width: 35,
                height: 35 * meterLevel
            )
            .opacity(0.5 * meterLevel)
            .onReceive(viewModel.output.view.meterLevel) { meterLevel = $0 }
        }
    }

    struct PlayPauseView: View {
        let viewModel: PlayerViewModel

        @State private var isPlaying = false
        @State private var isDisabled = true

        var body: some View {
            Button {
                isPlaying ? viewModel.input.view.pause.send() : viewModel.input.view.play.send()
            } label: {
                isPlaying ? Image(systemName: "pause.fill") : Image(systemName: "play.fill")
            }
            .frame(width: 40)
            .padding(40)
            .disabled(isDisabled)
            .onReceive(viewModel.output.view.isPlayButtonEnabled) { isDisabled = !$0 }
            .onReceive(viewModel.output.view.isPlaying) { isPlaying = $0 }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView()
    }
}
