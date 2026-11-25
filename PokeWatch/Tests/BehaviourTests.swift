import XCTest
@testable import PokeWatch

final class MoodEngineTests: XCTestCase {
    let registry = CharacterRegistry.shared
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()

    func date(hour: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: hour, minute: 0))!
    }

    func inputs(hour: Int = 14, battery: Double? = 0.8, charging: Bool = false, steps: Double? = 0.2,
                quiet: Double? = nil) -> MoodInputs {
        MoodInputs(date: date(hour: hour), batteryLevel: battery, isCharging: charging, stepProgress: steps,
                   minutesSinceStepChange: quiet, calendar: cal)
    }

    func testChargingWins() {
        XCTAssertEqual(MoodEngine.mood(for: registry.character("pikachu"), inputs(battery: 0.05, charging: true)), .charging)
    }

    func testLowBatteryIsTired() {
        XCTAssertEqual(MoodEngine.mood(for: registry.character("pikachu"), inputs(battery: 0.12)), .tired)
    }

    func testGoalCelebration() {
        XCTAssertEqual(MoodEngine.mood(for: registry.character("psyduck"), inputs(steps: 1.05)), .celebrating)
    }

    func testStepLoverGetsExcitedNearGoal() {
        XCTAssertEqual(MoodEngine.mood(for: registry.character("pikachu"), inputs(steps: 0.85)), .excited)
        XCTAssertNotEqual(MoodEngine.mood(for: registry.character("snorlax"), inputs(steps: 0.85)), .excited)
    }

    func testSnorlaxSleepsWhenQuiet() {
        XCTAssertEqual(MoodEngine.mood(for: registry.character("snorlax"), inputs(quiet: 45)), .sleeping)
        XCTAssertNotEqual(MoodEngine.mood(for: registry.character("pikachu"), inputs(quiet: 45)), .sleeping)
    }

    func testNightBehaviourDependsOnPersonality() {
        XCTAssertEqual(MoodEngine.mood(for: registry.character("snorlax"), inputs(hour: 2)), .sleeping)
        XCTAssertEqual(MoodEngine.mood(for: registry.character("pikachu"), inputs(hour: 2)), .drowsy)
        // Gengar is a night owl: lively at night, drowsy in the morning.
        XCTAssertEqual(MoodEngine.mood(for: registry.character("gengar"), inputs(hour: 2)), .happy)
        XCTAssertEqual(MoodEngine.mood(for: registry.character("gengar"), inputs(hour: 8)), .drowsy)
    }

    func testNoHealthDataStillProducesMood() {
        let m = MoodEngine.mood(for: registry.character("eevee"), inputs(battery: nil, steps: nil))
        XCTAssertEqual(m, .calm)
    }
}

final class AnimatorTests: XCTestCase {
    let pikachu = CharacterRegistry.shared.character("pikachu")

    func testAlwaysOnPoseIsStaticAndAsleep() {
        let a = CompanionAnimator.pose(pikachu, AnimationInput(time: 10, mood: .excited, dimmed: true))
        let b = CompanionAnimator.pose(pikachu, AnimationInput(time: 47.3, mood: .celebrating, dimmed: true))
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.expression, .closed)
        XCTAssertEqual(a.particleLevel, 0)
    }

    func testReducedMotionRemovesMovement() {
        for t in stride(from: 0.0, to: 20, by: 0.37) {
            for mood in [Mood.calm, .excited, .celebrating] {
                let p = CompanionAnimator.pose(pikachu, AnimationInput(time: t, mood: mood, variant: .dance, motionScale: 0))
                XCTAssertEqual(p.dx, 0); XCTAssertEqual(p.dy, 0, accuracy: 1e-9); XCTAssertEqual(p.rotation, 0, accuracy: 1e-9)
            }
        }
    }

    func testWakeSequenceEndsWithHappyHop() {
        let start = CompanionAnimator.pose(pikachu, AnimationInput(time: 0, mood: .calm, wakeElapsed: 0.1))
        let end = CompanionAnimator.pose(pikachu, AnimationInput(time: 0, mood: .calm, wakeElapsed: 1.2))
        XCTAssertEqual(start.expression, .closed)
        XCTAssertEqual(end.expression, .happy)
        XCTAssertLessThan(end.dy, 0)
        XCTAssertEqual(start.speech, pikachu.lines.wake)
    }

    func testTapReactionJumpsAndSpeaks() {
        let p = CompanionAnimator.pose(pikachu, AnimationInput(time: 0, mood: .calm, reactionElapsed: 0.3))
        XCTAssertLessThan(p.dy, 0)
        XCTAssertEqual(p.expression, .happy)
        XCTAssertNotNil(p.speech)
    }

    func testBlinksHappenButRarely() {
        var blinks = 0, samples = 0
        for t in stride(from: 0.0, to: 120, by: 0.05) {
            samples += 1
            if CompanionAnimator.isBlinking(t, interval: pikachu.personality.blinkInterval, seed: pikachu.seed) { blinks += 1 }
        }
        XCTAssertGreaterThan(blinks, 0)
        XCTAssertLessThan(Double(blinks) / Double(samples), 0.15)
    }

    func testSleepingShowsZAndClosedEyes() {
        let p = CompanionAnimator.pose(pikachu, AnimationInput(time: 3, mood: .sleeping))
        XCTAssertEqual(p.expression, .closed)
        XCTAssertTrue(p.showsZ)
    }
}

final class MotionPolicyTests: XCTestCase {
    func testFrameRateAdapts() {
        let p = MotionPolicy(intensity: .lively, reducedMotion: false, lowPower: false)
        XCTAssertEqual(p.framesPerSecond(secondsSinceEngagement: 0), 30)
        XCTAssertEqual(p.framesPerSecond(secondsSinceEngagement: 60), 15)
        let low = MotionPolicy(intensity: .lively, reducedMotion: false, lowPower: true)
        XCTAssertLessThanOrEqual(low.framesPerSecond(secondsSinceEngagement: 0), 6)
        XCTAssertFalse(low.particlesEnabled)
        let rm = MotionPolicy(intensity: .lively, reducedMotion: true, lowPower: false)
        XCTAssertEqual(rm.motionScale, 0)
        XCTAssertEqual(rm.framesPerSecond(secondsSinceEngagement: 0), 4)
    }

    func testVariantCycles() {
        var v = AnimationVariant.idle
        for _ in AnimationVariant.allCases { v = v.next }
        XCTAssertEqual(v, .idle)
    }
}
