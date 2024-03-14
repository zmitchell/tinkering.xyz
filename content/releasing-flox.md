+++
title = "Today we launched Flox 1.0"
date = 2024-03-13
description = "Today we released version 1.0 of Flox, a new tool that allows you to create declarative environments without containers. Let's talk about why we built it, how it works, and some of my favorite features."
+++

# Intro

A little over a year ago I was working full time as a software engineer while finishing my PhD in physics (you're probably already questioning my judgement, please keep reading).
After I defended my thesis I had some free time to be a real human being again and decided to pick up Nix.
I’ve always had a thing for documentation, and I noticed that the Nix documentation was notoriously hard to use.
I wrote a [blog post](./nix-docs-unified-theory.md) about what my ideal formulation of the Nix documentation would look like.
Ron Efroni, [Flox](https://flox.dev/) CEO and NixOS Foundation Board member,
reached out to talk about the docs and eventually asked if I would be interested in working at Flox.
About a year later we've released our 1.0 and I'm excited to tell you about it.

# What is Flox?

[Flox](https://flox.dev) is a virtual environment and package manager all in one.
What does that mean?

When you activate a Flox environment you're put into a sub-shell
(though you can also `eval` and stay in the current shell).
Inside this shell you have access to whatever packages you've requested and any environment variables you've specified.
If the environment provides a package that you already have installed on your system,
the package from the Flox environment takes precedence while you're in the environment (we modify `PATH`, etc).
In this way, Flox environments layer on top of your existing system.

You can also define shell scripts that run when you enter the shell to perform initialization,
provide instructions, etc.
Once you leave the shell you no longer have access to the software the environment provided, as if it never existed.
Even better, that software isn't scattered across arbitrary locations on your system.
To top things off, you can push these environments to FloxHub and share them with others.

My favorite feature, however, is that you can activate more than one Flox environment at a time.
This lets you compose different sets of tools together in a way that you can't with containers.
Working on the backend? Activate the backend environment.
Working on the frontend? Activate the frontend environment.
Working across the entire stack? Activate the frontend and backend environments.
Throw in a network tools environment to see how responses compare from the development server vs. the production server.
Wrap things up by activating a profiling environment to diagnose some pesky latency spikes.

And since all of this is built using Nix, these environments are bulletproof and portable across different operating systems and architectures.

Flox environments are declarative as well.
With VMs and containers you start with some base system (`FROM` or a fresh install of an OS) and then either run or specify a sequence of imperative commands that prepare the system in the desired state.
With Flox you have a single TOML file ([`manifest.toml`](https://flox.dev/docs/reference/command-reference/manifest.toml/)) that declares the software you want in your environment along with environment variables and activation scripts.

Flox environments are also composed at the package level,
meaning that when you add a new package to the environment you download it,
update some symlinks and some text files,
and then you're done.
You don't have to reinstall all the other packages in your monster `RUN` command or rebuild any layers that came after it.
Adding this package to another environment is even faster now that the package is cached locally.
All of this makes build times very attractive compared to containers.

Interested?

Let's talk about why we built Flox.

# Containers are fine, right?

Containers are a great format for deployment and distribution,
but they leave something to be desired when it comes to development.
How much time have you spent setting up your machine to feel like `$HOME`?
How much time have you spent tweaking your artisanally handcrafted dotfiles,
or installing nifty little utilities?

Don't actually think about that, it's probably more than you want to admit.
But we all do it.
Why?
Easy, when you set up your system to work how you want it to work,
you'll obviously feel more comfortable and be more productive.

When you enter a container it's like someone walked in and cleared off your desk.
It's isolated! Great! Isolated from all the stuff I set up for myself!
When you use a container for a development environment you also spend some time poking holes in it to share a directory with the host machine, connect it to other services, etc.

You do all of this because the promise of working cross-platform in a reproducible environment is seductive.
Unfortunately, there's a big asterisk on that promise.
First, if you're bundling up a snapshot of a Linux system (e.g. a container), are you really working cross-platform?

With containers your Dockerfile contains a `FROM` line that tells you the base system you’re building on top of.
Depending on how you write this line, you’ll get a different system each time.
- `ubuntu:latest` could give you two different releases of the OS.
- `ubuntu:23.10` could still give you two different systems as security patches are applied, packages are upgraded, etc.
- Every time you build the image, two different calls to `apt update && apt install foo` aren’t guaranteed to give you the same versions of the package.

So, every time you enter a container with a given digest you're getting the same system,
but every build isn't guaranteed to give you the same container.

There's a better way.
We can have nice things.

# What is Nix?

Flox uses Nix to achieve reproducibility and portability.
So, what is Nix?
At its core, Nix is a platform for building and configuring software.
That's a vague answer, and there's two reasons for that:
- I'm a former academic and it's therefore physically impossible for me to give you a straight answer.
- Nix can do a lot of things. You can use Nix to do everything from creating a text file to configuring an operating system.

Let's focus on the "building software" and "setting up development environments" parts of Nix.
I'm going to use a couple of Rust analogies because you can draw _some_ parallels between them.

One of the reasons that people use Rust is that it enforces correctness and memory safety while *writing* software.
It does this via immutability, a strong type system, etc.
Nix enforces correctness while *building* software.
It tries really hard to make sure that you aren't building your software by happy accident.
Nix also does this through immutability and some other mechanisms.

{% details(summary="Nix vs. nixpkgs vs. NixOS?") %}

- "Nix" is two things:
    - The name of the ecosystem.
    - The name of the programming language you use to build software and set up development environments.
- "nixpkgs" is also two things:
    - A software repository containing recipes for building a staggering amount of software (something like 80,000 packages).
    - A standard library for building software using the Nix language.
- "NixOS" is a Linux distribution built and configured using the Nix language.

{% end %}

Here's one example of something that Nix tries to prevent:
- Say you install package `A` and it puts `libfoo` on your system.
- Now you install package `B` and it also provides `libfoo`, but it’s slightly different in some way, and that overwrites the existing `libfoo` on your system
    - Say that maybe package `B`’s `libfoo` has a patch applied, or say that it’s the same exact semantic version but made from a different git revision.
- All the software that relied on `libfoo` is now different because `libfoo` is now different
- You haven’t changed anything about your software, but now it’s operating slightly differently because the software it depends on is slightly different.

I mentioned mutability earlier.
Rust tries really hard to avoid shared, mutable state.
Your filesystem is a great example of a big ball of shared, mutable state.

Nix stores all of the software that it downloads, builds, installs, etc into one big immutable build cache, meaning that once something is in there, it doesn’t get modified.
The Nix store is just the directory `/nix/store`, nothing fancy.
Everything in the store has a hash in its filename, and that hash is computed from all the software that was used to build that particular artifact.
The software used to build an artifact also contain hashes in their filenames in the Nix store, and so on.
This means that the hash of your piece of software is essentially a hash computed from the entire dependency tree, all the way down to `libc`.
Since the path contains this hash, the path is essentially unique.
Since this path is unique, you can use the absolute path to it and you’ll never depend on the wrong piece of software.

When Nix builds software,
it hard-codes these absolute paths into the artifact so that it’s effectively impossible to link the wrong dynamic library,
depend on the wrong Python interpreter, etc.
This is what makes software built with Nix so bulletproof.
When you go to set up a development environment you get the same benefits.

# What does Flox add?

Nix provides a lot of power and flexibility,
and it's awesome seeing all the fun and interesting ways people solve problems with Nix.
That power and flexibility has a cost, however, and that cost is one of the steepest learning curves I've ever encountered.

If you’ve used one package manager, you’ve pretty much used them all.
You run `install`, `uninstall`, `search`, etc.
You likely know the build tools for your language of choice pretty well too.
With Nix none of those things are all that helpful.
With Nix you have to write a program in a lazily evaluated functional programming language that no one has ever heard of.
You also have to know the library of functions provided by nixpkgs, and even understanding their arguments can be difficult.
For example, what’s the difference between `buildInputs`, `nativeBuildInputs`, and `propagatedBuildInputs`?
It’s all very intimidating and confusing to new users since they can’t fall back on familiarity with other systems.

With Flox we're providing a substantially better user experience.
We provide the suite of package manager functionality with `install`, `uninstall`, etc,
but we also provide an entire new suite of functionality with the ability to share environments via `flox push`, `flox pull`,
and `flox activate --remote`.
We still provide a declarative model for the environment that underpins all of this.
All of the imperative commands edit a TOML file ([`manifest.toml`](https://flox.dev/docs/reference/command-reference/manifest.toml/)).

With Flox you can benefit from Nix without needing to _know_ Nix.

I'm not going to talk much about our roadmap,
but it does include a suite of features for teams and organizations in the enterprise.
We're open to feedback,
so if there's something you'd like,
we'd be happy to hear about it.

# Wrapping up

Building up to a release feels like racing towards a finish line,
but releasing a 1.0 is really more of a beginning.
I'm excited about what we've built so far,
but I'm even more excited about what we're _going_ to build.
If you have questions or feedback,
you can reach me directly or in one of our community spaces:
- [Flox Discourse](https://discourse.flox.dev)
- [Flox Community Slack](https://floxcommunitygroup.slack.com/join/shared_invite/zt-2ef7qa1x3-LVL0v6i9MScPMOceyzB7BQ#/shared-invite/email)

