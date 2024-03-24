+++
title = "How I finally installed NixOS"
date = 2024-03-24
description = "...or, how `disko-install` is what I thought `nixos-install` would be. I've been in the Nix world for about a year now, I work at a company that uses Nix daily, and it was only last week that I finally installed NixOS on the PC that I've been meaning to install it on for close to a year. Why? What kept me from installing it for so long? What was the breakthrough?"
+++

I've been in the [Nix](https://nixos.org) world for about a year now,
I work [at a company](https://flox.dev) that uses Nix daily,
and it was only last week that I finally installed NixOS on the PC that I've
been meaning to install it on for close to a year.
Why? 
What kept me from installing it for so long?
What was the breakthrough?

# The motivation

Every time I get a new machine there's a feeling of dread that now I have to
(try) to set it up from scratch.
I have ADHD and this is the kind of tedious task that makes my brain melt.
The process typically goes like this:
- Run `brew list` or something like that in order to get a list of packages I
  have installed.
- Prune that list to remove things that I installed because I needed them for
  one time use and later forgot about.
- Run `brew install`, `apt install`, etc to install that list of packages.
- Discover that package names are different across OS, distribution, etc.
- Discover that some packages just don't exist on the new OS, distribution, etc.
- A month later, discover that some application I need wasn't in that original
  list because I installed it through some other mechanism.

Barf.

Fast forward and Nix pops up on my radar.
I can configure the entire operating system declaratively?
Yes please.

# Requirements
My main machine is an M1 Macbook Pro,
and it's a personal machine,
so I've installed all kinds of stuff on it.
I don't see myself switching to Linux as my work machine any time soon,
though I've been a Linux user in one form or another for over a decade.

I have a desktop that's a fire-breathing monster of a machine with 32GB of RAM,
a 16-core/32-thread CPU,
an RTX 4090 GPU,
and a full custom water cooling loop.
It's pretty nice.
Right now it's just my gaming PC,
but there's a second SSD in there that's been empty since I built it because
I intended to put NixOS on it.

My one, major requirement was that I should be able to take my NixOS config
and run one or two commands to set up the entire machine.
I don't want to be involved in the process, just do it automatically.

In the spirit of "we can have nice things",
I also decided that I wanted this machine to use ZFS as the filesystem.
But again, I didn't want to manually type out the partitioning commands.
This is NixOS, everything is supposed to be declarative, right?

I learned about a Nix project called
[disko](https://github.com/nix-community/disko)
that allows you to declaratively configure your filesystem.
The docs were terse and not terribly beginner-to-Nix friendly,
but there were example configurations that you could copy and modify,
including one for ZFS.

# Attempt #1

Ok, I lied a little bit,
I wasn't set on ZFS from the outset,
so my first attempt was just running the "minimal" installer available from the
NixOS website.
I ran into a couple of problems.

First, the installer at the time didn't include drivers for my WiFi chip.
I think those drivers have since been added to the Linux kernel,
so they don't need to be added separately.

I followed the installation instructions meticulously because I already had the
Windows side of the machine set up and didn't want to accidentally nuke it.
Fast forward, I've done the partitioning,
I've done some minimal configuration so I have a few familiar programs after
the install,
and it's finally time to run `nixos-install`.

The text scrolls by as the installer runs,
and..."something something bad sector".
The fucking flash drive is corrupted.

I was a little burnt out at the time
(working on the Nix Docs Team, speaking at NixCon, speaking at RustConf),
so finding the time and summoning the energy to spend on this was hard enough.
This killed that energy, especially since I had a startup cost of running
an ethernet cable across my house to even attempt it again.

At that point I resolved to try things in a VM first.

# Attempt #2

After talking with a [coworker](https://github.com/bryanhonof),
I learned that you can make yourself a custom installer that includes all the
software specified in your config.
If I can include the options for my WiFi chip,
I should be able to run the install without an ethernet cable.
I used the [nixos-generators](https://github.com/nix-community/nixos-generators)
tool to build an ISO image out of my config so that I could use that instead of
the official "minimal" installer.

Time found and energy summoned,
I took my ISO image and ran the installation in a VM.
I go to run the `disko` scripts to apply my filesystem config.
The scripts aren't there.
wat?

Digging through the `disko` source was a little bit above my pay grade at that
point because I didn't have any experience with the NixOS module system.
I ask another [coworker](https://github.com/tomberek),
he makes some suggestions and points out a couple of bugs in my config.
Sure, I don't know what I'm doing yet.

I go to run the install again and I'm still getting these errors.
At this point I give up on `disko` for the time being and just install NixOS
on ext4 using the manual installation instructions.
This reduces the surface area of what I possibly could have messed up.
I'd rather get the rest of the config in a known working state,
and then add on the `disko` stuff.

I played around with this VM and got a basic config working.

# Attempt #3

I had been wanting to get back into playing Elden Ring for a while,
but when I'm constantly getting my ass kicked I'd like to slouch a little bit.
This is my roundabout way of saying that I wanted to set up game streaming from
my desktop to a small machine in my living room.

I bought an Intel NUC and installed my NixOS config on it,
again using the manual partitioning instructions for ext4.
Life's too short to let ZFS get in the way of Elden Ring.

This went off without a hitch,
so technically this is the first time I successfully install NixOS on hardware.
However, I'm still running partitioning commands manually and I'm still not
using ZFS.

I did buy a new flash drive just for this.

# SCaLE 21x and NixCon North America 2024

I was one of the organizers for
[NixCon North America 2024](https://2024-na.nixcon.org/),
mainly in charge of creating the program.
One of my [co-organizers](https://github.com/djacu) submitted a workshop on
essentially exactly what I was trying to do: NixOS on ZFS using `disko` for the
filesystem config.
We decided it would be better for the wider audience if he did a workshop on the
NixOS module system instead.

Fast forward to NixCon NA and we get to talking about the holy grail again:
NixOS on ZFS without manual partitioning.

# Attempt #4

I took a couple of days off work after NixCon NA and SCaLE.
Motived by conversations at those conferences,
I start looking at the `disko` docs again and notice that there's a new command:
`disko-install`.
This was [added on March 1st](https://github.com/nix-community/disko/pull/548),
and it claims to be a combination of `disko` and `nixos-install`.
Could it be?
The one that was promised?
The chosen one?

I ignore responsibilities to find some time, I dig deep to summon my courage,
I dash across the house with the ethernet cable,
and I fumble to get the flash drive plugged into my desktop.
I run `disko-install`.

It works on the first try!
We did it!

# Meet `chungus`

My laptop is a 16" Macbook Pro M1 Max.
It's not a small laptop.
For this reason I named it `chonker`.

At [Flox](https://flox.dev) we do demo days on Thursday mornings.
This is a fun way to show your coworkers what you've completed in the last
sprint,
or simply show something you've been working on at work or otherwise.

My demos have become somewhat notorious for two reasons:
- Given a captive audience I will talk indefinitely.
- Every demo starts with `chonker $`.

We have an internal chat bot called Goldiflox that,
among other things,
keeps "karma" scores and "facts".
`chonker` and my demos have left their mark even in the company chat bot.

![Demo day order showing chonker instead of my name](/images/installing-nixos/chonker-demo-order.png)

![Slack chat showing someone increasing chonker's karma, and the chat bot telling someone else that a "Zach demo" is 20 minutes long](/images/installing-nixos/chonker-karma.png)

So, when it came time to name my desktop,
I needed a name that invoked something even bigger than a chonk.

Meet `chungus`.

![neofetch run on chungus](/images/installing-nixos/chungus-neofetch.png)
![A photo of chungus's hardware](/images/installing-nixos/chungus.jpeg)

# What's next?

You'll notice I didn't post any screenshots of `chungus`'s desktop.
That's because I've decided I'm going to roll my own desktop environment using
Hyprland and a variety of other Wayland applications.
I did get a basic Gnome desktop set up just to make sure everything was working
properly,
but now that I have a NixOS machine I can tinker on,
I'm going to _tinker_.
