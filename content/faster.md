+++
title = "The receipts for 'faster'"
date = 2026-04-22
description = "A reply to 'faster'. The thesis is right. The public toolkit doesn't quite enforce it yet. Here's how to close the loop."
+++

Read "faster" and nodded along. The 500x numbers really are mostly broken benchmarks. The 2x numbers really are mostly honest. "Your benchmark isn't measuring what you think it's measuring" is the single most useful sentence anyone's written about this.

But the post argues a stronger position than the public repos currently enforce, and the gap is worth closing. If the thesis is that `faster` deserves skepticism, then the defense should be mechanical, not rhetorical — otherwise you're doing the same thing the post criticizes: asserting something without receipts.

## What's already there

Proptest is used in earnest. Polarization has 75 property tests against 60 unit tests and a `proptest-regressions/` directory with six checked-in counterexamples, which is the habit most people skip. There's a metamorphic testing library, written from scratch, with a README that cites Hillel Wayne. Criterion benches in `aoc-2024` wrap their inputs in `black_box` — not a formality, most benches don't. Domain-aware approximate-equality macros for complex numbers, beams, and matrices. That's more rigor than 95% of the ecosystem ships.

So this isn't a "you need to test your code" reply. You already test your code.

## Where the thesis exceeds the tooling

A benchmark that says "500x" is almost always broken. Fine. But a benchmark that says "2x" is only trustworthy if you can demonstrate that:

1. The thing being measured hasn't been optimized away.
2. The two sides of the comparison are doing equivalent work.
3. The measurement itself is reproducible across machines and days.
4. The test suite that claims the code is correct would actually notice if it wasn't.

Criterion plus `black_box` gives you (1) and (2). Proptest with regressions gives you part of (4). Nothing in the public repos gives you (3) or the rest of (4). The post treats all four as load-bearing, so the tooling should too.

## The specific gaps

**iai-callgrind.** Criterion measures wall time, which is noisy, machine-dependent, and wrong to ship in a PR gate. iai-callgrind counts instructions, cache references, and branch misses through Valgrind. It's deterministic across machines and runs in CI without flakes. This is the single change that would let you publish "2x faster" numbers that a skeptic — including yourself — couldn't wave away. Especially relevant for `proctrace`, which is the kind of tool people benchmark themselves.

**cargo-mutants on polarization.** 75 properties is a lot of properties. Mutation testing flips operators and returns in the code under test and tells you which of those properties actually catches the perturbation. Without it, a property can silently rot into a tautology — the test passes, but only because it's checking something that's always true. This is the "test for your tests" and it's specifically the right tool for code that's mostly property-based.

**cargo-fuzz on `ingest.rs`.** The bpftrace output parser is exactly the shape fuzzing was built for: structured text, regex-heavy, adversarial inputs possible if bpftrace ever changes its output format. An `Arbitrary` impl on a synthetic event, a round-trip target, and an afternoon of fuzzing is about a hundred lines of code and makes proctrace robust against the thing that breaks proctrace-class tools in practice.

**dhat-rs.** A tool that traces kernel-level process lifecycle events should probably know its own allocation profile, especially for long recordings. dhat-rs wraps the same DHAT that Nethercote built; instrumenting `proctrace record` for a ten-minute trace and looking at the output would either confirm there's nothing to see or surface a detail that matters.

**trybuild on wickerman.** Procedural macros without compile-fail tests mean the error-path UX drifts and nobody notices until a user files an issue about a confusing diagnostic. Small lift, high payoff.

**divan on the SIMD comparison in aoc-2024.** The `day1` vs `day1_simd_parser` split is already the right shape — same puzzle, same input, two implementations. Divan compares functions in the same bench natively, which is the apples-to-apples framing the post asks for. Criterion can do it but divan says it out loud.

## Why this matters for the thesis

The "faster" post isn't really about benchmarking. It's about epistemics — what does it take to make a performance claim that a skeptic would accept? The honest answer is: instruction-counted benches, mutation-verified properties, fuzzed parsers, heap profiles, snapshot-tested output. Not because any single tool is magic, but because together they make the claim *checkable* rather than *asserted*.

None of the above contradicts the existing work. It fortifies it. The article is good. The gap is that anyone motivated to disagree with you could point at the public repos and say "prove it," and right now the answer would be more careful than it needs to be.

Fill the gaps and the answer becomes: here are the receipts.
