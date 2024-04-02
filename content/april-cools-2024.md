+++
title = "April Cools 2024: Physics Edition"
date = 2024-04-01
description = "Three of the weirdest \"bugs\" I encountered during my PhD."
+++

# Ghost triggers

This particular experiment was driven by a laser that periodically spit out
pulses that were 5ns long.
A photodiode would pick up when a pulse was emitted,
and we'd use that as the trigger for the oscilloscope.
The oscilloscope would then record signals from our two other detectors.
One of these is called "probe" and the other is called "reference".

Here's a block diagram of the system:
![block diagram of the laser system](/images/april-cools-2024/ns-system.png)

Only the beam hitting the probe detector actually passes through the sample.
The beam hitting the reference detector does not pass through the sample,
so any variations in intensity must come from noise in the laser,
vibrations in the table,
etc.
All of these variations should be seen in both the probe and reference beams
since they were produced by splitting a "parent" beam.

We do this so that if you divide the probe signal by the reference signal you
cancel out any part of the signal that doesn't come from the physics happening
inside the sample.
This isn't perfect, but it works well enough.

Imagine you need to run this experiment for about 8 hours in order to get
enough measurements.
Now imagine the oscilloscope is running Windows XP with the tiniest hard drive
known to man.
If you're not a programmer and you don't know that you can drive the experiment
from Python,
and don't know that you can save every measurement individually,
it makes sense that you'd resort to averaging the data in place on the
oscilloscope.

Again, this isn't perfect, but it works well enough.
That is, until one day when you start mysteriously averaging in a garbage
measurement once in a while,
destroying all the data you've just collected.
It looked as if the running average was trying to incorporate a measurement that
was either 0/`<very small number>` or `<anything>`/0.
This wasted hours of time when it happend, but at least the squiggly line on the
screen looked cool.

We try all the obvious things,
then we all give up and the new guys in the lab (me and someone else) decide to
just sit and watch the experiment run in hopes of witnessing the failure.
We wait, and we wait.
No failure.

Until someone unplugs their phone charger from the wall.
The fuck?
We plug the charger back in and unplug it,
just to make sure that the insane thing we're seeing is reproducibly insane.
Yup, it's reproducibly insane.

It turned out that a large amount of electrical interference was emitted every
time a phone charger was unplugged from the wall (although not from Apple iPhone
chargers, take from that what you will).
Electrical interference is always floating through the air,
like it or not,
but electrical engineers and physicists (mostly) know about this.
To protect our equipment from interference we "shield" it,
which really just means we wrap it in metal.

Guess what,
the photodiode we were using to pick up the laser pulse wasn't shielded very
well.
One might even say that the shielding was absolute dogshit.
Couple that with a very old, very crappy cable connecting it to the oscillscope
and you have yourself what is basically an antenna.

Whenever this photodiode or cable would pick up interference,
it would like to the oscilloscope as if a laser pulse had just arrived.
It would then trigger a measurement,
even though there was no laser beam present.
This is where the 0/`<very small number>` or `<anything>`/0 came from.

# Ok, I guess I have to worry about that now

I was working on an experiment that used a never-before-seen measurement
technique.
The laser system itself was incredibly sensitive and used 20fs pulses
(a femtosecond is 10^-15 seconds).
I'm pretty sure it was the most sensitive device of its kind in the world by
1 or 2 orders of magnitude.
I was pretty proud of it.

However, when you have a device that's incredibly sensitive,
you start to pick up effects that are well below the noise floor of other
measurement techniques.
This will become relevant.

Here's a diagram of the system from my thesis:
![diagram of the laser system](/images/april-cools-2024/mhz_layout.png)

A few things to point out here:
- Yes, I did make this diagram in LaTeX.
- Yes, of course there are LaTeX packages for drawing optical layouts.
- Yes, I am insane.
- Yes, I'm one of the only people to ask about [how to draw an off-axis parabolic mirror](https://tex.stackexchange.com/questions/204266/drawing-an-off-axis-parabolic-mirror-in-pst-optexp-and-pst-optic) in LaTeX.
- This diagram is meant for physicists, the only thing you need to see is that
  there's a 950kHz "AOM" and a 50kHZ "PEM".

The way this experiment works is that you have two laser beams that intersect
in the sample.
One of them is called the "probe",
and one of them is called the "pump".
In short, the pump excites the sample,
and the probe comes by some time later to see how things have evolved after some
period of time.

In this case we're modulating each beam at some frequency,
50kHz for the probe (modulating the polarization),
950kHz for the pump (modulating the intensity).
Why?
Well, when these beams interact in the sample,
the physics we're trying to observe happens at the sum of these two frequencies,
which in this case is 1MHz.

