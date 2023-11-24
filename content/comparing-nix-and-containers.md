+++
title = "Comparing Nix and containers"
date = 2023-11-19
description = "If you use Nix for any amount of time it's inevitable that you'll be asked \"why not just use containers?\" from someone who either has never heard of Nix or who _has_ heard of Nix and isn't convinced of the value proposition. There are several companies that are now selling Nix consulting services or building products that either present a nice interface to Nix or use Nix as an implementation detail (like my employer). As authors of these tools we should be able to articulate the tradeoffs in a way that's complete, clear, and (hopefully) convincing."
+++

If you use Nix for any amount of time it's inevitable that you'll be asked "why not just use containers?" from someone who either has never heard of Nix or who _has_ heard of Nix and isn't convinced of the value proposition. There's also VMs, FreeBSD Jails, etc, but I only have so much time in the day to write stuff like this so we're just going to focus on containers.

There are several companies that are now selling Nix consulting services or building products that either present a nice interface to Nix or use Nix as an implementation detail (like my employer).
As authors of these tools we should be able to articulate the tradeoffs in a way that's complete, clear, and (hopefully) convincing.

For this post I'm going to assume you're using flakes just for the sake of not juggling flake and non-flake commands.
{% details(summary="What are flakes?") %}
A "flake" is a Nix file named `flake.nix` (just like Docker uses a file called `Dockerfile`) that adheres to a particular schema. A `flake.nix` file contains an attribute set (Nix equivalent of a dictionary, map, etc) with the following attributes:
- `inputs`: an attribute set of packages and libraries to use as inputs to the build
- `outputs`: a single-argument function that produces an attribute set of build artifacts

The `outputs` attribute has a defined structure in which the name of some artifacts have semantic meaning:
- `packages.${system}.default` is the default package to build when calling `nix build` for `${system}` (`{aarch64,x86_64}-{linux,darwin}`).
- `packages.${system}.foo` is another package that can be built.
- `devShells.${system}.default` is the default shell environment that will be entered when calling `nix develop` for `${system}`.

A barebones `flake.nix` looks like this:
```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = {self, nixpkgs, ...}:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [
          pkgs.ripgrep
          pkgs.python310
        ];
      };
    };
}
```

Flakes also have a URL scheme for referring to each other so that you can easily refer to packages that are stored on remote machines.
For example, you could activate the default shell environment defined in the `flake.nix` file stored at `https://github.com/owner/repo` via `nix develop github:owner/repo`.
{% end %}

Finally, I'll also say that using whatever tool you want is totally fine.
If someone asks you why you use X instead of Y, "because I feel like it" is a valid answer.
You do you.

With all of the "please, internet mob, don't yell at me" out of the way, let's dig in.

## "What is Nix?"
Answering the question "what is Nix" can be tricky for two reasons:
- It's not clear whether the questioner means Nix the language, Nix the build system, or NixOS the Linux operating system.
- Nix can do a lot of things.

The first one isn't terribly hard to clear up.
The second one is _much_ trickier.

Nix can do a lot of things, and different people use it for different things.
Often as a Nix user you're excited to tell someone about Nix and you don't want to sell it short, so you start trying to explain _everything_ it can do.
This often ends up going over people's heads or sounding like technical gibberish.

{{ youtube(id="Ac7G7xOG2Ag") }}

For the rest of this post we're going to limit ourselves to:
- Using Nix to build and configure development environments
- Using Nix to build software artifacts (including containers)

## Problem statement
Containers and Nix wouldn't be popular if they didn't solve a real problem for people. That problem as I see it can be broken down into a few pieces:
- I want to create a development environment:
    - The environment has all of the tools I need for developing software
    - The tools have precedence over any copies of the tools I have installed globally (e.g. system version of Python)
    - The tools don't pollute my system i.e. they aren't there when I'm not using them TODO: haven't addressed this yet
- I want to be able to share that development environment with other people
    - It should be easy to bundle up the environment itself or a way of recreating it so I can send it to someone else.
    - I should be able to pull down an environment that someone else has created with a reasonable amount of confidence that it's the same one they meant to share with me.
