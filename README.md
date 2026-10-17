# Exactulator
An exact-representation calculator.

## What is exact representation?
In math, exact representation is a way to represent irrational numbers by extracting out the irrational parts. For example,

| Exact Representation | Inexact Representation | Use case |
| --- | --- | --- |
| 2√5 | 4.472135955 | Hypotenuse (long side) of a 2x4 rectangle |
| π/4 | 0.7853981634 | 45 degrees in radians, used in trigonometry |
## Why do I want a simple calculator with exact representation?
Most calculators, including the Calculator app, Spotlight, and even some "scientific" calculators, will calculate values in non-exact form. This is usually ideal! Very few people care about the fact that 0.707 is actually √2/2.
But I am one of those people that care that 0.707 is actually √2/2, because as an engineer I run into these all the time (triangles and trigonometry are like, half of engineering). As a Singaporean student, my secondary school-approved calculator doesn't support exact representation.
Therefore, I want to make a calculator that is as simple to use as the built in Calculator app, yet lets me view results in exact form. Ideally it should also support units, making it more useful as a general purpose calculator.
Also its educational. If my school calculator can work with 0.0006W surely I can make a calculator that works on a phone....

## What else does this calculator have?
This calculator makes use of the fact that its on a phone. Specifically,
- You can click anywhere in the equation to move the cursor. Arrow keys are there if you want them too.
- There is no `=` button. It is automatically evaluated. Sadly I wasn't able to get the evaluator to return \*where\* syntax errors are, so if your equation is incomplete it'll just show an error.
- You can hide/show the keyboard if you need more space
- Units (on the left) have a dropdown button for you to select other units
- Pressing the green `↑` button (basically the closest to an `=` button) saves the current expression and solution to a scrollable history. You can scroll back to see what you previously computed. You can click anywhere in an expression to edit it.

## Known Issues
- Exponents act very weird with the caret
- Unit math doesn't simplify, so an expression like `7m/s * 8h` would evaluate to `56 m/s.h`, which is correct but not expected. `7m/s * 8h -> m` instead evaluates correctly to 201600m.
- Units don't work with square roots
- Having a unit next to a function can confuse the parser. This is because tokens are reduced into a string, which unfortunately makes equations like `5msin(4)` fail to parse, as it fails to parse `msin` (which isnt a thing). Workaround right now is to explicitly spell it out as `5m*sin(4)`.

## What do I want in this calculator? (todo list)
- [x] Exact representation of the following:
  - [x] Surds, like 2√2
  - [x] Multiples of pi, like π/3
- [x] Units
  - [x] Implicit conversion between units (e.g. "1m + 50cm = 1.5m")
  - [x] Explicit conversion between units (e.g. "5 min as seconds = 300 s")
  - [x] Compound units (e.g. m/s)
- [x] Basic functions
  - [x] Arithmetic (+, -, \*, /)
  - [x] Prefix negation (e.g. "-2")
- [x] Scientific functions
  - [x] Logarithms (log, ln, log\_base)
  - [x] Trigonometry (sin, cos, tan, with support for special angles)
  - [x] Constants (π)
- [x] Input
  - [x] Native keyboard
  - [x] Keypad UI
