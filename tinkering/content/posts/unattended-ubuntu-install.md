+++
date = "2017-02-19"
title = "Attempting an Unattended Ubuntu Installation"
tags = [
    "failed",
    "ubuntu"
]
+++

# Motivation
In a [recent post][hardware-post] I mentioned that I bought a new development machine. The computer didn't come with a graphics card or an operating system, which was fine with me since I was going to install Ubuntu Server on it anyway. I bought a cheap graphics card (~$25) to go with the computer, even though it would be a headless installation, since I would still need a way to connect the computer to a monitor if I wanted to tweak any BIOS settings. Well, I was dumb and bought a graphics card with a low-profile mounting bracket by accident when the computer needs a full-sized mounting bracket, so my graphics card doesn't fit. 

After looking around for the mounting bracket online, it looks like my options are to buy the correct bracket on eBay from a seller in China, buy the same model graphics card with the correct bracket, or buy a new graphics card entirely. I decided that I wasn't going to wait a month for the $7 bracket to arrive from China, so that option was out. From perusing Newegg, I found that I could get a substantially better graphics card for only a little bit more money, so I went that route. That card won't get here for a few days, but I don't want to wait that long to play with my new toy.

During a typical Ubuntu installation process the installer asks you a few questions such as what to name the main user, what that user's password should be, what timezone to use, etc, and will wait patiently until you provide answers. Since there's no way for me connect a monitor to the computer at the moment, I have no way of seeing or responding to the installer's questions. What I need is an installer that won't stop and wait for me to answer its questions. This is called an "unattended install."

# Ubuntu Unattended Install Options
I found a few AskUbuntu posts ([here][askubuntu1] and [here][askubuntu2]), but the processes detailed in those posts seemed hairier than I wanted to deal with, so I kept looking around. There's also some [documentation][canonical-docs] from Canonical themselves about how to do this, but again this seemed more complicated than what I was looking for. At that point I was wondering whether a simple solution even existed, but eventually I stumbled onto [netson/ubuntu-unattended][github-repo]. This repository provides some scripts that will download the image for the Ubuntu Server image you want, ask you some questions, do some magic, and spit out an image that will do an unattended install. Hell. Yes.

# Speed Bumps

### Requires Ubuntu/Debian to Run
The first issue I ran into was that you need Ubuntu/Debian in order to run this. My main computer is a Macbook Pro, but luckily I have a Raspberry Pi 3 that my home automation server runs on (I'll write about this at some point in the future). The Pi is running Raspbian, which is a version of Debian tweaked for the Raspberry Pi, so I lucked out there.

### Timezones
I was a little confused about the format used for time zones. I see formats like `UTC` and `EST`, but I also see `America/New_York`. I wasn't sure which one was expected, so I just picked `EST` and hoped for the best. Nothing has exploded yet, so I guess it worked.

### Broken Download Link
After asking you some questions the script will attempt to download the selected Ubuntu Server image. Well, the link in the script is broken, so you have to download the image manually ([link][ubuntu-image]) and stick it in `/tmp/`. The script was written such that Ubuntu Server 16.04.1 is the most recent version, so rather than messing with the script to figure out if it would work with the 16.04.2 (current at the time of writing), I just found the link for 16.04.1. I plan to install 16.04.1 and update to 16.04.2 immediately after the install.

### Missing `isohybrid`
After downloading the image and putting it in the specified location, the script attempts to do its magic on the image that will let it run unattended. In my case, it gave me an error message saying that `isohybrid` wasn't found, but also told me that it finished. From the terminal output alone I'm not sure if that means it found a way around whatever problem it ran into, or if it "successfully" made an image that's broken due to the missing dependency. Since this is supposed to run unattended, I'll have no way of knowing if the installation fails until I boot from the image and let it do its thing. I'd rather know that the image is valid before trying to boot from it.

I tried looking around to find the package that contains the `isohybrid` command, and it looks like it's supposed to be in the `syslinux-utils` package. Well, `apt-cache search` returned no results for `syslinux-utils`, so I tried `syslinux`, `syslinux-common`, `isolinux`, and `xorriso`, but none of them worked. From what I can tell, there's just not an `isohybrid` package for `armhf` (Raspberry Pi), so that put the nail in the coffin of this idea. You can download the source for the `syslinux` package, but compiling anything from source on a Pi is glacially slow, so I decided against that. You could probably do it in a pinch, but I didn't have the patience for it.

# What I Ended Up Doing
In the end, I made a bootable USB with the Ubuntu Server installer on it and plugged the SSD from my development machine into my Windows desktop machine. From there I did the typical installation process, and then put the SSD back into my development machine. By the time I string up another ethernet cable across the ceiling of my apartment to connect my development machine to my router, my graphics card will probably be here. I ended spending about a day doing this, and I could have spent a lot less time if I just waited for the graphics card, but quick and painless just isn't the Tinkering way.

[hardware-post]: /posts/development-hardware/
[askubuntu1]: http://askubuntu.com/questions/122505/how-do-i-create-a-completely-unattended-install-of-ubuntu
[askubuntu2]: http://askubuntu.com/questions/806820/how-do-i-create-a-completely-unattended-install-of-ubuntu-desktop-16-04-1-lts
[canonical-docs]: https://help.ubuntu.com/16.04/installation-guide/i386/ch04s06.html
[github-repo]: https://github.com/netson/ubuntu-unattended
[ubuntu-image]: http://old-releases.ubuntu.com/releases/xenial/ubuntu-16.04.1-server-amd64.iso