- I want to build my software with some amount of confidence that if I build it today I'll still be able to build it tomorrow
- I want the environment I develop in to be as close as possible to the environment my software is running in to reduce the possibility of bugs due to differences in environments.
- I want it to be easy to send the software I've developed into production.

## Building a development environment
Let's start with this most basic want: to be able to create some kind of environment at all.

### Build instructions
Containers are most often created from a Dockerfile.
The syntax is simple and you can pretty much read what a Dockerfile is doing without knowing anything about containers.
The bulk of the Dockerfile consists of `RUN` statements, which are basically the commands you would run on that system in order to build up the system you'd like to work on top of.
This is convenient because you're probably already familiar those commands.
This means there's less to learn to get started.

A Dockerfile begins by declaring the base system you'd like to build up from:
```Dockerfile
FROM ubuntu:latest
```
This in itself tells us something: Dockerfiles present you with a userspace to configure and build on top of.

A Nix build and a Nix development environment are specified the same way: by writing a program in a lazily evaluated, pure functional programming language (Nix).
In this program you declare the direct inputs to your build (a compiler, your source code, library dependencies, etc), and you write a function that uses those build inputs to produce an artifact, usually through language- or framework-specific helper functions.

For building a Rust program that can be as simple as:
```nix
myPkg = pkgs.rustPlatform.buildRustPackage {
  pname = mypkg;
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [
    pkgs.rustc
    pkgs.cargo
  ];
};
```
What's really nice about this is that it's declarative and only includes details about your specific package.
You aren't dealing with configuring an entire userspace around your artifact.
You also don't need to install transitive dependencies yourself.
Your build inputs declare their build inputs, so the whole dependency tree gets

In general, though, writing a Nix file to build your software will feel very alien for a number of reasons:
- Nix is lazily evaluated, which can be mind-bending if you haven't seen that before.
- Nix is a pure functional programming language, which can also be mind-bending if you haven't seen that before.
- Nix tries to fit language-specific constructs into a common-denominator interface for building _the entire universe of software_, so it can be hard to map what you want to accomplish onto Nix-isms.
- The documentation leaves...much to be desired.

The Nix documentation can simultaneously be nonexistent, sparse, overly verbose, misleading, or outdated depending on which resource you're looking at.
I say this as a member of the Nix Documentation Team.
Most of us joined in order to fix that situation.
I don't think anyone on the Documentation Team would react to criticism of the Nix docs with "how could you say this about my precious, perfect baby".

The Nix error messages are also not the greatest.
One of my coworkers is fond of asking "did Nix just tell me to go fuck myself?"

