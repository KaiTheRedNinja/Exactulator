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

## What do I want in this calculator?
- [x] Exact representation of the following:
  - [x] Surds, like 2√2
  - [x] Multiples of pi, like π/3
- [ ] Units
  - [ ] Implicit conversion between units (e.g. "1m + 50cm = 1.5m")
  - [ ] Explicit conversion between units (e.g. "5 min as seconds = 300 s")
  - [ ] Compound units (e.g. m/s)
- [x] Basic functions
  - [x] Arithmetic (+, -, \*, /)
  - [x] Prefix negation (e.g. "-2")
- [x] Scientific functions
  - [x] Logarithms (log, ln, log\_base)
  - [x] Trigonometry (sin, cos, tan, with support for special angles)
  - [x] Constants (π)
- [ ] Input
  - [x] Native keyboard
  - [ ] Keypad UI
