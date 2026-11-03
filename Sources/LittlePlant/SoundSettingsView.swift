import SwiftUI

struct SoundSettingsView: View {
    @ObservedObject private var audio = AudioSettings.shared
    var english: Bool
    private func t(_ ko:String,_ en:String) -> String { english ? en : ko }
    var body: some View {
        VStack(alignment:.leading,spacing:11) {
            HStack {
                Label(t("음향", "Sound"),systemImage:"speaker.wave.2").font(.system(size:12,weight:.medium))
                Spacer()
                Toggle(t("음소거", "Mute all"),isOn:$audio.muted).toggleStyle(.switch).controlSize(.mini).font(.system(size:10))
            }
            volume(t("배경음악", "Music"),value:$audio.musicVolume)
            volume(t("효과음", "Sound effects"),value:$audio.effectsVolume)
            Toggle(isOn:$audio.rainEnabled) {
                Label(t("비 소리", "Rain sounds"),systemImage:"cloud.rain")
                    .font(.system(size:11))
            }.toggleStyle(.switch).controlSize(.small)
        }
        .tint(Color(red:0.32,green:0.60,blue:0.45))
    }
    private func volume(_ title:String,value:Binding<Double>) -> some View {
        VStack(spacing:3) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((value.wrappedValue*100).rounded()))%")
                    .monospacedDigit().foregroundStyle(.secondary)
            }.font(.system(size:11))
            Slider(value:value,in:0...1).controlSize(.small)
                .disabled(audio.muted).accessibilityLabel(title)
        }
    }
}
