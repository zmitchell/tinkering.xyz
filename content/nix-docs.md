+++
title = "Nix journey part 0: The various sets of Nix docs"
date = 2023-02-25
draft = true
description = "In this series I'll be documenting my journey learning Nix. This first installment is more of a prequel, if you will. In this post I'll present a collection of Nix documentation all in one place so that anyone using this series to learn Nix will be aware of the various resources at their disposal."
[extra]
show_date = true
+++

## The story before the recipe
I've been following the Nix project for a while but now that I'm done with my PhD I finally have some free time and energy to try using it in earnest. For those of you unaware, Nix takes reproducible builds to the extreme by making package builds (mostly) pure functions of the their dependencies, which are pure functions of their dependencies, etc. The binary artifacts of builds are stored in a content-addressed store (the Nix store) so you can be sure that you're always getting the same package if you have its name and hash digest. Not only can you build programs this way, but you can also build development environments ("I want these libraries available in my build environment and nothing else", for example), run commands in throw-away environments with specific packages installed without polluting your global environment. There's even an operating system, NixOs, based on this packaging system that allows you to configure your whole system (installed packages, system settings, etc) from a single file.

Being able to specify an entire development environment including build time dependencies, toolchains, etc in a single file and drop into a clean environment with a single command, `nix develop`, is very appealing to me. Being able to have a reproducible, hermetic build environment also eliminates the "it builds fine on my machine" problem caused by having the wrong version of `libfoo.so` on your system from installing a random CLI application 4 months ago that you never uninstalled.

Now, with all of that said, Nix can be intimidating simply because it's so different from other packaging systems. First off Nix packages are written in a purely functional language, also called Nix. The terminology used in the Nix ecosystem isn't commonly used, so reading about Nix can often feel like this classic:

![How to draw an owl meme](https://i.kym-cdn.com/photos/images/newsfeed/000/572/078/d6d.jpg)

This series is going to be me documenting my journey learning Nix so that I can use it both professionally and in my side projects. That means I'll need to be able to specify separate sets of dependencies (dev-time, build-time, and run-time) available at different times, build both binary artifacts and Python packages, and generate Docker images.

At the end of each post there will be a "questions for the audience" section where I'll put questions I was unable to find satisfactory answers for. The hope is that readers familiar with Nix can provide answers that I can include both for my benefit and the benefit of anyone reading these posts at a later date. There will also be a "Resources" section at the end where I'll link the posts and documentation that I used to answer my own questions.

My focus in this series will be on using flakes to the largest extent possible, but from the reading I've already done it seems like you still need to know how pre-flakes derivations work in order to get as much value out of Nix as possible.

## Today's goal

This post will be a collection of Nix documentation, both official and unofficial. This deserves its own post simply because I've found that the official Nix documentation is scattered across multiple sources. I am not the first person to point this out, I would simply because (1) I am an obsessive note taker, and (2) I would like to have everything all in one place for anyone reading this series.

## [Nix Reference Manual](https://nixos.org/manual)

## [NixOS Wiki](https://nixos.wiki) (Unofficial)
The NixOS wiki is a community maintained wiki for NixOS, not just Nix. Accordingly you'll find pages here that cover not just creating and building Nix packages, but a variety of other topics like how to configure your dotfiles with Nix, etc. Since these pages are community maintained I've found that the content can be more or less approachable and more or less complete depending on the author (this is to be expected with a community maintained site).