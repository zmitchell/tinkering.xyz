+++
title = "The mystery of the disconnecting Nix daemon"
date = 2025-05-03
description = "\"Nix daemon disconnected unexpectedly (maybe it crashed?)\" I saw this from time to time while running the Flox test suite, but none of the other engineers were complaining about it, so I ignored it for a while. Then we started seeing it *outside* of the test suite. Let's get to debugging!"
+++

# Setting the stage


## First contact

At some point in the recent past I started seeing an error when I ran the test suite:

```
---- providers::build::tests::cleans_up_data_no_sandbox stdout ----
stdout: Rendering foo build script to /tmp/nix-shell.VbrWdU/76a8d12a-foo-build.bash
stdout: Building foo-0.0.0 in local mode
stderr: 00:00:00.005725 + mkdir /tmp/store_76a8d12a2a78307d613f8ea3637d16b7-foo-0.0.0
stderr: 00:00:00.008396 + echo 'some content'
stderr: warning: Nix search path entry '/nix/var/nix/profiles/per-user/root/channels' does not exist, ignoring
stderr: warning: Nix search path entry '/nix/var/nix/profiles/per-user/root/channels' does not exist, ignoring
stderr: warning: Nix search path entry '/nix/var/nix/profiles/per-user/root/channels' does not exist, ignoring
stderr: this derivation will be built:
stderr:   /nix/store/4c38jisi0f0vknd20cpjqi3hhwpsz6v1-foo-0.0.0.drv
stderr: error: Nix daemon disconnected unexpectedly (maybe it crashed?)
stderr: make: *** [/Users/zmitchell/src/flox/daemon-panic/build/flox-package-builder/libexec/flox-build.mk:486: foo_local_build] Error 1
```

The important line here is:

```
stderr: error: Nix daemon disconnected unexpectedly (maybe it crashed?)
```

I brought up the error to the team, but this test was passing in CI, and none of the other engineers were seeing it.
While Nix reproducibility is generally rock solid, the tool itself does have bugs in it.
I chalked this up to something weird about my particular setup and moved on with life.

## Ok, now it's a problem

A few months later, we're preparing the regularly scheduled release (we put out new releases every two weeks) and my boss mentions that he's seeing `Nix daemon disconnected` in some situations.
Uh oh.

I mention that I see this when I run the test suite, and another engineer chimes in to say that he's also been seeing this when he runs the test suite.
Cool, so this thing I thought was a "me" thing is apparently an "us" thing.
The release goes out because the feature being exercised by these tests is behind a feature flag, but I decide that it's a priority to fix this bug.

# Digging in

## Context

As part of the Flox test suite we run some commands that perform Nix builds.
There is also some helper functionality that will eagerly clean up store paths rather than waiting for Nix to decide to clean them up whenever the next garbage collection cycle happens.

## When does the error happen?

At this point I can reliably hit the error, but I can't _reproduce_ the error in isolation.
We have 615 unit tests across the entire Rust codebase that makes up the Flox CLI.
The other engineer only saw this error when he ran the entire test suite, but hadn't investigated further to see if it truly required running _all_ of the tests.

I knew that I saw the error when running the entire test suite as well, but it was reliably one of the same three tests every time that failed:

- `providers::build::tests::cleans_up_data_no_sandbox`
- `providers::build::tests::cleans_up_data_sandbox`
- `providers::build::tests::cleans_up_all`

Can I cause the error by just running one of these tests?
Nope.
I run an individual test in a loop a few hundred times, no issue.
I run all three in a loop, and now we get the error.
There's something about these three tests that is making the Nix daemon have a bad day.

It's also important to note that all of the tests in this module are run serially rather than in parallel, precisely because we were running into issues like this.
I didn't have that context when I started debugging this.

## Attempting to reproduce

