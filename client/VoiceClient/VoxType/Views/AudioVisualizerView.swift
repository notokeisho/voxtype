import SwiftUI

/// View that displays audio level as animated vertical bars.
/// Creates a visualizer effect that responds to audio input levels.
struct AudioVisualizerView: View {
    /// Current audio level from 0.0 to 1.0.
    let audioLevel: Float

    /// Number of bars to display.
    private let barCount = 24

    /// Width of each bar in points.
    private let barWidth: CGFloat = 3

    /// Spacing between bars in points.
    private let barSpacing: CGFloat = 2

    /// Maximum height of bars in points.
    private let maxBarHeight: CGFloat = 30

    /// Minimum height of bars in points (shows activity even at low levels).
    private let minBarHeight: CGFloat = 3

    /// Current bar heights with random variation.
    @State private var barHeights: [CGFloat] = []

    /// Timer for updating bar animation.
    @State private var animationTimer: Timer?

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor)
                    .frame(width: barWidth, height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.05), value: barHeights)
            }
        }
        .onAppear {
            initializeBarHeights()
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: audioLevel) { _ in
            updateBarHeights()
        }
    }

    // MARK: - Private Computed Properties

    /// Bar color that adapts to system appearance.
    private var barColor: Color {
        Color.primary.opacity(0.8)
    }

    // MARK: - Private Methods

    /// Initialize bar heights array.
    private func initializeBarHeights() {
        barHeights = Array(repeating: minBarHeight, count: barCount)
    }

    /// Get the height for a specific bar index.
    private func barHeight(for index: Int) -> CGFloat {
        guard index < barHeights.count else { return minBarHeight }
        return barHeights[index]
    }

    /// Start the animation timer for smooth updates.
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updateBarHeights()
        }
    }

    /// Stop the animation timer.
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    /// Update bar heights based on current audio level with randomization.
    private func updateBarHeights() {
        let level = CGFloat(audioLevel)

        // Create wave-like pattern centered in the middle
        let centerIndex = barCount / 2

        barHeights = (0..<barCount).map { index in
            // Distance from center (0.0 to 1.0)
            let distanceFromCenter = abs(CGFloat(index - centerIndex)) / CGFloat(centerIndex)

            // Base amplitude decreases towards edges (wave-like shape)
            let baseAmplitude = 1.0 - (distanceFromCenter * 0.6)

            // Add randomness for natural look
            let randomFactor = CGFloat.random(in: 0.7...1.3)

            // Calculate height based on audio level
            let targetHeight = level * baseAmplitude * randomFactor * maxBarHeight

            // Ensure minimum height for visual activity
            let height = max(minBarHeight, targetHeight)

            // Add small idle animation when audio level is low
            if level < 0.1 {
                let idleVariation = CGFloat.random(in: 0.8...1.2)
                return minBarHeight * idleVariation
            }

            return min(height, maxBarHeight)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AudioVisualizerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Silent state
            AudioVisualizerView(audioLevel: 0.0)
                .padding()
                .background(Color.gray.opacity(0.2))
                .previewDisplayName("Silent")

            // Low level
            AudioVisualizerView(audioLevel: 0.3)
                .padding()
                .background(Color.gray.opacity(0.2))
                .previewDisplayName("Low")

            // Medium level
            AudioVisualizerView(audioLevel: 0.6)
                .padding()
                .background(Color.gray.opacity(0.2))
                .previewDisplayName("Medium")

            // High level
            AudioVisualizerView(audioLevel: 1.0)
                .padding()
                .background(Color.gray.opacity(0.2))
                .previewDisplayName("High")
        }
        .padding()
    }
}
#endif
