//
//  ContentView.swift
//  DropPlay
//
//  Created by Borisov Nikita on 17.12.2021.
//

import SwiftUI

struct PlayerView: View {
    let viewModel = PlayerViewModel()
    @State var isDisabled = true
    @State var isPlaying = false
    @State var meterLevel: CGFloat = 0

    var body: some View {
        VStack {
            Spacer()
            vUMeter
            Spacer()
            playPause
        }
        .background(Color.black)
    }

    private var vUMeter: some View {
        Color.white
        .frame(
            width: 35,
            height: 35 * meterLevel
        )
        .opacity(0.5 * meterLevel)
        .onReceive(viewModel.output.meterLevel) { meterLevel = $0 }
    }

    private var playPause: some View {
        Button {
            isPlaying ? viewModel.input.pause.send() : viewModel.input.play.send()
        } label: {
            isPlaying ? Image(systemName: "pause.fill") : Image(systemName: "play.fill")
        }
        .frame(width: 40)
        .padding(40)
        .disabled(isDisabled)
        .onReceive(viewModel.output.isPlayButtonEnabled) { isDisabled = !$0 }
        .onReceive(viewModel.output.isPlaying) { isPlaying = $0 }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView()
    }
}
