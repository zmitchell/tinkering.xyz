+++
title = "I don't care that it's X times faster"
date = 2026-04-14
description = "Many new project announcements these days come with a tagline of 'X times faster than ...' and I need to rant about it."
+++

Yeah, this is a rant. I saw a post on `r/rust` and it triggered me. Rather than putting it in my diary or keeping it between me and my therapist I'm putting it on the internet because I suspect there are some kindred spirits out there. I'm sure this will go well for me.

Also, yeah, I've written [a post](../fmo-optimization-story) about making things faster, but that was about the incremental improvements I made to (1) something no one knew existed, and (2) something that was legitimately really slow. This isn't what I'm talking about.

# Getting butthurt

I don't know if this is some kind of psychological bias that has caused me to notice this now that I'm thinking about it, but lately it seems like new project announcements take one of the following forms:

- "I built Foo, which is X times faster than Y"
- "X times faster <thing>"
- "Foo is X times faster than Bar"

First, I'm skeptical that it's even true. Second, even if it is true, is performance the most important metric?

# Is it true?

The order of magnitude of `X` in these post titles is _all_ over the map. I've seen some posts where X is on the order of 500x. In that case I instantly think one of the following:

- Your benchmark isn't measuring what you think it's measuring
  - Charitable interpretation: you're accidentally measuring something that's been optimized away entirely
- Your benchmark isn't a fair comparison
  - ex.) Project A does some work inline, whereas your project sends the work to a background thread, and you're comparing the time it takes to send data over a channel as opposed to actually doing the rest of the work on the background thread.

If you did legitimately make something significantly faster all things considered, I sincerely congratulate you. That's an achievement and it's really fun to do. Otherwise, I'm giving you stink eye.

When X is on the order of ~2x faster I'm much more likely to believe that you've discovered a legitimate optimization. Maybe you improved cache locality, reduced the number of system calls, etc. If you write a blog post about that, I'm probably going to read every single word because that's the kind of nerd I am.

Another aspect of "is it true" is "does it even do the same thing?". If you ignore 90% of the problem (which may be valid for your use case!) and your program is faster, that's kind of to be expected, but it's not strictly a fair comparison. You can probably slice bread with a chainsaw, and it will probably do it faster than a bread knife, but "chainsaw slices bread faster than bread knife" is only true if bread carnage counts as "sliced".

# Is it important?

A headline of "I made `<popular or just existing tool>` MUCH faster" can be read a number of ways, some more charitable than others:

- Existing tool is unreasonably slow
- Existing tool could be better
- Maintainers of `<existing tool>` are naive/ignorant/bad/wasting their time/...
- I am really good at performance
- I am much better at performance than the maintainers of `<existing tool>`
- Performance matters at all for `<existing tool>`
- Performance is an _important_ feature of `<existing tool>`
- Please hire me
  - You are valid, it's rough out there and you deserve to eat

Being totally transparent, I'm autistic, so I'm totally willing to entertain the idea that I read things differently than other people. That said, these headlines often feel like clickbait, meant to catch your eye either because X is a big number, or because the project being compared against is well known. Bad. Don't be clickbait.

I currently work on and have in the past worked on performance sensitive code. It's often the case that improving the performance of some part of your code makes no _real_ difference to the _overall_ performance. In other words, if you're improving the performance of code that isn't part of the bottleneck, this often makes no practical difference.

This isn't to say that you shouldn't care about performance, but there's a number of other axes you can optimize along:

- Well tested
- Does something no one has done before
- Covers more edge cases
- Is stable
- Uses cutting edge APIs
- Is easy to use
- Is well documented
- Is friendly to new contributors
- Most embodies the shitposter spirit

This also isn't to say that it's illegal to write the absolutely most optimal code. I just think that if this is your goal you need to come with receipts and be able to make your case. If your project was entirely vibe coded, benchmarks and all, you're going to get shredded. Not by me (probably, I tend to keep to myself on the internet), but other commenters are probably going to shit on you (for better or worse) if/when they find your claims lacking.

# Done

Glad I got that off my chest.

I want to end by saying you're not a bad person if you make a headline like this. I just think you can do better. That's probably patronizing, but what I'm trying to convey is that you're selling yourself and your achievements short.
