+++
title = "Nix journey part 1: A flake from scratch"
date = 2023-03-01
draft = true
description = "Today we're to develop a Nix flake from scratch (no really, from an empty file) that will let us compile a Rust crate, and that's it. \"Compile a Rust crate\" means both calling `nix build` and dropping into a development shell and calling `cargo build`. This is a pretty basic piece of functionality, but we'll build off of it in later posts"
[extra]
show_date = true
+++


## Today's goal

Today we're going to build a flake from the ground up, starting with an empty file. This flake will allow us to compile a Rust crate either by calling `nix build` or by dropping into a development shell and calling `cargo build`. The reason that we're taking this route is that I struggle to use tools when I don't understand how they work, so I want to have an understanding of why every single character is present in a flake. There's no better way to understand that than by building one from scratch. Hopefully by the end of this post when you see a flake you'll see this:
```
<expression>
    <function>
        <inputs>
            nixpkgs
            <other tools>
        <outputs>
            <default package>
            <default development shell>
```
rather than
```
withlet{}{}{}::{}inputs{pkgs.foo,buildInputs=[]}
```

## Getting started
You'll obviously need Nix to get started. I recommend the official Nix installation script as instructed by the [Nix Reference Manual][installation]. I'm on macOS and the official installer worked just fine for me, no having to mess with SIP or anything like that. You'll need to add the following line to `/etc/nix/nix.conf`:
```
experimental-features = nix-command flakes
```
This line enables experimental features, like it says. The `nix-command` feature allows you to use the `nix` command with subcommands like `build`, `shell`, `develop`, etc rather than having to use separate commands like `nix-env`, `nix-shell`, etc. The `flake` feature enables us to write flakes. You can read more about the motivation for flakes in [this article][old_vs_flakes]. In short, a flake is a Nix expression that adheres to a specific schema, providing some structure to what exactly a Nix build is supposed to do while providing a single entry point to a project as opposed to a collection of separate Nix files e.g. `shell.nix`, `foo.nix`, etc.

There's also a new, unofficial installation method from Determinate Systems called [`nix-installer`][nix_installer]. I used it about a month prior to writing this, ran into a bug, and filed an issue (issue [#212][installer_issue]). It was resolved quickly and the maintainers were very pleasant. The nice thing about this installation method is that it sets you up for flakes by default and also tries very hard to make sure that (1) uninstalling Nix is easy, and (2) if installation fails you aren't left in an unrecoverable state. The official installation method is lacking in both of these regards.

Now that we have the Nix tools we can start building our flake. We could do `nix flake init` to build out a very basic flake, but we're going to build it from the ground up, so let's really start from the ground floor:
```
$ mkdir rust_flake && cd rust_flake
$ touch flake.nix
$ nix develop
error: syntax error, unexpected end of file

       at /nix/store/3yph0sq9h5nwxaw89wy0vxaalb4csmxw-source/flake.nix:1:1:
```
You don't get much more "ground floor" than an error at line 1 column 1.

You might have noticed that I said we're going to build the crate with `nix build`, but here I've used `nix develop`. The reason we're going this route is that I know how to build a Rust crate with `cargo`, but I don't yet know how to build a Rust crate with Nix-native tooling. The `nix develop` command puts you into a Bash shell (by default, you can change that somehow) with certain packages in `$PATH`, so if we can get `cargo` and `rustc` into our shell then we can just do a good old `cargo build` to compile the crate. Once we can do that we'll circle back and learn how to compile the crate using `nix build`.

