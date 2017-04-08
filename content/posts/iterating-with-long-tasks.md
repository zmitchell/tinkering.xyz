+++
date = "2017-02-20"
title = "Iterating with Long-Running Tasks"
tags = [
    "tmux",
    "docker",
    "logging"
]
description = "It turns out I'm a noob"
+++

## The Problem
One of the reasons that I bought a separate development machine was the friction surrounding tasks that take a long time to run on a Raspberry Pi. For a home automation related project I had to compile the `openzwave` library on the Pi, and for another project in the works I had to compile `opencv` on the Pi. Both of those tasks take hours to complete. Both projects were being built inside Docker containers, so modifying the Dockerfile to fix a bug would trigger a complete rebuild of the image. To make matters worse, I wasn't saving the output of the build script to a file. Since I wasn't logging the output of the build process, I had to have a persistent connection to the Pi (via `ssh`) in order to see the error message if the build failed. In order to keep that connection open I had to prevent my Macbook Pro from sleeping, and press a button every now and then. If I had to go somewhere in the middle of a build, I would have to start that process all over again. Here's what this process looks like in a nutshell.  

1. Identify a bug
2. Attempt to fix the bug by modifying the Dockerfile
3. Start the build process
4. Keep the `ssh` connection open at all costs
5. Wait a few hours for the build to fail
6. If at any point the connection closes, go back to step 3
7. Repeat until the build completes  

  
Needless to say, this process is rage-inducing. Making incremental improvements takes forever, and is really demoralizing. Thankfully, there are some really basic solutions I've found to make life easier.

## Solutions
The one thing that would make my sob story above less painful would have been the ability to view the output of the build script after the build completed, or to at least be able to see the build progress without the need for a persistent connection to the Pi. I've found two easy solutions to this that probably won't be a surprise to anyone who programs for a living.

### Using `tmux`
`tmux` eliminates the need for a persistent connection to the Pi. In a nutshell, `tmux` allows you to start a terminal session on the host machine that will continue to run regardless of whether you're still connected to the machine. In other words, I can start the build process in a `tmux` session, close the connection to the Pi, and the next time I open a connection to the Pi I'll be able to see the current progress of the build in the `tmux` session that's still running.

This is great if I want to see the progress of the build as it's running, but it doesn't solve the problem of being able to review the build log after the build fails.

### Using Redirects
I've known about redirects for a while, but for some reason I never thought to use it to capture the output of the build.

```bash
$ bash build.sh > build-log.txt
```

The command above will redirect `stdout` to `build-log.txt`. If I want to capture errors as well, I need to redirect `stderr` to `stdout`.

```bash
$ bash build.sh 1> build-log.txt 2>&1
```

In that command `1` is the identifier for `stdout`, `2` is the identifier for `stderr`, and `&1` is the way that you reference a stream when you're redirecting **to** a stream. In short, the command tells `bash` to run my script, redirect `stdout` to a file, and redirect `stderr` to whatever `stdout` is pointed at (the same file as before).

## Conclusion
I think the thing that I took away from this was that I needed to do a better job thinking about looking for standard solutions to my problems. If I run into a problem, there's a very, very good chance that someone else out there has run into the same problem before. On the other hand, I already knew how to use redirects, so I just didn't think hard enough about how to use the tools at my disposal.
