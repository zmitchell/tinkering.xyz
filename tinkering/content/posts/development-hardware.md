+++
date = "2017-02-14"
title = "Development Hardware for a Steal"
tags = [
    "hardware"
]
+++

Yes, this is posted on Valentine's Day, but my wife is out of town so I have nothing better to do.

# Motivation
I do all of my programming on my Macbook Pro, but which hardware the code runs on varies. I have a Raspberry Pi 3, a desktop running Windows that’s attached to a Drobo, and my Macbook Pro. Windows isn't *nix based and has no built-in package manager (neither does macOS, but at least it's Unix based), so there's more friction than I would like with regards to programming on Windows. Most of the programming I’ve done for the Pi has involved developing Docker containers with dependencies that must be built from source. This is rage inducing for a number of reasons:  

- Compiling anything from source on a Pi is glacially slow.
- I connect to the Pi via `ssh`, which means that I don’t see any error messages if the connection is interrupted while Docker is building an image.
- I haven’t found a way to have Docker save the output of the build process so that I can look at it later.  

  
All of that is to say that I have to be connected to the Pi throughout the entire multi-hour long build process if I want to see the error message at the end. What if I start the build process at work and need to go home while it’s still building? I decided that I wanted to spend more time programming and less time [yak shaving][yak-shaving], so I started looking at what kind of computer I could get for what kind of money.

# The Search
The first thing I did was pick a bunch of new parts on Newegg and see how much it came out to. For a Skylake i5 processor, some DDR4 RAM, a small SSD, and some mini-ITX parts the build came out to about $500. I didn’t want to spend that much on a computer that would only be marginally faster than my current desktop, so I started looking around on eBay.

I eventually discovered that you can buy used servers on eBay for $200-$300. When you consider that the available servers typically come with two processors, each of which is either 4-core or 6-core, and somewhere in the range of 16GB-48GB of RAM, an old server becomes a pretty enticing option with regards to bang for your buck.

The first thing I realized while browsing used servers on eBay was that I had no idea what I was looking at. I, like lots of other nerds, have built my own desktop from scratch, but that did basically nothing to educate me about server hardware. After poking around on the internet for a little while I found [/r/homelab][homelab], which is a subreddit for people who want to build their own quasi-enterprise-level computer lab at home. The wiki there has a bunch of information about which servers to buy, which to avoid, etc. More importantly, it provides a warning about the downsides of these servers. 

Most of these servers are several years old, so their processors haven’t reaped benefits from recent advancements in power efficiency. These servers were also designed to keep their internals cool in an environment where you have lots of heat-producing hardware running at full-bore while stuffed in a small box next to a bunch of other small boxes that are also spewing heat. Needless to say, you need a lot of beefy fans to keep things cool in that kind of environment. This means that some servers sound like small jets taking off. Another issue is that the hard drives used in servers are typically not the same hard drives that you would find in a desktop computer. Server hard drives use [SAS][sas-wikipedia] rather than [SATA][sata-wikipedia], and typically spin at 10k-15k RPM compared to 5.4k-7.2k like consumer hard drives. The read/write speed of a hard drive increases with the rate at which the disk spins, but the power consumption increases as well.

On top of that, some of the processors that you'll find in these servers don't have support for Intel's AES-NI instructions (see [here][aesni-wikipedia] and [here][aesni-explanation]), which provide hardware acceleration for certain encryption related tasks. Just to be clear, you can still do encryption related tasks with processors that don't support the AES-NI instruction set, it will just be much faster on processors that **do** support the AES-NI instruction set.

Put all of that together and you have older, less efficient processors, a bunch of loud fans running at full speed all the time, and a bunch of hard drives that consume more power than your average consumer hard drive. The power consumption of a server like this can be anywhere from 140W-175W **at idle**, but as high as 250W at full load. I did a quick calculation based on the cost of electricity from my last electric bill, and a server consuming 140W at idle would cost about $15/month in electricity alone. That’s $180/year, which is a considerable fraction of the cost of the server itself. With that in mind, I decided to see what else I could get for a similar amount of money.

# What I Bought
I eventually found some workstations built around Xeon E5-2660/E5-2670 processors, which are slightly newer 8-core server processors with performance only slightly lower than that of the fastest servers that I was looking at before. The workstations only come with 1 processor, but the motherboards support up to 2 processors. The ability to add another processor means that at some point in the future I can waste a bunch of money on even more excessive processing power. In the end I spent $400 for a Dell Precision T3600 with an E5-2660 and a 256GB SSD.

In the near future I’ll be installing a [hypervisor][hypervisor-wikipedia] and playing around with a bunch of virtual machines.

[yak-shaving]: https://en.wiktionary.org/wiki/yak_shaving
[homelab]: https://www.reddit.com/r/homelab/
[sas-wikipedia]: https://en.wikipedia.org/wiki/Serial_Attached_SCSI
[sata-wikipedia]: https://en.wikipedia.org/wiki/Serial_ATA
[aesni-wikipedia]: https://en.wikipedia.org/wiki/AES_instruction_set
[aesni-explanation]: http://crypto.stackexchange.com/questions/19544/how-exactly-does-aes-ni-work
[hypervisor-wikipedia]: https://en.wikipedia.org/wiki/Hypervisor