## Minimal compiling flake
A flake is basically just an "attribute set" or "attrset", which is what you would call a "map" or "dictionary" in other languages. In other words it's just a collection of key-value pairs where the keys are called "attributes". Right now the syntax with which we've defined our attrset has an error (duh, it's empty). An attrset is defined with this syntax:
```nix
{
    attributeName = expression;
}
```
That means our flake needs to have curly brackets surrounding a list of `foo = bar;` statements. Let's just put an empty attrset in the flake and see if it works:
```
$ echo "{}" >flake.nix
$ nix develop
error: flake 'path:/Users/zmitchell/code/rust_flake?lastModified=1675541093&narHash=sha256-wsCzRc01DrmsFcszMdKcgqZW1UGPS3Wrwo6oXM0XjVI=' lacks attribute 'outputs'
```
A shortened error message is `error: flake <stuff> lacks attribute 'outputs'`. The `<stuff>` is a "flake reference" and is how you refer to flakes that can come from a variety of sources (elsewhere on your machine, the internet, etc). We'll come back to this later, it's not important to understand the error. This error tells us that our flake is missing an attribute `outputs`, meaning that our set of key-value pairs is missing one whose key is `outputs`. This means we need to create an attribute called `outputs`, but that's probably not the whole story. Besides, how were we supposed to know we needed this attribute? If there's one required attribute, are there others? Let's consult the [flake schema][flake_schema] as described on the NixOS Wiki since that was the first search result:

>It has 4 top-level attributes:
>
> - `description` is a string describing the flake.
> - `inputs` is an attribute set of all the dependencies of the flake. The schema is described below.
> - `outputs` is a function of one argument that takes an attribute set of all the realized inputs, and outputs another attribute set which schema is described below.
> - `nixConfig` is an attribute set of values which reflect the values given to nix.conf. This can extend the normal behavior of a user's nix experience by adding flake-specific configuration, such as a binary cache.

But wait, `nix develop` didn't complain about a missing `description`. On top of that I've never seen someone's flake have a `nixConfig` attribute, so there's some nuance missing from this description.

It was at this point that I discovered that the _actual_ flake schema is defined in the [`nix flake` command reference][flake_command] in the Nix Reference Manual, which is not where I would expect to find it. After finding this page things started to make sense, so definitely go read that. All of it. I trust that you've done that, but I'll just paraphrase what it says anyway (emphasis mine):
> The following attributes are **supported** in `flake.nix`:
> - `description`: A short, one-line description of the flake
> - `inputs`: An attrset specifying the dependencies of the flake
> - `outputs`: A function that takes inputs in an attrset and produces the outputs of this flake
> - `nixConfig`: A set of `nix.conf` options to be overridden when evaluating this flake

Ah, _supported_, not _required_. So these are the four keys that I suppose _can_ appear at the top level of a flake, but not all of them are required. A quick search of the `nix flake` command reference doesn't show that any of these attributes are required, so I suppose there's a gap in the documentation. This also tells us that you can't have **any** other attributes at the top level of the flake. If you had a working flake and added `foo = "bar";` to it you would get an error that looks like this `error: flake <stuff> has an unsupported attribute 'foo'`.

With that out of the way let's fill out a minimal flake. We'll say that we have no inputs, and that our `outputs` function takes no inputs and produces no outputs:
```nix
{
    description = "A flake for a Rust development environment";
    inputs = {};
    outputs = {} : {};
}
```
Now let's run `nix develop` again and see what happens:
```
$ nix develop
error: 'outputs' at /nix/store/qfhahmkdi9d0yikf4ka21xhz7ffsivy4-source/flake.nix:4:15 called with unexpected argument 'self'

       at «string»:45:21:

           44|
           45|           outputs = flake.outputs (inputs // { self = result; });
             |                     ^
           46|
```
This error is saying that our `outputs` function was called with an argument `self`, but we wrote a function that takes an empty attribute set `{}` as its argument. That's unexpected, didn't we say that our `inputs` were `{}`? If you consult the [Flake Inputs][flake_inputs] section of the `nix flake` reference, you'll see that `self` is _always_ passed as argument. The `self` input is described like this:

> The special input named `self` refers to the outputs and source tree of _this_ flake.

So `self` contains the source tree of the flake that's being evaluated, but what's this about it containing the outputs of this flake? Aren't we literally using `self` to define the outputs? The Nix language is lazily evaluated, and that makes these kinds of circular references possible. By passing `self` as an input we allow one output to reference a different output. What happens if we add `self` to the arguments?
```nix
{
    description = "A flake for a Rust development environment";
    inputs = {};
    outputs = {self} : {};
}
```
\*_crosses fingers_\*
```
$ nix develop
error: flake 'path:/Users/zmitchell/code/rust_flake' does not provide attribute 'devShells.aarch64-darwin.default', 'devShell.aarch64-darwin', 'packages.aarch64-darwin.default' or 'defaultPackage.aarch64-darwin'
```
That's a new error! Let's figure out what these `devShell.<something>.default` and `packages.<something>.default` things are about. The [`nix develop` reference][nix_develop_reqs] says that when you call `nix develop` it tries to find these output attributes
- `devShells.<system>.default`
- `packages.<system>.default`
where `<system>` is something like `aarch64-darwin` or `x86_64-linux` and corresponds to your system architecture and operating system.

I can get behind creating an attribute called `devShells.aarch64-darwin.default`, but what should we assign to it? Strangely I haven't been able to find a good reference on this. I was expecting to find something along the lines of "`devShells.${system}` expects an attribute set containing the attributes X, Y, and Z", but I never found anything like that.

## Building a development shell
From reading a bunch of blog posts and examples it seems like you create a shell using the `mkShell` built-in function. Looking for documentation on this led me down a rabbit hole. I found much of what follows at this [Nixpkgs Manual page][nixpkgs_manual_rehosted], which is as it turns out isn't the official page even though it comes up first in my search results. You can find the [official Nixpkgs Manual][nixpkgs_manual_official] without much trouble if you know that it exists. Anyway, back to business.

Nix provides what it calls the ["standard environment"][stdenv] or `stdenv`, which is what Nix considers to be the bare minimum for building software. Whether this is _really_ the bare minimum for building software is debatable, it's certainly a very C-centric way of building software. The standard environment consists of a Bash shell, `make`, `gcc`, etc (full list [here][stdenv_tools]) and some Nix functions like `mkShell` and `mkDerivation`.

It turns out that `mkShell` is a specialized version of `mkDerivation`, so the inputs to `mkShell` are the inputs to `mkDerivation` plus some shell-specific extras such as options to set the shell prompt, commands to execute before entering the shell, etc. You can read all about `mkShell` [here][mkshell] and its inputs [here][mkshell_attributes]. The `mkDerivation` function looks for an input called `buildInputs`, which contains a list of dependencies needed for building your package (this isn't the whole story regarding dependencies, but I'm reserving that story for another post). For the moment let's just say we have no dependencies.

```nix
{
    description = "A flake for a Rust development environment";
    inputs = {};
    outputs = {self} : {
        devShells.aarch64-darwin.default = mkShell {
            buildInputs = [];
        };
    };
}
```
Did it work?
```
$ nix develop
error: undefined variable 'mkShell'

       at /nix/store/7g87ps2mnlh42721p8xwm36vd27b2svi-source/flake.nix:5:36:

            4|     outputs = {self} : {
            5|         devShells.aarch64-darwin = mkShell {
             |                                    ^
            6|             buildInputs = [];
```

Remember that Nix is a functional programming language, so if we don't explicity have `mkShell` in our inputs (which we don't, yet) we can't use it in our `outputs` function. Where are we supposed to get this `mkShell` function from? 

