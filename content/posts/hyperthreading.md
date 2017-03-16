+++
date = "2017-02-17"
title = "How Hyperthreading Works ... I Think"
tags = [
    "threading",
    "hardware"
]
description = "In which I pretend to know what I'm talking about"
+++

**tl;dr** - A hyperthreading-enabled processor reports to the operating system that it is actually two separate processors so that the CPU assumes the responsibility of deciding when it should schedule work to be done on multiple jobs running at the same time. The CPU is much more efficient than the operating system at this decision making process, which allows it to better manage its time and resources. In some cases this results in doubled performance, but in others it doesn’t increase performance at all. The type of work being done by the processor is a large deciding factor in whether hyperthreading increases performance.

In my last post I talked about buying a development machine. Since I'll be doing a lot of compiling on this machine the particular CPU installed was one of the details I focused on most. Some of the available processors offered what Intel calls "Hyperthreading" (HT). This is something that Intel still uses today. In broad strokes, Intel's desktop processor lineup looks like this:  

- i3 - 2 cores with HT
- i5 - 4 cores without HT
- i7 - 4 or more cores with HT  

  
While doing some research on this topic I found an [article](http://www.sheepguardingllama.com/2008/03/cpus-cores-and-threads-how-many-processors-do-i-have/) that clarifies the distinction between a CPU, a processor, and a core. The article is nearly 10 years old at this point, but I learned a few things and found it to still be relevant. 

Let's get back to the discussion of HT. A processor with `N` physical processor cores supports `N` threads without HT, or `2N` threads with HT. A CPU [thread](https://arstechnica.com/business/2011/04/ask-ars-what-is-a-cpu-thread/) is basically a pipeline of instructions that are fed to the CPU.  Intel's [product pages](https://ark.intel.com/m/products/65719/Intel-Core-i7-3770-Processor-8M-Cache-up-to-3_90-GHz) are pretty informative, and report the number of threads supported by a given processor. In some places I've seen threads called "logical cores" or “logical processors.” In that case a CPU without HT has the same number of logical and physical processor cores, but a CPU that supports HT has twice as many logical cores as physical cores.

Let’s tie this back to my original question about code compilation. GNU `make` allows you to pass it an argument telling it how many parallel jobs to spawn. For example, the following code would allow 4 different jobs to run in parallel during compilation.

```bash
$ make -j4
```

The documentation for `make` tells you to set the argument of the `-j` flag to the number of processors. The question then becomes whether "processor" means physical processor cores or logical processors (CPU threads).

It turns out I'm not the first person to ask this question (go figure). In [this](http://stackoverflow.com/questions/2499070/gnu-make-should-the-number-of-jobs-equal-the-number-of-cpu-cores-in-a-system) Stack Overflow post someone asks basically the same question. One of the responders posts compilation times done on a 4-core processor with HT and a variety of parallel job counts.  Before reading about what HT actually is or how it works, I assumed that a CPU that supported HT would be able to do twice as much work as a non-HT CPU since the HT CPU supported two execution threads per physical processor as opposed to a single execution thread per processor in a non-HT CPU. That assumption turns out not to be true.

Looking at the compilation times in that SO post, there is a big difference in compilation time going from 1-4 jobs (148s vs 59s), a very small difference from 4-8 jobs (59s vs 54s), and basically no difference with more than 8 jobs.

Regardless of HT, it makes sense that you would see a big speed up going from 1 to 4 jobs since at the very least you have 4 physical processors available to work independently. On the other hand, if the number of execution threads is the bottleneck then you would expect a much bigger speed up than what the poster reported going from 4 to 8 jobs. To understand the discrepancy we have to dig in to the details of how a processor works. I'm by no means an expert on this topic, so I'm sure that I'm glossing over very important details, but I've tried to explain the following in an accessible way. 

Everything related to feeding instructions to a processor is highly optimized to prevent the processor from having to wait around for instructions. If we think about feeding instructions to the processor through a pipeline, the processor gets the most done when that pipeline is full and the instructions are related to the same thing. The operating system (OS) sees that there is a job that needs to be done, and passes the relevant instructions through the pipeline to the processor.

Now let's complicate matters by saying that there are two jobs that need to be done and they have equal priorities. In the case of a single processor without HT, the OS flips back and forth between telling the processor to work on job 1 and job 2, and each time it does so the processor has to change gears. Clearly this is not the most efficient use of the processor's time, and letting the OS tie itself up trying to figure out which of the two jobs to tell the processor to work on probably isn't doing us any favors.

Enter hyperthreading. According to [this article](https://www.percona.com/blog/2015/01/15/hyper-threading-double-cpu-throughput/), a processor with HT assumes the responsibility of deciding when to work on which job by essentially faking out the OS. A processor with HT has two instruction pipelines per processor, rather than one, and it fakes out the OS by telling it that each instruction pipeline is a separate processor. Now when the OS has two jobs of equal priority it doesn't have to think about when to work on one or the other, it just hands one job to one "processor" and the other job to the other "processor" and lets them get on with it.

At this point you might be wondering what that accomplishes. Both with or without HT something is deciding when the processor should work on job 1 or job 2. In one case it's the OS, and in the other case it's the processor. The answer lies in the fact that everything gets faster as you get closer to the CPU. Letting the CPU decide which of its instruction pipelines to churn through is much more efficient than letting the OS call the shots. Think of it as walking down to your manager's office to ask a question as opposed to trying to get a meeting with the CEO.

Now we can tie this back to our code compilation and the reason that you sometimes only see a modest speed improvement with HT. A processor with HT doesn't behave like two complete, separate processors. True, there are two separate pipelines of instructions for the CPU, but you still only have a single CPU and you're limited by how fast it process a single instruction. Compared to a processor without HT, a processor with HT is better at managing its time and resources, but at the end of the day it's still just a single processor. 

However, one thing I’ve completely ignored up to this point is the type of work the CPU is doing. Some work is well-suited to being parallelized, whereas other work doesn’t see any benefit. It seems to me that the most important aspect of this is where the bottleneck lies. [This](http://superuser.com/a/279803) SO post discusses this bottleneck effect. The poster runs a variety of algorithms on a HT-enabled CPU, and reports the speedup as a function of the number of threads. For two of the algorithms you see a linear increase all the way up to the maximum number of threads, whereas two other algorithms top out at the number of physical processors. The algorithms that scale with the number of threads are bottlenecked by something other than the processor, which means that the processor can work on one job while the other job is waiting for whatever external resources are causing the bottleneck. The other two algorithms are limited strictly by the CPU, so the ability to put one job on hold while working on the other doesn't provide any benefits.

 One thing to keep in mind with that post is that it reports the speedup relative to a single thread running the same algorithm. In other words, it doesn’t tell you anything about whether one algorithm is faster than another on a single thread, or whether HT makes one algorithm faster than another. 

To wrap up, a hyperthreading-enabled processor reports that it is actually two separate processors to the operating system so that the CPU assumes the responsibility of deciding when it should schedule work to be done on multiple jobs running at the same time. The CPU is much more efficient than the operating system at this decision making process, which allows it to better manage its time and resources. In some cases this results in doubled performance, but in others it doesn’t increase performance at all. The type of work being done by the processor is a large deciding factor in whether hyperthreading increases performance.
