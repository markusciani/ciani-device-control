import SwiftUI

struct AnimatedGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var preset: GradientPreset = .aurora
    var vibrantOnBlack = false
    var animates = true
    @State private var shifted = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if vibrantOnBlack { Color.black }
                LinearGradient(colors: palette.base, startPoint: shifted ? .topLeading : .bottomTrailing,
                               endPoint: shifted ? .bottomTrailing : .topLeading)
                    .opacity(vibrantOnBlack ? 0.42 : 1)
                Circle().fill(palette.accent1).blur(radius: 100)
                    .frame(width: proxy.size.width * (vibrantOnBlack ? 0.62 : 0.8)).offset(x: shifted ? proxy.size.width * 0.25 : -proxy.size.width * 0.3,
                                                                  y: shifted ? -proxy.size.height * 0.25 : proxy.size.height * 0.2)
                    .blendMode(vibrantOnBlack ? .screen : .normal)
                Circle().fill(palette.accent2).blur(radius: 130)
                    .frame(width: proxy.size.width * (vibrantOnBlack ? 0.7 : 0.9)).offset(x: shifted ? -proxy.size.width * 0.25 : proxy.size.width * 0.3,
                                                                  y: shifted ? proxy.size.height * 0.25 : -proxy.size.height * 0.2)
                    .blendMode(vibrantOnBlack ? .screen : .normal)
                if vibrantOnBlack {
                    Ellipse().fill(palette.accent3).blur(radius: 110)
                        .frame(width: proxy.size.width * 0.7, height: proxy.size.height * 0.42)
                        .rotationEffect(.degrees(shifted ? 22 : -18))
                        .offset(x: shifted ? proxy.size.width * 0.08 : -proxy.size.width * 0.14,
                                y: shifted ? proxy.size.height * 0.34 : -proxy.size.height * 0.3)
                        .blendMode(.screen)
                    RadialGradient(colors: [.clear, .black.opacity(0.78)], center: .center, startRadius: 120,
                                   endRadius: max(proxy.size.width, proxy.size.height) * 0.72)
                }
            }
            .scaleEffect(1.25)
            .onAppear {
                guard animates, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) { shifted = true }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var palette: (base: [Color], accent1: Color, accent2: Color, accent3: Color) {
        let dark = colorScheme == .dark
        if vibrantOnBlack {
            switch preset {
            case .aurora: return ([.black, Color(red: 0.02, green: 0.02, blue: 0.12)], Color(red: 0.66, green: 0.05, blue: 1), Color(red: 0, green: 0.82, blue: 1), Color(red: 1, green: 0.03, blue: 0.55))
            case .indigo: return ([.black, Color(red: 0.02, green: 0.02, blue: 0.14)], Color(red: 0.22, green: 0.12, blue: 1), Color(red: 0.55, green: 0.08, blue: 1), Color(red: 0, green: 0.55, blue: 1))
            case .ocean: return ([.black, Color(red: 0, green: 0.06, blue: 0.12)], Color(red: 0, green: 0.9, blue: 1), Color(red: 0, green: 0.28, blue: 1), Color(red: 0, green: 1, blue: 0.62))
            case .purpleNight: return ([.black, Color(red: 0.08, green: 0, blue: 0.12)], Color(red: 0.82, green: 0, blue: 1), Color(red: 1, green: 0, blue: 0.52), Color(red: 0.25, green: 0.08, blue: 1))
            case .dynamic: return ([.black, Color(red: 0.02, green: 0, blue: 0.1)], Color(red: 1, green: 0, blue: 0.48), Color(red: 0, green: 0.85, blue: 1), Color(red: 0.62, green: 0.04, blue: 1))
            case .sunset: return ([.black, Color(red: 0.16, green: 0.025, blue: 0.01)], Color(red: 1, green: 0.22, blue: 0.02), Color(red: 1, green: 0.68, blue: 0.02), Color(red: 1, green: 0.03, blue: 0.38))
            case .emerald: return ([.black, Color(red: 0, green: 0.11, blue: 0.07)], Color(red: 0, green: 1, blue: 0.56), Color(red: 0, green: 0.58, blue: 0.34), Color(red: 0.08, green: 0.9, blue: 0.86))
            case .rose: return ([.black, Color(red: 0.14, green: 0.01, blue: 0.07)], Color(red: 1, green: 0.12, blue: 0.48), Color(red: 0.72, green: 0.05, blue: 1), Color(red: 1, green: 0.38, blue: 0.65))
            case .electric: return ([.black, Color(red: 0.01, green: 0.03, blue: 0.16)], Color(red: 0.05, green: 0.42, blue: 1), Color(red: 0, green: 1, blue: 0.95), Color(red: 0.58, green: 0.05, blue: 1))
            }
        }
        switch preset {
        case .aurora: return dark ? ([Color.indigo, Color(red: 0.05, green: 0.08, blue: 0.2)], .purple.opacity(0.75), .cyan.opacity(0.5), .pink.opacity(0.4))
                                  : ([Color(red: 0.78, green: 0.86, blue: 1), .white], .purple.opacity(0.35), .cyan.opacity(0.45), .pink.opacity(0.25))
        case .indigo: return dark ? ([.indigo, .black], .blue.opacity(0.7), .purple.opacity(0.6), .indigo)
                                  : ([Color.indigo.opacity(0.45), .white], .blue.opacity(0.35), .purple.opacity(0.3), .indigo.opacity(0.2))
        case .ocean: return dark ? ([Color(red: 0, green: 0.12, blue: 0.25), .black], .cyan.opacity(0.6), .blue.opacity(0.7), .mint.opacity(0.4))
                                 : ([Color.cyan.opacity(0.35), .white], .blue.opacity(0.3), .mint.opacity(0.4), .cyan.opacity(0.2))
        case .purpleNight: return dark ? ([Color(red: 0.12, green: 0.03, blue: 0.22), .black], .purple.opacity(0.8), .pink.opacity(0.5), .indigo.opacity(0.5))
                                       : ([Color.purple.opacity(0.35), .white], .pink.opacity(0.3), .indigo.opacity(0.3), .purple.opacity(0.2))
        case .dynamic: return dark ? ([.blue, Color(red: 0.08, green: 0.02, blue: 0.18)], .pink.opacity(0.6), .cyan.opacity(0.55), .purple.opacity(0.5))
                                   : ([Color.blue.opacity(0.35), Color.purple.opacity(0.18)], .pink.opacity(0.3), .cyan.opacity(0.4), .purple.opacity(0.2))
        case .sunset: return dark ? ([Color(red: 0.25, green: 0.04, blue: 0.02), .black], .orange.opacity(0.8), .yellow.opacity(0.55), .pink.opacity(0.5))
                                  : ([.orange.opacity(0.35), .yellow.opacity(0.18)], .red.opacity(0.28), .yellow.opacity(0.4), .pink.opacity(0.25))
        case .emerald: return dark ? ([Color(red: 0, green: 0.18, blue: 0.11), .black], .green.opacity(0.75), .mint.opacity(0.6), .cyan.opacity(0.35))
                                   : ([.green.opacity(0.3), .mint.opacity(0.18)], .green.opacity(0.3), .mint.opacity(0.42), .cyan.opacity(0.2))
        case .rose: return dark ? ([Color(red: 0.22, green: 0.02, blue: 0.12), .black], .pink.opacity(0.8), .purple.opacity(0.55), .red.opacity(0.35))
                                : ([.pink.opacity(0.3), .purple.opacity(0.14)], .pink.opacity(0.35), .purple.opacity(0.28), .red.opacity(0.18))
        case .electric: return dark ? ([Color(red: 0.02, green: 0.06, blue: 0.28), .black], .blue.opacity(0.85), .cyan.opacity(0.7), .purple.opacity(0.5))
                                    : ([.blue.opacity(0.3), .cyan.opacity(0.16)], .blue.opacity(0.35), .cyan.opacity(0.4), .purple.opacity(0.22))
        }
    }
}

extension View {
    @ViewBuilder func expandedFont() -> some View {
        if #available(iOS 16.0, tvOS 16.0, *) { self.fontWidth(.expanded) } else { self }
    }

    @ViewBuilder func compressedFont() -> some View {
        if #available(iOS 16.0, tvOS 16.0, *) { self.fontWidth(.compressed) } else { self }
    }
}