In "Old Nix" this function is in a package called `stdenv` that I think is just available in every "derivation" you make. As far as I can tell, a "derivation" is essentially a pre-flakes Nix package. But we're working with flakes, so where is `mkShell` now? Again, from reading blog posts I see that `mkShell` now resides in `nixpkgs.legacyPackages.${system}`, where `nixpkgs` is essentially the universe of Nix/community-maintained packages. As far as I can tell the `legacyPackages` part is there for compatibility since all the packages in `nixpkgs` aren't written as flakes. Someone feel free to correct me on that.

In order to use `mkShell` we'll need to bring in our first dependency: `nixpkgs`. We refer to other flakes with "flake references", which can come in different formats depending on where the flake is or who's providing it (see the [Flake references][flake_refs] section of the manual for the details). For git hosts like GitHub (where `nixpkgs` is hosted) there is a URL scheme with the format `github:<owner>/<repo>/<branch>` where if `<branch>` is master you can just omit that part of the URL. Different releases of `nixpkgs` are put on separate branches such as `release-22.11` or `nixpkgs-unstable` if you want to live on the edge. I'm feeling spicy so our `nixpkgs` flake reference will look like `github:nixos/nixpkgs/nixpkgs-unstable`. Let's add that and see how things go:

```nix
{
    description = "A flake for a Rust development environment";
    inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    outputs = {self, nixpkgs} : {
        devShells.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.mkShell {
            buildInputs = [];
        };
    };
}
```
And it works! Hooray! Before we move on I'd just like to reiterate that the `inputs.nixpkgs.url` syntax is equivalent to
```
inputs = {
    nixpkgs = {
       url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };
};
```
and that the `url` field here is not an actual URL that you would paste into your browser but is instead a URL in the general sense of the word.

