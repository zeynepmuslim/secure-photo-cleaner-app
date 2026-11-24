//
//  WaitUntil.swift
//  PurgioTests
//

/// Yields until `condition` holds, for work that lands on the main actor from detached observers.
@MainActor
func waitUntil(maxYields: Int = 1_000, _ condition: () -> Bool) async {
    var yields = 0
    while !condition(), yields < maxYields {
        await Task.yield()
        yields += 1
    }
}
