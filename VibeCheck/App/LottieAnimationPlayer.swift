import SwiftUI
import Lottie

struct LottieAnimationPlayer: UIViewRepresentable {
    let animationName: String
    var loopMode: LottieLoopMode = .loop

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear

        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.loopMode = loopMode
        animationView.animation = resolveAnimation(named: animationName)
        animationView.play()

        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let animationView = uiView.subviews.first as? LottieAnimationView else { return }
        if animationView.animation == nil {
            animationView.animation = resolveAnimation(named: animationName)
        }
        animationView.loopMode = loopMode
        if !animationView.isAnimationPlaying {
            animationView.play()
        }
    }

    private func resolveAnimation(named name: String) -> LottieAnimation? {
        if let bundled = LottieAnimation.named(name) {
            return bundled
        }

        let localPath = "/Users/sr90052857/Desktop/\(name).json"
        if FileManager.default.fileExists(atPath: localPath) {
            return LottieAnimation.filepath(localPath)
        }

        return nil
    }
}