Before moving on we can also make our flake less verbose by using the `let ... in ...` construct, which allows you to bind names to arbitrary expressions (such as creating a shorthand name for a bigger expression). First we'll create a shorthand for the `nixpkgs` for my specific system:
```nix
{
    description = "A flake for a Rust development environment";
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };
    outputs = {self, nixpkgs} :
        let
            pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        in {
            devShells.aarch64-darwin.default = pkgs.mkShell {
                buildInputs = [];
            };
        };
}
```
Note that we've changed some of the braces here. Previously we had `outputs = {self, nixpkgs}: {...};` but now we have `outputs = {self, nixpkgs}: let ... in {...};` since the `in {...}` part is the actual attribute set that our `outputs` function is returning.

Next we'll create a shorthand for the system.
```nix
{
    description = "A flake for a Rust development environment";
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };
    outputs = {self, nixpkgs} :
        let
            system = "aarch64-darwin";
            pkgs = nixpkgs.legacyPackages.${system};
        in {
            devShells.${system}.default = pkgs.mkShell {
                buildInputs = [];
            };
        };
}
```
Note that we've used `system` in both the definition of `pkgs` and our `devShell`.

So, we have a shell, but we still need tools do our Rust stuff.

## Rust
We'll definitely need `rustc` and `cargo` to build our Rust crate. Normally these are both downloaded and managed by `rustup` and you'll add a `rust-toolchain` file to choose a specific version for your project or keep a record of which version you were using at which point in time. At the moment I'm not sure if you have this ability with Nix, it sounds like you just get whatever version is defined in your version of `nixpkgs` (the latest stable version if you're using `nixpkgs-unstable`).

So how do we know which packages to include? You can actually search all of the available packages that Nix knows about at [search.nixos.org][nix_search]. If you do a search for `rustc` you'll find this listing: [rustc][nixpkgs_rustc]. First let me note that it's a little weird that I can't link directly to the `rustc` search result, I have to link the `nix-shell` tab of the `rustc` search result. Second note that it lists a number of programs that it provides, like `rust-gdb`, `rustdoc`, etc. You can do a similar search for `cargo`. Let's add both packages to the flake:
```nix
{
    description = "A flake for a Rust development environment";
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };
    outputs = {self, nixpkgs} :
        let
            system = "aarch64-darwin";
            pkgs = nixpkgs.legacyPackages.${system};
        in {
            devShells.${system}.default = pkgs.mkShell {
                buildInputs = [pkgs.rustc pkgs.cargo];
            };
        };
}
```
Now lets hop into our shell and try to make and compile a crate:
```
$ nix develop
(nix:nix-shell) chonker:rust_flake zmitchell$ cargo init
     Created binary (application) package
(nix:nix-shell) chonker:rust_flake zmitchell$ cargo build
   Compiling rust_flake v0.1.0 (/Users/zmitchell/code/rust_flake)
    Finished dev [unoptimized + debuginfo] target(s) in 1.30s
```
We did it!

