import Foundation

/// Deterministic RNG so a card's procedural placeholder art looks the same every launch.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17; return state
    }
    mutating func unit() -> Double { Double(next() % 10_000) / 10_000.0 }
}