I look at the operations that the tests are performing, and they boil down to a couple of interactive commands.
I run just those commands in a loop (e.g. without all of the testing stuff), but can't reproduce the error.
This tells me _something_, but not much since I already knew that just running the same test over and over again didn't reproduce the error, and I'm essentially running a single stripped down test with this method.

## Checking the daemon logs

At this point I decide I need more information.
Since the error is related to the Nix daemon, I decide to look in the daemon logs.
I check `/var/log/nix-daemon.log`, but all it contains is a bunch of lines like this:

```
accepted connection from pid <unknown>, user zmitchell
accepted connection from pid <unknown>, user zmitchell
```

No errors, no other information.
Interesting.
From this I decide that there's a couple of options:

- An error is occurring in the daemon, but the daemon doesn't think it's an error.
- An error is occurring in the daemon is such a way that it can't or simply doesn't log it.
- The error isn't happening in the daemon at all.

I also looked in `Console.app` in case there was anything in there, but I don't think the Nix daemon actually sends logs there.
I've never use `Console.app` for debugging before, so it's entirely possible there's information in there that I just don't know how to surface.

## Running my own daemon

Seeing that the daemon logs didn't contain much information, I decided to run the Nix daemon myself with debug logging enabled.
I stop the running Nix daemon with

```
$ sudo launchctl stop org.nixos.nix-daemon
```

Then start my own daemon with

```
$ sudo nix-daemon --debug
```

That spits out an interesting error and immediately exits:

```
objc[78593]: +[__NSCFConstantString initialize] may have been in progress in another thread when fork() was called.
objc[78593]: +[__NSCFConstantString initialize] may have been in progress in another thread when fork() was called. We cannot safely call it or ignore it in the fork() child process. Crashing instead. Set a breakpoint on objc_initializeAfterForkError to debug.
```

After some digging it turns out that you just need to run the Nix daemon with an environment variable set.

```
$ sudo env OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES nix-daemon --debug
```

You can actually see this in the `launchd` config for the daemon, but I didn't think to look at that first:

```
$ sudo launchctl print system/org.nixos.nix-daemon
...
        environment = {
                OBJC_DISABLE_INITIALIZE_FORK_SAFETY => YES
                NIX_SSL_CERT_FILE => /etc/ssl/certs/ca-certificates.crt
                XPC_SERVICE_NAME => org.nixos.nix-daemon
        }
...
```

I run the tests again with my debug-logging-enabled Nix daemon, I see the same test failure, but I _don't_ see anything new in the daemon logs.
Hm.
I need to know more about how the daemon works to rule out something fishy happening there.

## Investigating the daemon internals

After some searching, I tracked down `src/nix/unix/daemon.cc`, which contains the `runDaemon` function.
This function calls `daemonLoop` in that same file.

This has some boilerplate to bind to a Unix domain socket, then forks to handle each new connection.
The forked process then calls `processConnection` in that same file, which has an inner loop that reads opcodes from the socket, then calls `performOp` on that opcode.
`performOp` is in `src/libstore/daemon.cc` and is basically a big `switch` statement.

Since each connection to the daemon forks a new process to handle the connection, if I want to debug the process that's _actually_ doing the work of the daemon, I need to attach a debugger to a forked process.
Well, turns out you can't really do that on macOS (see this [lldb issue][lldb-forks]).

Instead I decided I would just compile the daemon myself with some extra debug logging thrown in.
It's a testament to Nix that I don't need to know anything about this particular project's build process, I just need to know that it's built with Nix so that I can run `nix build`.

I ran the tests again, they failed again, but I still didn't see anything interesting in the daemon's output.

At this point I'm feeling pessimistic that the error happens in the daemon at all.

## Investigating the client side

Now that I'm investigating the client side of the connection I realize I can also turn on debug logs for the `nix build` invocations.
Once I do this I start to get a little more insight into the problem:

```
...
sending GC root '/nix/store/3q2kj5slkj1pliq88axsrw5pjlhrqmhx-foo-0.0.0.drv'
closing daemon connection because of an exception
error: Nix daemon disconnected unexpectedly (maybe it crashed?)
...
```