But, do we really need to enter the shell just to build the package? Of course not! Let's see how we can get Nix to build the package for us.

## Building a crate with Nix
Nix has a built-in function for building a Rust crate called `rustPlatform.buildRustPackage`, and the documentation for it can be found in the [Nixpkgs manual][build_rust_package]. If you read a little bit you can see that the required attributes are:
- `pname`: the package name (the name of your crate)
- `version`: the version of your crate
- `src`: where to find the source for the package (`.` when building your own crate)
- `cargoLock.lockFile`: The path to your `Cargo.lock` file

Let's just add that to our flake:
```nix
{
    description = "A flake for a Rust development environment";
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };
    outputs = {self, nixpkgs} :
        let
            system = "aarch64-darwin";
            pkgs = nixpkgs.legacyPackages.${system};
        in {
            devShells.${system}.default = pkgs.mkShell {
                buildInputs = [pkgs.rustc pkgs.cargo];
            };

            packages.${system}.default = pkgs.rustPlatform.buildRustPackage {
                pname = "rust_flake";
                version = "0.1.0";
                src = ./.;
                cargoLock.lockFile = ./Cargo.lock;
            };
        };
}
```
Before moving on you'll also need to add `Cargo.lock` to git, otherwise `Cargo.lock` won't be included in the build and the reference `cargoLock.lockFile = ./Cargo.lock` will fail. Once you've done that you can do `nix build` and it should compile your crate! You should now have a directory called `result` that's a symbolic link to the directory in the Nix store where the compiled binary was stored.
```
$ ls -al
total 64
drwxr-xr-x  11 zmitchell  staff    352 Feb 20 17:58 .
drwxr-xr-x  27 zmitchell  staff    864 Feb  4 15:05 ..
drwxr-xr-x  12 zmitchell  staff    384 Feb 20 17:56 .git
-rw-r--r--   1 zmitchell  staff      8 Feb 19 10:05 .gitignore
-rw-r--r--   1 zmitchell  staff  15940 Feb 20 17:29 Cargo.lock
-rw-r--r--   1 zmitchell  staff    194 Feb 20 17:29 Cargo.toml
-rw-r--r--   1 zmitchell  staff    569 Feb 18 19:51 flake.lock
-rw-r--r--   1 zmitchell  staff    684 Feb 20 17:58 flake.nix
lrwxr-xr-x   1 zmitchell  staff     60 Feb 20 17:58 result -> /nix/store/nxrjsynrybf0xz2n3yzh5yhc1z80v61f-rust_flake-0.1.0
drwxr-xr-x   3 zmitchell  staff     96 Feb 19 10:05 src
drwxr-xr-x@  6 zmitchell  staff    192 Feb 20 16:40 target
```

If we execute `result/bin/rust_flake` we should see the following:
```
$ ./result/bin/rust_flake
Hello, world!
```
We can also run the binary via `nix run`. Cool!

## Moving forward
This is a pretty basic Nix workflow and there are some rough edges that we'll address in the future.
- If you modify `main.rs` all of your crate's dependencies are recompiled. That's _worse_ than without Nix.
- Right now our flake only works for a single architecture (the one we hardcoded in as `system`). Surely there's a way to extend our flake to be more flexible in this regard (spoiler, of course there is).
- You may want different dependencies available at development-time, build-time, and run-time. For example, say you need to generate code based on Protobuf schemas, you'll probably need `protoc` around for that. You need that at build time, but you don't need it at run-time and you may or may not need it around at development time. Right now all of our dependencies are around at build time and development time.
- How do you build a workspace instead of a single crate?