It's relatively easy to separate dependencies needed at build time, development time, and run time, you just list the dependencies in a different array.
A flake that builds a package using different sets of dependencies looks like this:
```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = {self, nixpkgs, ...}:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in
    {
      packages.x86_64-linux.default = pkgs.mkDerivation {
        src = ...;
        buildInputs = [
          # Run time only deps go here
        ];
        nativeBuildInputs = [
          # Build time only deps go here
        ];
        propagatedBuildInputs = [
          # Deps needed at build and run time (like Python libraries) go here
        ];
      };
    };
}
```
You'll note that `buildInputs` are used at run time, `nativeBuildInputs` are used only at build time, and `propagatedBuildInputs` are used for both.
If you find that confusing as fuck, you are correct.
Feel free to read the [Specifying dependencies](https://nixos.org/manual/nixpkgs/stable/#ssec-stdenv-dependencies) section of the `nixpkgs` manual.
It may or may not help, especially this [big ass table](https://nixos.org/manual/nixpkgs/stable/#ssec-stdenv-dependencies-reference).
Godspeed.

Splitting up your build/environment into multiple files is also possible, and in fact this is often the default way to do things without flakes.
This makes it possible to assemble a build or environment from modular, reusable pieces, which is great for spinning up new projects.

A Nix shell environment is essentially an interrupted build.
A Nix build does package specific setup for each package in the dependency tree before calling the builder executable.
Calling `nix develop` drops you into a Bash subshell in which all of this same setup has been done right up to the point where the builder was about to be executed.
If you're already _building_ your artifacts with Nix, you get an always up to date development environment for free.

Nixpkgs is a truly enormous package repository, but it doesn't have _every_ package.
For example, you won't find less popular Python packages in nixpkgs.
This means you either have to package something yourself, or you need to use a `<my language>2nix` type tool that translates your language specific config to something Nix can understand.

### Build process

#### Containers
Without placing any kind of value judgement on this statement, the common joke about containers is that they solve the "it works on my machine" problem by bundling up your entire machine and shipping it to other developers.
This is tongue in cheek, but there's a little bit of truth to it.
A container is essentially a snapshot of a slimmed down machine.

Filesystem snapshots (layers) are created from each `RUN`, `COPY`, etc statement in the Dockerfile.
An entry point for the container is specified via the `CMD` statement.
Commands like `apt install` by default will install packages that are _recommended_ but not _necessary_ and will populate some caches during package installation so that later invocations of `apt install` are fast.
Neither of these are necessary for an ephemeral container, so part of building a Dockerfile is finding and tweaking system commands whose defaults cause bloat.
In other words, eliminating bloat is an _opt-in_ mechanism.

The container image is assembled by bundling together these layers so that they can be overlaid on top of each other, along with some additional metadata.
The container manifest records the order in which the layers should be overlaid so that the layers can be cached independently of the image itself.
The image is then ready to be run by your favorite container runtime.

Part of the process of setting up a Dockerfile is tuning it to reduce the build time and image size.
This can often mangle what would otherwise be an easy to understand process for building the system.
Rather than grouping package installations and setup steps that logically go together, you end up grouping things based on how frequently they're likely to change for the sake of fewer rebuilds.
In (hopefully) rare cases you find yourself in a special kind of hell where two layers are undergoing active development (say in some monorepos) and there's no way to sequence them to prevent frequent rebuilds.

Dockerfiles don't lend themselves to being split up or reused across projects (without literally using the same image).
A Dockerfile with more than a few build stages gets ugly really quickly.
You typically set up a different Dockerfile for each project you're working on, which involves a lot of copying and pasting because there's not really something like a module system for Dockerfiles.
This also makes it easy to introduce subtle differences by mistake.

#### Nix
A Nix development environment is lazily built by calling `nix develop`.
Nix evaluates the Nix code in your `flake.nix` file, which eventually produces a "derivation".
A derivation is just a computation that produces an artifact (an executable, library, shell environment, etc).

{% details(summary="Wait, how can a shell environment be an artifact?") %}
The artifact is a directory containing symbolic links to all of the programs, libraries, etc that make up the environment.
The artifact also includes an activation script that executes a subshell, sets environment variables, and puts this directory full of symlinks into `PATH` so that the programs are available in the shell.
{% end %}

As part of producing the derivation Nix hashes and locks all the inputs to the derivation, namely:
- The `flake.nix` file itself
- The derivations (executables and libraries) that this derivation depends on
- The "builder" executable, which is the executable responsible for calling the build commands (e.g. `make`, `cargo build`, etc) and putting the artifact in the correct place
- `system` (the platform and architecture the build is being run on)

Here you can see that just about every part of the build environment and process is hashed and locked to provide a high degree of reproducibility.

After hashing all of these things Nix will then look to see if the directory `/nix/store/<hash>-<name>` exists.
If it does, the artifact has already been built and there's no need to rebuild it.
If it doesn't, it will attempt to download it from any "substituters" (remote caches like `cache.nixos.org`) that are configured.
If it can't be found in any of the caches, then Nix knows that it needs to be built from source.
This process is done recursively for the entire dependency tree, but usually all of your dependencies are cached somewhere and you'll only need to build your artifact from source.

{% details(summary="Incremental compilation") %}
Nix builds from source, meaning that there's no incremental compilation.
This means that by default large projects in some languages like C++ and Rust will experience pretty long build times.
Luckily there are Nix libraries that automatically create separate derivations for each dependency in say `Cargo.toml`, so those get built once and are only rebuilt if you update your `Cargo.lock`.
This effectively restores incremental compilation.
{% end %}

The directory `/nix/store` is called the "Nix store", and it acts as both a giant build cache and a key-value store.
When viewed as a key-value store, the directory names `<hash>-<name>` are the keys and the values are the artifacts contained in those directories.
Nix calls directory names like `/nix/store/<hash>-<name>` "store paths".

Nix hardcodes the specific store paths that an artifact depends on into the artifact, so it's impossible to accidentally depend on the wrong dependency simply by copying a new version of `libfoo` into `/usr/lib/include`.
More specifically, Nix will modify an executable's `RPATH`, which is the set of runtime paths the executable tells the linker to search when locating dynamic libraries to link to.

In other words, we can have two packages `foo` and `bar` that link to two different revisions of the _same version_ of `libbaz` because at runtime the linker will link `foo` with `/nix/store/<hash1>-libbaz-v1.2.3` and will link `bar` with `/nix/store/<hash2>-libbaz-v1.2.3`.

Nix creates an environment primarily by setting `PATH` and `PATH`-like variables (e.g. `PYTHONPATH`, `LD_LIBRARY_PATH`, etc) either by prepending store paths directly to `PATH` or by adding a directory to `PATH` and symbolically linking store paths into this directory.
You can use `nix profile install` as an analog to something like `brew install` and it works using this latter method (the directory lives at `$HOME/.nix-profile`).

## Developing in the environment

### Running a single command

With a container you need two steps (1) start the container, (2) issue the command.
First start the container:
```
$ docker run -d --name <container name> <owner>/<name> <optional startup command>
```
Then issue the command:
```
$ docker exec <container name> <command>
```
That's kind of a mouthful just in order to run a single command inside of a container.

With Nix you just need a single command:
```
$ nix develop --command <command>
```

### Typical development workflow

#### Containers
The first step is running the container image.
What you do next is largely determined by your development tooling.

If you use a terminal-based text editor, you probably just SSH into the container and start working with (neo)vim, emacs, etc.
This puts you in a running version of the userspace and filesystem that you set up with the commands in the Dockerfile.
You can't call programs you didn't install in the Dockerfile, even if they exist on the host (the machine the container is running on).
This can be both a pro and a con depending on the context.
- Pro: you can't accidentally call the system version of Python on the host.
- Con: you can't call a handy tool that's already installed on your system.

By default all of your precious, artisinally handcrafted dotfiles aren't found inside of the container.
This is a major bummer and can make it feel like the environment isn't "yours" even though it's right there running on your machine.
There are ways to get your dotfiles working inside the container, but again this is an opt-in mechanism and new users are unlikely to figure this out on their own.

If you use an IDE it needs to be container-aware or otherwise have some remote development capability.
The most popular IDEs and text editors at least have support for remote development, so this isn't a huge imposition, but it can be a problem if you want to try incorporating a new experimental text editor into your workflow.
In some places the ordained way of working is inside a container on a remote VM, which is painful and no IDE knows how to handle on its own.
There's probably a way to make that work with SSH port forwarding, but at this point you're jumping through hoops just to get your _IDE_ working.

In order to do any kind of development in the container you also have to set up volume mounts so that you can share files between the host and container.
This is a pretty basic container usage skill, but again, it's an opt-in mechanism.

One benefit of this "using a container via SSH" workflow is that your local development workflow now looks exactly like your remote development workflow.
That can be a blessing if you need to work on remote machines frequently.

You don't have to worry about any of this with Nix since you're just working with normal OS processes.
You just activate the environment with `nix develop` and then launch your editor from the command line so that it inherits the correct environment variables
```
$ nix develop # after this we're in Bash in the environment
$ code . # opens VS Code with all the correct environment variables set
```

It's important to note that you always get a Bash shell when activating the environment.
Remember that I said a Nix development environment is basically an interrupted build, and in order to make builds reproducible Nix uses Bash across the board.
My employer is working to let you bring whatever shell you want to a Nix-powered environment.

Once you're in this subshell your `PATH` now has those packages from your `flake.nix` prepended.
Since you're just in a subshell you still have access to the whole filesystem.
Note that we haven't cleared `PATH`, so you can call programs that weren't installed as part of your environment.
Again, there are pros and cons here depending on the context.
Do note that `PATH` is cleared during a build for the sake of reproducibility.

If you're on macOS you're developing on a VM, which has consequences for certain tools, such as those that need access to hardware performance counters.
Those typically aren't emulated by VMs, so you're just completely out of luck there.

## Composition
With containers you can't use multiple environments at the same time.
Imagine you have a monorepo that has the frontend and backend in the same repo.
You have two options:
- Have one monster image that always contains the tools from both environments.
- Have a frontend image and a backend image, then switch between them when you want to tweak something on the other side

With Nix you can simply run `nix develop` multiple times, each time pointing at a different flake.
TODO: this _has_ to break something, right?

## Reproducibility

### Containers
In this example above we used `ubuntu:latest` just for simplicity.
This is not a best practice and I don't want to create a strawman.
However, it does illustrate a point: two different invocations of `docker build` for this image could have two very different base operating systems, and therefore package versions, depending on when the two different invocations were run.
However, it's _also_ possible to get a different system even if you use a specific tag like `ubuntu:23.10`.
Between bugfixes, security updates, etc you're not guaranteed to get the exact same system from `docker build` to `docker build`.
You can specify the image digest ([Dockerfile Reference - From](https://docs.docker.com/engine/reference/builder/#from)) and get the same system from invocation to invocation, but again this is an opt-in mechanism and in practice I've rarely seen it actually used.
Regardless of the whether you're using an image digest, the program building the container (e.g. `docker build`) isn't included in the digest for the container image, so its possible that even with the same Dockerfile and base image you could get a different final image.

Another issue with the imperative "run the same commands you would run on the system" approach to building an environment is that it's possible to accidentally build correctly.
Suppose you install package `foo` which also installs `libsomething`.
Later you decide to install package `bar` which requires `libsomething`.
Everything works, and that's great.
Then you decide you no longer need package `foo`, so `libsomething` no longer gets installed as part of building your image.
Now your build fails because you can't run `bar` without `libsomething`, which only got installed before because you were installing `foo`.
TODO: Need a better example here, `libsomething` is probably installed by `bar` as well if it actually needs it.

Let's consider another case: a transitive dependency is updated.
Suppose you depend on package `foo v1.2.3` and `foo` has a dependency `bar`.
Now `bar` is updated for whatever reason and this update introduces a subtle bug.
First and foremost, you're no longer operating in the same environment because your dependency tree is different.
You may not even be aware that your dependency tree changed, but you still have a bug in your system.

### Nix

A Nix build determines the entire closure of software needed by the artifact being built.
Nix hashes the entire dependency tree of your artifact, including the source, the inputs, and the executable used to build your artifact.
The build isn't allowed to access the network unless you provide the hash of the fetched resource to verify that it's the intended resource.
The build is also performed in a `chroot` and a separate namespace to create a hermetic build environment.

With a Nix build you aren't guaranteed to get something that's bit-for-bit reproducible from machine to machine, but you get very close.
You're essentially guaranteed that a build targeted towards a particular platform and architecture will work the same way on all machines of that platform and architecture.
"It works on my machine" effectively means that it works on everyone else's machine.

Reproducibility for its own sake is nice, but reproducibility is what allows these hashed artifacts in the Nix store to be shared between machines so easily.

## Resources

It's well known that container images can be huge.
It's also [well](https://pythonspeed.com/articles/docker-performance-overhead/) [documented](https://pythonspeed.com/articles/gunicorn-in-docker/) that the isolation and security mechanisms that containers use can cause performance issues.
On macOS and Windows you also need to run a Linux VM in order to run containers at all, which comes with its own performance implications and resource draws.

With Nix the artifacts that you build are just like any other processes on your machine, so there's no runtime performance impact.

This isn't to say that Nix has no resource usage issues, they just happen to not be runtime resource hits.
The Nix store, like any cache, will grow indefinitely without some kind of cache eviction policy.
The default mechanism is to clean up artifacts that don't have active symlinks to them (these symlinks are produced during builds).
However, there's not an automatic GC mechanism unless you're using NixOS.
This can be a real problem.
I have a 2TB drive on this machine and I noticed at some point that I had ~300GB of free space left.
I ran `nixos-collect-garbage` and freed up 850GB.
Woof.

## Sharing
With a container you can pull and run someone else's image pretty easily:
```
$ docker run <owner>/<repo>
```
This is important because a common method of sharing an image among the developers on a team is to put the Dockerfile in its own repo where it's built, then developers each pull and run the same pre-built image.
This makes it such that developers don't _need_ to build the image, but can also lead to a situation where it's unclear whether developers _can_ build the image if the developers can't replicate the build environment of CI.

With flakes the story is also pretty straightforward:
```
$ nix develop github:<owner>/<repo>
```
Since Nix builds are reproducible, you're guaranteed* that this will work if it works for someone else with a machine of the same platform/architecture.

## Build vs. development vs. production environments
With containers you typically have a single Dockerfile with several stages.
You might have a `builder` stage that installs the compiler, copies in secrets, etc.
You might also have a `dev` stage that starts from the `builder` stage, and brings in any development tools.
Finally, you might have a `prod` stage that simply copies in the compiled binary produced by the `builder` stage.

In this scenario you aren't actually making sure that the production environment is the same as the development environment.
Instead, you're making an evironment that's as trimmed down as possible to hopefully reduce the possibility of conflicts.
This gives you _some_ confidence that things will work as predicted, but it doesn't give you _complete_ confidence.

If you're building (in addition to developing) with Nix, you get a development environment for free that you know is always up to date given that a development environment is again simply an interrupted build.

A Nix production environment simply needs a Nix store containing the dependency tree produced by the Nix build.
This can either be a VM or a container built with Nix (Nix can produce a container containing the compiled artifact _in addition_ to the compiled artifact itself).
Since Nix modifies `PATH` and hardcodes the dynamic library lookup path of the artifact, the system it's running on is largely (but not _entirely_) irrelevant.

## Isolation

Out of the box containers provide more isolation than an artifact produced with Nix since by default each container is run in its own namespace.
Nix just produces normal executables, so by default they provide no isolation with regards to filesystem or network access.
As I mentioned, these isolation mechanisms can cause performance degradations, and you can't opt out of them.

A Nix-built artifact still only depends on other libraries/executables in the Nix store, so there's some degree of isolation, but it's not the same as what a container provides.
However, on Linux you can still apply namespace and control groups to these artifacts, so in some sense isolation and reproducibility can be composed with Nix, whereas with containers the two come bundled together.

## Security

When it comes to security it depends on which container runtime you're using.
It used to be the case that Docker would run both the Docker daemon and containers as root.
This is a problem because any process that breaks out of the container's namespace now has root access on the host machine.
Docker still runs the daemon as root, but now has an option to run containers as normal users.

A artifact produced with Nix is again just a normal process, so by default it will run without root privileges, but also without any additional restrictions for increased security.

It's trivial to query the dependency tree of a Nix artifact, which means that it's trivial to produce a software bill of materials (SBOM) that can then be scanned for vulnerabilities.

## Deployment
There's a lot of infrastructure that's been developed around the container ecosystem, and it shows.
It's pretty straightforward to set up a CI/CD system that on every push will build a new container, upload it to a registry, pull the new container from the registry and spin it up in production.

With Nix the infrastructure story isn't as mature.
There's currently a few companies building Nix-based CI solutions that include caching (GitHub CI doesn't play will with Nix out of the box), but the CD side isn't as clear.

If you're using Nix to build containers, deployment is simple: you build a container with Nix in CI, and then the rest is the same as with any other container-based deployment method.
If you're deploying to a collection of VMs you can copy the dependency tree (the "closure") to all of your running systems with [nix-copy-closure](https://nixos.org/manual/nix/stable/command-ref/nix-copy-closure).
This is a simple command, and there are other Nix-based deployment frameworks out there, but they all strike me as complicated and not as mature as most container-based solutions.

## Conclusion

If you made it all the way to the end, congratulations, I wish I had something to give you.
Hopefully everyone reading this now has a more informed opinion on how Nix compares to containers.
The intent wasn't to sell Nix, just to educate.
Make your own determinations as to whether the tradeoffs are worth it in one direction or the other.