I see this `closing daemon connection because of an exception` message and start to form the hypothesis that the client is dropping the connection between it and the daemon, and that it's a symptom of a different problem.
I search for this error message, and sure enough, you only see this error message when the destructor for `RemoteStore::ConnectionHandle` runs and there's uncaught exceptions.

I also hadn't seen this `sending GC root` line before, so I searched for that as well and found it in `LocalStore::addTempRoot`.
After running the tests multiple times I didn't always see the same error, but I saw it more frequently than any others.
I also remember that even when I _did_ see this error, the path taken to get there (as I could read it from the logs) wasn't always the same.

Now I'm starting to form the hypothesis that something is happening asynchronously.

## Aside: stores, store paths, and garbage collection

The Nix store can be thought of as a giant immutable build cache.
However, you can actually make use of multiple stores, some of which are remote (e.g. the local Nix store of a machine you've connected to via SSH, an S3 bucket, etc), and some are local (e.g. `/nix/store`).
A "store path" is conceptually a subdirectory directly below `/nix/store`, which contains the output artifacts of a Nix derivation.
Without getting too into the weeds, a derivation is a computation that produces an artifact (a file, a compiled executable, a directory tree, etc).

If you've run the standard Nix installer, your store lives at `/nix/store` and is owned by `root`.
In this situation, you have a `nix-daemon` process running as root and performing priviledged operations on behalf of your unpriviledged user.

Because stores in different locations have different semantics, Nix has a concept of different store types such as "local", "remote", "daemon", etc.
In the case of the typical installation, you have a "local daemon store", which is a store that exists locally, but that you access remotely through a connection to the Nix daemon.
This is why I see the error message from `RemoteStore::ConnectionHandle` even though my store is local to my machine.

Since this is conceptually a cache, at some point you want to evict things from it.
Nix has mechanisms in place to determine when an entry in the store is no longer "live", just like garbage collection of objects in memory.
"Liveness" is primarily (as far as I know) determined by the existence of symlinks to store paths.
I'm fuzzy on the exact details of this, but I think you need to explicitly create the symlink via a Nix command in order for its existence to be recorded in a SQLite database that Nix uses for book keeping.
We call a symlink that makes a store path "live" a "GC root".

This `addTempRoot` function I mentioned earlier serves to create a temporary GC root so that a store path used in an operation isn't garbage collected out from under it during the operation, while at the same time avoiding the need for a persisted symlink somewhere on the filesystem.

Garbage collection can be a gotcha if you're putting more primitive Nix operations together yourself, since a store path without a GC root can be garbage collected in the middle of an operation you care about.
At various points in time, the CI system used to test Flox has helpfully garbage collected things out from under us during tests to keep us on our toes.

## Disconnection error

While tracking down various leads I was running these tests over and over again.
At some point I saw an error I hadn't seen before:

```
sending GC root '/nix/store/1mij38k61bsl2hi7idzpj1ydk0yyp4dq-foo-0.0.0.drv'
GC socket disconnected
connecting to '/nix/var/nix/gc-socket/socket'
closing daemon connection because of an exception
```

Note the `GC socket disconnected` error.
Up until this point I was thinking that GC might be a red herring.
However, this error appears inside that same `addTempRoot` function that the `sending GC root` line comes from, and only appears when the "GC socket" hits EOF unexpectedly.

Now I'm thinking that this GC stuff is no longer a red herring, but a key part of the problem.

## Tom to the rescue

One of my coworkers is [Tom Bereknyei][tomberek], who's on the [Nix Team][nix-team] and the Nix Steering Committee.
It's safe to say that Tom knows his way around Nix.

At some point I get ahold of Tom and we hop on a Zoom call to starte debugging this together.
It's at this point that I actually learn what the hell this GC socket thing is.

It turns out that internally there are GC locks, one of which is a big, global lock.
If one process acquires this global lock, and another process comes by to do anything GC related, it will attempt to acquire the global lock, fail, and attempt to a connect to a socket created by the process that _does_ have the global lock (or at least that's my understanding).
Once that connection is made, the subordinate process will send GC related operations to the process with the global lock via the socket.
This is where the `sending GC root` message comes from.

Here are some links to the source code where this happens:
- [Get the global lock][gh-gc-global-lock]
- [See if you can do GC][gh-gc-shared-lock]
- [Connect to whoever has the lock][gh-gc-connect]
- [Send the GC root over the socket][gh-gc-send-root]

The error we're seeing is consistent with that `writeFull` call in the last link (i.e. "write to the socket to ask the other GC process to do something for us") throwing an exception that isn't caught.
After some investigation, it turns out that the socket is being closed unexpectedly.
However, if you poke around the code in that `addTempRoot` function you'll see some `goto restart` and `try-catch` blocks.
This is supposed to provide error recovery so that if the connection is terminated you can take over and continue doing GC on your own.

Somehow that isn't happening here.

## Exceptional exceptions

`writeFull` is just a wrapper around the `write` syscall, and it really doesn't do much:

```c++
void writeFull(int fd, std::string_view s, bool allowInterrupts)
{
    while (!s.empty()) {
        if (allowInterrupts) checkInterrupt();
        ssize_t res = write(fd, s.data(), s.size());
        if (res == -1 && errno != EINTR)
            throw SysError("writing to file");
        if (res > 0)
            s.remove_prefix(res);
    }
}
```

Seems pretty straightforward to me: if `write` encounters an error, throw a `SysError`.
It's important to note that `SysError` captures `errno` and tries to use `strerror` to turn the error code from `write` into an understandable error.
If you add a debug statement to this function, you'll see that when we hit our error it's because of `errno = 32` or `EPIPE`, meaning that the socket was disconnected.

What's strange is that if you go back to `addTempRoot`, `SysError` is explicitly one of the exceptions we're trying to catch, and we also already handle the `EPIPE` case:

```c++
try {
    debug("sending GC root '%s'", printStorePath(path));
    writeFull(fdRootsSocket->get(), printStorePath(path) + "\n", false);
    char c;
    readFull(fdRootsSocket->get(), &c, 1);
    assert(c == '1');
    debug("got ack for GC root '%s'", printStorePath(path));
} catch (SysError & e) {
    /* The garbage collector may have exited, so we need to
       restart. */
    if (e.errNo == EPIPE || e.errNo == ECONNRESET) {
        debug("GC socket disconnected");
        fdRootsSocket->close();
        goto restart;
    }
    throw;
} catch (EndOfFile & e) {
    debug("GC socket disconnected");
    fdRootsSocket->close();
    goto restart;
}
```

So if that's the case, how do we know that it's this `writeFull` that's causing the exception?
Well, if you put a `try-catch` block inside the body of `writeFull` to catch the `SysError` that it itself is throwing, you can rethrow that as a `std::exception`:

```c++
void writeFull(int fd, std::string_view s, bool allowInterrupts)
{
    try {
        while (!s.empty()) {
            if (allowInterrupts) checkInterrupt();
            ssize_t res = write(fd, s.data(), s.size());
            if (res == -1 && errno != EINTR)
                throw SysError("writing to file");
            if (res > 0)
                s.remove_prefix(res);
        }
    } catch (const std::exception & e) {
        debug("Caught our mystery exception");
        throw;      
    }
}
```

Then you can add a `catch (const std::exception & e) {}` branch to the `try-catch` block in `addTempRoot`.
Once you do this you reliably see that we are catching the `std::exception` from `writeFull` when we see test failures.

So what gives? Why can we catch `SysError` inside `writeFull`, but not in `addTempRoot`?

I do some searching to see why a `try-catch` wouldn't catch an exception that it explicitly has a `catch` arm for.
C++ is not my strong suit (or my favorite thing to work with), so I start to develop a pit in my stomach that there's some weird, nuanced bullshit that I don't understand and will have to learn entirely too much about.

After searching, I found that there were a few options:
- `SysError` in one file is in a different namespace from `SysError` in the other file.
  - Nope, they're both in the `nix` namespace as far as I can tell.
- The `SysError` in one place has different "RTTI" or "run time type information" than the `SysError` in the other place.
  - I didn't know RTTI was a thing.
  - Apparently this can be controlled via compilation flags.
  - I don't _really_ know how Nix is built, I just run `nix build` and watch the computer go brrr.
  - I don't _really_ know how to inspect that.
- The `SysError` in one place can be slightly different than the one in another place due to templating and which constructor is used.
  - Honestly I don't even know if that's correct, but it sounds like a thing C++ would let happen to you.
  - I have thus far avoided learning much at all about templating in C++, but I do have a pretty decent understanding of generics in Rust.
- `SysError` doesn't inherit from `std::exception`.
  - Nope, `SysError` does at some point have `std::exception` as a base class.
- There's a function marked as `noexcept`.
  - Nope, `writeFull` isn't marked with 

# Painting the picture

## The failing test

The test fails because under the hood we are running the following commands:

- `nix store add-file`
  - Put a file into the Nix store, and return its store path.
- `nix build --out-link result-foo <store path>`
  - Run this with the new store path to create a `result-foo` symlink pointing at the new store path.

The `nix store add-file` fails, which causes the `nix build` to fail, and this was partially hidden by the fact that the command was actually run via process substitution:

```bash
$ nix build --outlink result-foo `nix store add-file <path>`
```

The `nix store add-file` fails because under the hood it calls the `LocalStore::addTempRoot` method we've been looking at, which fails with an uncaught exception when attempting to write to a socket that has closed.
The socket is initially available but closes asynchronously during the execution of the `nix store add-file` process.

## Failure timeline

A previous run of the test calls `daemonize nix store delete <path>`.
This creates a `nix store delete` process running in the background.
This process internally does some GC operations, which requires it to obtain the GC lock.

The next test is started while `nix store delete` is still running.
The test goes to `nix store add-file`, which requires creating a temporary GC root.
Since `nix store delete` still has the lock, `nix store add-file` connects to the GC socket to send it the store path it wants a temporary GC root for, but before it can finish doing so, the `nix store delete` process exits, closing the connection.

The `nix store add-file` process gets an error from the `write` syscall because the connection is now closed, which it turns into a `SysError` exception.
This `SysError` exception isn't caught, which kills the `nix store add-file` process.

# Loose ends

One thing that bugs me is that one of the reasons we use `daemonize` is that the `nix store delete` command can sometimes be _very_ slow.
Internally we've seen that on some machines that `nix store delete` command can take >5min to complete, so if you run the test suite many times in succession and run `ps -a | grep 'nix store delete'` you may be surprised to see a bunch of these processes sticking around.

[lldb-forks]: https://github.com/llvm/llvm-project/issues/127952
[tomberek]: https://github.com/tomberek
[nix-team]: https://nixos.org/community/teams/nix/
[gh-gc-global-lock]: https://github.com/NixOS/nix/blob/f22359ba1af6d976d248318aa14e6a6326682f5c/src/libstore/gc.cc#L92
[gh-gc-shared-lock]: https://github.com/NixOS/nix/blob/f22359ba1af6d976d248318aa14e6a6326682f5c/src/libstore/gc.cc#L101
[gh-gc-connect]: https://github.com/NixOS/nix/blob/f22359ba1af6d976d248318aa14e6a6326682f5c/src/libstore/gc.cc#L107
[gh-gc-send-root]: https://github.com/NixOS/nix/blob/f22359ba1af6d976d248318aa14e6a6326682f5c/src/libstore/gc.cc#L130
