+++
title = "Evaluating a process manager"
date = 2024-08-27
description = "I recently went through the process (ha) of picking a process manager and using it as the backend of Flox's alternative to Docker Compose. I learned a few things from that experience and put together a list of questions to consider when picking a process manager for your own projects."
+++

At [Flox](https://flox.dev)[^1] we recently released a feature that we call "service management",
which is essentially an analog to Docker Compose that runs processes instead of containers.
In short, you define some services in your manifest and they get started as part of activating
your environment with `flox activate --start-services`.
When there are no more activations of this environment (i.e. you've closed all your shells that
had activated the environment) the services are **automatically cleaned up**.

A simplified environment that starts a Postgres server looks like this:

```toml
version = 1

[install]
postgres.pkg-path = "postgres"

[services.postgres]
command = "postgres -D my_data_dir"

[options]
systems = ["aarch64-darwin", "x86_64-darwin", "aarch64-linux", "x86_64-linux"]
```

Pretty straightforward, right?
What's not straightforward is wrangling a process manager to bend it to your will
without losing your mind a little bit.
What's the issue?
Race conditions. Race conditions everywhere.
Some of them in how you call the process manager, others inside the process manager itself.

Different process managers will be better or worse at certain tasks,
and some will be missing features that you've decided that you really need.
They may also just do different things because there's not a single correct answer.

As always, choosing one will come down to your particular needs and priorities.
However, the unknown unknowns can make choosing pretty difficult.
Having spent the last couple of months immersed in this,
I've put together a list of topics to consider to help you get your due diligence done.

# Shutdown
- Does it cleanly shut down when requested (e.g. with a built-in command)?
- Does it cleanly shut down when sent a SIGTERM, etc?
- If there is data in-flight (process has shut down, but there are logs yet to be written) during shutdown, is shutdown postponed until that data is persisted, or is it gone forever?

# Starting services
- Can you start a single process?
- Can you start all processes without naming them?
- Can you specify a startup order?
- Can it block until processes have started?
- Is it clear what it means for processes to have started (e.g. the process has been forked vs a readiness check is green)?
- What happens if you try to start a process that's already running (warning? error? success?)
- What happens if you try to start multiple processes and some of them are already running? Do you get individual warnings but still succeed? Do you get an error?
- What happens if you try to start multiple processes and some of them don't exist? Is that a warning, a failure, or success? Do you get individual warnings/errors? Does it check the names beforehand? Does it succeed until it finds a name that doesn't exist?

# Stopping processes
- Can you stop a single process?
- Can you stop all processes without naming them?
- Can you specify a shut down order?
- Can it block until all processes have stopped?
- Is it clear what it means for processes to have stopped (e.g. the process has been sent a SIGTERM vs the process has terminated and is now a zombie vs the process has terminated and been cleaned up)?
- What happens if you try to stop a process that's not running (warning? error? success?)
- What happens if you try to stop multiple processes and some of them aren't already running? Do you get individual warnings and succeed? Do you get an error?
- Does it distinguish between processes that aren't running and processes that don't exist?
- What happens if you try to stop multiple processes and some of them don't exist? Is that a warning, a failure, or success? Do you get individual warnings/errors? Does it check the names beforehand? Does it succeed until it finds a name that doesn't exist?

# Restarting processes
- Can you restart a single process?
- What about dependent processes in the startup order? Shutdown order?
- Can you restart all processes without naming them?
- Can it block until processes have restarted?
- What happens if you try to restart a process that's isn't running (warning? error? starts it?)
- What happens if you try to restart multiple processes and some of them aren't already running? Do you get individual warnings and succeed? Do you get an error?
- What happens if you try to restart multiple processes and some of them don't exist? Is that a warning, a failure, or success? Do you get individual warnings/errors? Does it check the names beforehand? Does it succeed until it finds a name that doesn't exist?

# Backgrounding
- Does it run in the foreground or background by default?
- If it runs in the foreground by default, does it have a way to background it, or do you have to do it manually?

# Client/server (assumes backgrounding)
- Does the server daemonize (re-parent) itself?
- Does it use a Unix socket or TCP?
- If you'll have more than one running, how do you prevent conflicts (ports, socket location, etc).
- If it uses a Unix socket, can you configure or predict its location?
- If a dead socket file is found on startup, is that an error or does it clean it up and create a new one?
- Can multiple clients connect to the same server at the same time? Does that affect data integrity i.e. does each client get a complete set of streaming logs?
- If it shuts down does it wait until all outstanding responses are sent before terminating the server?
- Can you tell whether the server is running without sending it a command?

# Logs
- Are the process manager logs separate from the process logs?
- Are the process logs separate from each other, or in one log stream?
- Can the log format be configured (e.g. human readable, json, etc)
- Can the process manager logs be persisted or only printed to the terminal?
- Can the process logs be persisted or only printed to the terminal?
- Can you stream the logs? Can you stream all processes? Can you stream a single process? Can you stream some but not all processes?
- Can you sample the last few log lines? For all processes? For one? For some but not all?

# Updates
- Can you add or remove processes without restarting the process manager?
- If there's a startup order, does it restart any services when the startup graph changes?

# Statuses
- What information are you given about the processes? Can you see the runtime? PID? Number of restarts? Name?
- Is the list of statuses granular enough? Too granular? Is it clear what the differences are between the statuses?
- What is the status of a process that has never been started? That crashed? That completed? That was terminated via signal? Can you tell what signal? Can you see the exit code?

[^1]: At Flox we're kind of shaking the Etch-A-Sketch on developer environments. Cross-platform, reproducible developer environments without containers so you get the best of both worlds: your tools and dependencies are the same from engineer to engineer, machine to machine, _and_ you get to keep all the tools you love, configured the way you want. But, that's not the point of this post.
