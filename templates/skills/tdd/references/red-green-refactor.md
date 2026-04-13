# Red-Green-Refactor Cycle

## Phase 1: RED (Write Failing Test)
- Write ONE test that captures the expected behavior
- Run it — it MUST fail (proves the test is meaningful)
- If it passes: your test is wrong or the feature already exists

## Phase 2: GREEN (Minimal Implementation)
- Write the MINIMUM code to make the test pass
- No optimization, no cleanup, no abstractions
- Run the test — it MUST pass now
- Run ALL tests — nothing else should break

## Phase 3: REFACTOR
- Clean up the implementation (remove duplication, improve naming)
- Run ALL tests after each refactor step
- If any test breaks: undo the refactor

## Common Mistakes
- Writing too many tests before any implementation
- Making the implementation "pretty" in the GREEN phase
- Refactoring without running tests between changes
- Testing implementation details instead of behavior
- Skipping the RED phase (not verifying the test fails first)

## Test Structure
```
// Arrange — set up preconditions
// Act — execute the behavior under test
// Assert — verify the expected outcome
```
