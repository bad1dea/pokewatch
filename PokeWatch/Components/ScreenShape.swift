import CoreGraphics

/// The Apple Watch Ultra display is a superellipse: its corners hide anything placed
/// near them. This profile was measured from the Ultra 3 simulator's device mask
/// (422 × 514 px, `simctl io screenshot --mask=alpha`): at a given distance from the top
/// or bottom edge, how far in from the side the visible area starts.
enum ScreenShape {
    /// (distance from the top/bottom edge, horizontal inset), points at 211 × 257.
    static let profile: [(CGFloat, CGFloat)] = [
        (0, 86), (2, 46.5), (4, 38.5), (6, 33), (8, 28.5), (10, 25.5), (12, 22.5), (14, 20), (16, 17.5),
        (18, 15.5), (20, 14), (22, 12.5), (24, 11), (26, 9.5), (28, 8.5), (30, 7.5), (32, 6.5), (34, 5.5),
        (36, 5), (38, 4.5), (40, 3.5), (44, 2.5), (48, 2), (52, 1.5), (56, 1), (62, 0.5), (72, 0),
    ]
    static let referenceHeight: CGFloat = 257

    /// Horizontal inset at `distance` points from the nearest top/bottom edge, for a screen `height` tall.
    static func inset(atEdgeDistance distance: CGFloat, screenHeight height: CGFloat = referenceHeight) -> CGFloat {
        let k = height / referenceHeight
        let d = max(0, distance / k)
        guard let upper = profile.firstIndex(where: { $0.0 >= d }) else { return 0 }
        if upper == 0 { return profile[0].1 * k }
        let (d0, i0) = profile[upper - 1], (d1, i1) = profile[upper]
        return (i0 + (i1 - i0) * (d - d0) / (d1 - d0)) * k
    }

    /// Inset needed for content spanning `minY...maxY` (points from the top) on a screen `height` tall,
    /// plus a small margin so glyph edges never touch the mask.
    static func inset(forBand minY: CGFloat, _ maxY: CGFloat, screenHeight height: CGFloat, margin: CGFloat = 3) -> CGFloat {
        let nearest = min(minY, height - maxY)
        return inset(atEdgeDistance: nearest, screenHeight: height) + margin
    }
}
