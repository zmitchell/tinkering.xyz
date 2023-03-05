+++
title = "Nix journey part 0: Learning and reference materials"
date = 2023-02-28
description = "In this series I'll be documenting my journey learning Nix and this first installment is more of a prequel. A common complaint when learning Nix is that the documentation \"is not good\", and I think what people mean by that is that the documentation is spread across several sources which may or may not be easy to find, or that there is no explanation at all in official documentation. This post is a collection of both official and unofficial resources."
[extra]
show_date = true
+++

## The story before the recipe
I've been following the Nix project for a while but now that I'm done with my PhD I finally have some free time and energy to try using it in earnest. This series is going to be me learning Nix by showing you how things work and how to put the pieces together.

For those of you unaware, Nix takes reproducible builds to their logical conclusion by making package builds (mostly) pure functions of their dependencies. The binary artifacts of builds are stored in a content-addressed store (the Nix store) so you can be sure that you're always getting the same package if you have its name and hash. Not only can you build programs this way, but you can also build development environments ("I want these libraries available in my build environment and nothing else", for example), run commands in throw-away environments with specific packages installed without polluting your global environment. There's even an operating system, NixOS, based on this packaging system that allows you to configure your whole system (installed packages, system settings, etc) from a single file.

Now, with all of that said, Nix can be intimidating simply because it's so different from other packaging systems. First off Nix packages are written in a purely functional language also called Nix. The terminology used in the Nix ecosystem is also pretty unique, so reading about Nix can often feel like this classic:

![How to draw an owl meme](https://i.kym-cdn.com/photos/images/newsfeed/000/572/078/d6d.jpg)

At the end of each post there will be a "questions for the audience" section. I'll put questions there when I'm unable to find satisfactory answers on my own with the hope that readers familiar with Nix can provide answers that I can then include both for my benefit and the benefit of anyone reading these posts at a later date. There will also be a "Resources" section at the end where I'll link the posts and documentation that I used to answer my own questions.

My focus in this series will be on using flakes to the largest extent possible, but from the reading I've already done it seems like you still need to know how pre-flake derivations work in order to get the most value out of Nix.

## Today's goal: gathering the resources

This post will be a collection of Nix documentation, both official and unofficial. This deserves its own post simply because I've found that the official Nix documentation is scattered across multiple sources. I am not the first person to point this out, but (1) I am an obsessive note taker and already had all these links, and (2) I would like to have everything all in one place for anyone reading this series.

## Official
These are the resources maintained by the Nix project itself. You should consider these the source of truth, but you should also be realistic about open source documentation and realize that it could be out of date. In my experience some of these resources are hard to understand unless you already know what they're saying. I would mostly use these as reference materials and would recommend against trying to read them cover to cover unless you really have nothing better to do.

### [Nix Reference Manual](https://nixos.org/manual/nix/stable/)
The Nix Reference Manual covers a lot of ground ranging from installing Nix to man-pages for `nix` commands. I would say that the most useful pieces here are:
- [Installation instructions](https://nixos.org/manual/nix/stable/installation/installation.html)
- [Nix language reference](https://nixos.org/manual/nix/stable/language/index.html)
- [Command reference](https://nixos.org/manual/nix/stable/command-ref/command-ref.html)

Oddly enough, in the reference for the `nix flake` command you'll find a very thorough description of the schema for a Nix flake including which attributes are required, how to refer to other flakes, etc. In my mind this should live somewhere else, but I'm glad it exists somewhere.

### [Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)
The Nixpkgs manual is an in-depth guide to using Nix to build packages and the foundational tooling Nix provides. Since flakes are still considered experimental this mostly covers how to make derivations "the old way." In my brief time learning Nix I've found that you have to understand how the pre-flakes ecosystem works in order to get the most value out of Nix. The parts I've found most helpful are:
- [Chapter 6: The Standard Environment](https://nixos.org/manual/nixpkgs/stable/#chap-stdenv)
- [Chapter 17: Languages and Frameworks](https://nixos.org/manual/nixpkgs/stable/#chap-language-support)

The standard environment (`stdenv`) is the set of packages (`gcc`, `make`, etc) and Nix functions (`mkDerivation`, `mkShell`, etc) considered the bare minimum to build most software and development environments. The languages and frameworks chapter describes the built-in functionality for building software in your favorite language e.g. `buildRustPackage` for Rust, `buildGoModule` for Go, etc. You'll definitely find that some languages are better supported than others, and even if your language is supported with a built-in builder, you may find yourself reaching for a third-party tool that has a better user experience e.g. `poetry2nix` for Python or `crane` for Rust.

### [NixOS Package Search](https://search.nixos.org/packages)
This is a site where you can search all of the packages available in the official Nixpkgs repository.

One thing I find weird about this is that you can't link to a specific search result since search results don't have their own pages. For example, if I search `rustc` I'm presented with a list of search results. The first search result is the `rustc` package, as expected, and the package name is styled as if it's a link (e.g. it's styled as if it's `<a>rustc</a>`), but it's not actually a link. Clicking on the package name expands a more detailed view of the package including the programs that it provides, the maintainers, etc. There are anchor tags in the tab bar (the part that says "nix-env", "NixOS Configuration", and "nix-shell"), but if you copy that link it contains the entire query that contained this search result. Not ideal. There should definitely be a way to link to a specific package. Maybe there is and I've just missed it, but that just means it isn't obvious.

### [Nix Pills](https://nixos.org/guides/nix-pills/)
To me the name suggests that Nix Pills contains bite-sized pieces of pragmatic Nix knowledge e.g. how to set your shell prompt in a development shell. In actuality I've found it to be a deep dive on Nix internals. I haven't actually read too much of this yet, but I'm sure I'll read a section here and there as I learn more about how everything works under the hood.

## Community
Given that there's an entire internet of content out there about any given topic it's unrealistic for me to list every single resource about Nix. Instead I'm going to list the resources I've found to be helpful for me in particular or resources that I think more people should know about. I guarantee you I've left out resources that other people will say are great for one reason or another.

### [NixOS Wiki](https://nixos.wiki)
The NixOS wiki is a community maintained wiki for NixOS, not just Nix. Accordingly you'll find pages here that cover not just creating and building Nix packages, but a variety of other topics like how to configure your dotfiles with Nix, how to deploy a NixOS server, etc. This is a pragmatic resource that shows you how to do all kinds of stuff rather than focusing on how everything works under the hood.

For example, the [Flakes](https://nixos.wiki/wiki/Flakes) page gets right to the point of showing you what you need to create a `flake.nix`, but it doesn't explain everything in great detail. It also shows you how to accomplish a variety of tasks with flakes, like integrate them with `direnv` to automatically enter a development shell when you enter a certain directory.

### [Nix.dev](https://nix.dev)
It says right at the top that this is an opinionated guide. Since I'm a complete n00b I have no idea if these opinions are (1) any good, or (2) widely held. Here are some highlights:
- [Nix language basics](https://nix.dev/tutorials/nix-language.html)
- [Anti-patterns](https://nix.dev/anti-patterns/language)

### [Zero to Nix](https://zero-to-nix.com)
This is a brand new resource at the time of writing. I think this will be a great resource in 2 years. Right now it's relatively sparse, but I like the concept. The site divides its materials between a "Quick Start" guide and "Concepts". The concepts are linked to each other in a kind of knowledge graph so that you can emulate that late-night-Wikipedia-rabbit-hole experience while staying in the Nix universe.

### [Tony Finn - Nix from First Principles: Flake Edition](https://tonyfinn.com/blog/nix-from-first-principles-flake-edition/)
This is a series of blog posts showing you how to get started with Nix. You might assume from the title that it uses flakes from the very beginning, but you aren't introduced to flakes until several articles in. I actually think that's a good move. I think you need to understand the Nix ecosystem as it is today in order to get the most out of flakes. It's still a good overview of what you can accomplish with Nix, and it's a resource I found myself going back to.

### [Ian Henry - How to Learn Nix](https://ianthehenry.com/posts/how-to-learn-nix/)
This isn't so much a tutorial as it is one person's descent into madness while learning Nix. It's not a tutorial teaching you how to use Nix, it's one person's stream-of-consciousness as they learn Nix, and it's really refreshing. At some point you'll be reading the Nix documentation and you'll find your eyes skimming over a sentence only to realize you have no idea what you just read. This series is validating in the sense that someone else is reading that same documentation and verbalizing "wait, wtf did I just read?". Is it the best use of your time to learn Nix by reading this series? Probably not, but it can be entertaining and comforting. I haven't read the entire series because I have a short attention span, but it's useful to read and realize that Nix is foreign, it's not just you.

## What's missing
I spend a lot of time in the Rust ecosystem, where there's extensive automatically generated documentation for types, function signatures, module structures, etc for every package that's published to [crates.io](https://crates.io). This is something that I sorely miss when dealing with Nix. For example, there's no browsable, hyperlinked list of the functions available in Nixpkgs with the attributes that they expect as inputs and the attributes they provide as outputs. Nix is a pure functional language, shouldn't static analysis be possible to determine most of this? Shouldn't you be able to sprinkle in comments with semantic meaning that get turned into HTML documentation? Specifically, what is the function signature of something like `mkShell`? The inputs are pretty similar to `mkDerivation`, but I have no idea what the outputs look like.

Another thing that I miss in the Nix ecosystem is a cohesive documentation strategy. The motivation for this entire post is that the documentation is scattered.

## Conclusion
So, hopefully you've found this useful. In the first real installment of this series we'll look at how to create a flake from scratch (no really, starting from an empty file). Later installments will cover topics such as specifying separate sets of build-time, dev-time, and run-time dependencies, building Docker images from Nix flakes, setting up useful development shells, and a variety of other topics. Until next time, may cosmic rays never flip your bits.