## The SEO problem
Before leaving off I'd like to point out an area of improvement for the Nix project. Very often I found myself searching for a topic and the official sources were not in the top few search results, if they were present at all. For example, let's say I vaguely remember that the documentation for `mkShell` was in a section about "builders" ([Special Builders](https://nixos.org/manual/nixpkgs/stable/#chap-special)) and I do a search for "nix builders". My default search engine is DuckDuckGo, and the first page of search results (in order) are:
- A construction company
- A different construction company
- Nix builds as a service
- A rehosted version of a related page ([Trivial Builders](https://ryantm.github.io/nixpkgs/builders/trivial-builders/)
- The Facebook page of one of the above construction companies
- A custom home builder
- A different page from the site of one of the above construction companies
- The Generic Builders page on Nix Pills
- The Distributed Builds page on the NixOS Wiki
- A review of one of the above construction companies

If I do the same search on Google the results are better, but still not good:
- A construction company
- Remote Builds - Nix Reference Manual
- Nix builds as a service
- Construction company
- Distributed builds - NixOS Wiki
- `nixpkgs/trivial-builders.nix` on GitHub (so close Google, so close!)
- Review of a construction company
- How to Learn Nix, Part 32: Builders - Ian Henry

The page I'm looking for is not in the first page of results on either search engine. Ok, maybe my search was too obscure, but I don't think I'm being unreasonable here. Even with more precise search terms it's very common for other resources to come up before the official Nix pages.

## Questions for the audience
1. Doing a build to produce a package makes sense conceptually, but doing a build to provide a shell environment makes less sense. What are the attributes that `mkShell` produces and how are they turned into a running shell environment?
1. Can someone explain why/how the `stdenv` package is available in derivations, but with flakes the contents of `stdenv` are available under `nixpkgs.legacyPackages.${system}`? In other words, why `pkgs.mkShell` vs. `stdenv.mkShell`?
1. Is there a way to keep `version`, and `meta` in sync with the data in `Cargo.toml`?
1. What are your favorite Nix tools for Rust? I'm aware of `rust-overlay`, `naersk`, and `crane`. 

## Resources
- [Flakes - NixOS Wiki](https://nixos.wiki/wiki/Flakes)
       - Official overview of flakes
- [`nix flake` - Nix Reference Manual][flake_command]
       - Detailed description of flakes, their required attributes, etc
- [`nix develop` - Nix Reference Manual][develop_command]
       - What's required to start a development shell
- [Practical Nix Flakes - serokell.io](https://serokell.io/blog/practical-nix-flakes)
       - An overview of using flakes
- [Nix Flakes - zimbatm.com](https://zimbatm.com/notes/nixflakes)
       - An overview of using flakes

[installation]: https://nixos.org/manual/nix/stable/installation/installing-binary.html
[old_vs_flakes]: https://zimbatm.com/notes/summary-of-nix-flakes-vs-original-nix
[flake_schema]: https://nixos.wiki/wiki/Flakes#Flake_schema
[flake_command]: https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html
[flake_refs]: https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html#flake-references
[flake_inputs]: https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html#flake-inputs
[develop_command]: https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-develop.html
[nix_develop_reqs]: https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-develop.html#flake-output-attributes
[legacy_packages_toot]: https://hachyderm.io/@zmitchell/109808901311164663
[nixpkgs_manual_official]: https://nixos.org/manual/nixpkgs/stable/
[nixpkgs_manual_rehosted]: http://ryantm.github.io/nixpkgs/
[stdenv]: https://nixos.org/manual/nixpkgs/stable/#chap-stdenv
[mkshell]: https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-mkShell
[stdenv_tools]: https://nixos.org/manual/nixpkgs/stable/#sec-tools-of-stdenv
[mkshell_attributes]: https://nixos.org/manual/nixpkgs/stable/#id-1.5.5.4.4
[flake_url_refs]: https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html#url-like-syntax
[nix_search]: https://search.nixos.org/packages
[nixpkgs_rustc]: https://search.nixos.org/packages?channel=unstable&show=rustc&from=0&size=50&sort=relevance&type=packages&query=rustc#
[build_rust_package]: https://nixos.org/manual/nixpkgs/stable/#compiling-rust-applications-with-cargo
[installer_issue]: https://github.com/DeterminateSystems/nix-installer/issues/212
[nix_installer]: https://github.com/DeterminateSystems/nix-installer