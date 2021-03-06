//
//  ContentView.swift
//  DropPlay
//
//  Created by Borisov Nikita on 17.12.2021.
//

import SwiftUI
import Combine

struct PlayerView: View {

    let viewModel: PlayerViewModel

    // Так как в этом приложении всего один MVVM модуль, я собираю его здесь, чтобы не усложнять
    // Обычно сборкой занимается координатор

    init() {
        let player = Player()
        viewModel = PlayerViewModel(player: player)
        player.bind(viewModel: viewModel)
    }

    @State private var isFileLoaded = false

    var body: some View {
        ZStack {
            SharkView(viewModel: viewModel, isFileLoaded: $isFileLoaded)
            VStack {
                CentralView(viewModel: viewModel, isFileLoaded: $isFileLoaded)
                    .onReceive(viewModel.output.view.isFileLoaded) { isFileLoaded = $0 }
                Spacer()
                HStack {
                    StopView(viewModel: viewModel)
                    Spacer()
                    PlayPauseView(viewModel: viewModel)
                }
            }
        }
        .background(Color.white)
    }

    struct SharkView: View {
        let viewModel: PlayerViewModel

        @Binding var isFileLoaded: Bool
        @State private var isDraggedOver = false

        let open = "shark_open"
        let closed = "shark_closed"
        let type = "public.file-url"

        @ViewBuilder
        var body: some View {
            ZStack {
                if isFileLoaded {
                    Image(closed)
                } else if !isDraggedOver {
                    Image(open)
                } else {
                    BlinkView(open: open, closed: closed)
                }
            }
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
        }


        private struct BlinkView: View {
            @State private var isHowling = false

            let open: String
            let closed: String
            let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

            var body: some View {
                ZStack {
                    isHowling ? Image(open) : Image(closed)
                }
                .onReceive(timer) { _ in
                    isHowling.toggle()
                }
            }

        }
    }

    struct CentralView: View {
        let viewModel: PlayerViewModel
        @Binding var isFileLoaded: Bool

        @ViewBuilder
        var body: some View {
            if isFileLoaded {
                VUMeterView(viewModel: viewModel)
            } else {
                ErrorView(viewModel: viewModel)
            }
        }
    }

    struct ErrorView: View {
        let viewModel: PlayerViewModel

        @State private var text = ""

        var body: some View {
            Text(text)
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(.red)
            .multilineTextAlignment(.center)
            .frame(width: 600, height: 150)
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
            Image("brows")
                .padding(.top, 190 - 60 * meterLevel)
                .onReceive(viewModel.output.view.meterLevel) { meterLevel = $0 }
        }
    }

    struct PlayPauseView: View {
        let viewModel: PlayerViewModel

        @State private var isPlaying = false
        @State private var isDisabled = true

        var body: some View {
            ButtonSized {
                Button {
                    isPlaying ? viewModel.input.view.pause.send() : viewModel.input.view.play.send()
                } label: {
                    ButtonSized {
                        isPlaying ? Image("pause").resizable() : Image("play").resizable()
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isDisabled)
            }
            .onReceive(viewModel.output.view.isPlayButtonEnabled) { isDisabled = !$0 }
            .onReceive(viewModel.output.view.isPlaying) { isPlaying = $0 }
        }
    }

    struct StopView: View {
        let viewModel: PlayerViewModel

        @State private var isDisabled = true

        var body: some View {
            ButtonSized {
                Button {
                    viewModel.input.view.stop.send()
                } label: {
                    ButtonSized {
                        Image("stop").resizable()
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isDisabled)
            }
            .onReceive(viewModel.output.view.isPlayButtonEnabled) { isDisabled = !$0 }
        }
    }

    
    struct ButtonSized<Content: View>: View {
        @ViewBuilder var content: Content

        var body: some View {
            content
                .frame(width: 60, height: 60)
                .padding(10)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView()
    }
}