We use a special instrument called a "lock-in amplifier" to only detect a signal
at 1MHz,
which eleminates all the noise present at other frequencies.
It's incredibly effective...when you don't have other sources noise at 1MHz.

I had to put together a rats nest of electronics to make sure that my two signals,
50kHZ and 950kHz,
never got mixed together except for the exact place that I wanted them mixed.
You can see that box here:
![a bunch of ugly electronics](/images/april-cools-2024/mhz-modulator.jpeg)

Note the "LOL" spelled out in gaffer tape.
I put that there for whoever the next student was because I intended to never
open this box again,
and good luck to whoever had to open this box and play with it.
The joke was on me, clearly.

Again, this device is incredibly sensitive,
and one day I'm completely stuck trying to figure out where a source of 1MHz
noise was coming from.
My electronics are isolated extremely well.
My lasers are modulated extremely well.
There's no 1MHz electrical interference in the lab.
What the hell is going on?

I mentioned above that we used two devices,
an "AOM" and a "PEM",
to modulate each beam.
An "AOM" is an "acousto-optic modulator",
and it modulates the intensity of a laser passing through it.
It takes an incoming electric signal (my 950kHz signal, in this case)
and uses it to essentially vibrate a piece of glass in a special way.
A "PEM" is a "photo-elastic modulator",
and it modulates the polarizating of a laser passing through it.
It also takes an incoming electrical signal (my 50kHz signal, in this case)
and uses it to essentially vibrate a piece of glass in different but also
special way.

You'll notice that these devices both work by vibrating glass.
Long story short,
it turned out that ultrasonic vibrations from the PEM were floating through the
air in the system and vibrating the glass in the AOM.
The 50kHz ultrasonic vibrations picked up in the AOM were mixed together with
the 950kHz vibrations that the AOM was correctly producing,
producing a 1MHz signal.

I was absolutely floored.
Normally when you work with lasers you don't have to worry about sound.
Like, ever.
Lasers are light, they don't typically care about sound.
Everyone who has done a PhD has thing kind of moment where you think to yourself,
"sure, I'll just add this to the pile of bullshit that I didn't know I needed to
worry about."

The solution was to simply put a glass plate on either side of the PEM in order
to contain the ultrasonic vibrations it was producing.
You can see that in this photo, also held together with gaffer tape:
![arts and crafts with physics](/images/april-cools-2024/mhz-system.jpeg)

# My shirt is the bug

I was working on another experiment that used yet another very sensitive
measurement technique.
The photodiode I was using in this case was tuned to have very good time resolution
and frequency response under low-light conditions.
This photodiode and this measurement technique were both very sensitive to stray
light,
so we built a little box out of plexiglass and covered it in matte-black
aluminum foil (yes, that exists) to block out all of the stray light.

The back of the box wasn't made out of plexiglass.
This was necessary for practical reasons, namely that I frequently needed to
get inside the box and tweak the optics around the photodiode.
To cover the back of the box during an experiment we simply draped a black
blanket over it.
This worked shockingly well.

At some point I'm debugging an issue with the system.
I notice that there's a huge spike in the data right around when a laser
pulse arrives,
but this is a separate laser than what the photodiode is supposed to detect,
and it's not pointed at the photodiode.
This tells me that somehow all the mechanisms I'm using to protect the
photodiode against stray light aren't quite working.

I spend _a lot_ of time working on this.
At one point I'm running the system in real time,
and I'm watching the signals on the oscilloscope so I can see how the system
responds when I block light in various places.
Then I notice that this "bad" signal changes depending on where I'm standing.

What. the. fuck.

I start to have PTSD flashbacks to the "lasers vs. sound" incident.
I question my life choices.
How can this be possible?
Is there some kind of radio frequency interference that's blocked when I stand
next to the experiment?


Let's talk about where stray light comes from.
Well, one source is the overhead lights.
Another source is the air.
Yup.
The lasers we're using in this experiment are very, very intense,
and as the light travels through the air some amount of it will literally
bounce off of the molecules that make up the air,
sending that light in a completely random direction.
That light continues to bounce off whatever else is in the room.

Like me.

It turned out that there was two issues.
I had already solved the real issue.
The other issue,
the one that seemed to depend on where I stood,
was only present when I was debugging the first issue.

It so happens that this blanket that was draped over the back of the box during
experiments was pulled up slightly while I was diagnosing the real issue.
And since it was pulled up,
stray light could get in the back of the box.
Stray light like the random photons bouncing off of molecules in the air,
which then bounce around like pinballs until they eventually bounce off my shirt
and into the back of the box,
even though this beam is originally pointed in the opposite direction.

Sigh.
