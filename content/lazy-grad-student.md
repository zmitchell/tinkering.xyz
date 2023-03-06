+++
title = "Using notifiers to give yourself the day off"
date = 2020-11-12
draft = false
description = "When you're running experiments that take ~8 hours wouldn't it be nice if the experiment told you when it was done rather than needing babysitting? In this post I'll show you how I used Twilio to do just that."
+++

In keeping with the title, this will be a short post.

The experiments that I do take roughly 2 hours each. The program that runs the experiments is written in Python and uses the [click][click] module for the command line interface. `click` provides an easy to use [progress bar][progressbar], so I have some visual indicator of how the experiment is progressing and some estimate of when it will complete.

If I know roughly how long the experiment is going to take, that means I can walk away while the experiment runs, right? Well, no. My samples degrade with increased laser exposure, so I'd like to minimize the time spent blasting my sample while not collecting data. However, I don't really want to sit in front of the computer the whole time or get up to check on the experiment every 5 minutes. What is a lazy grad student to do?

Enter the [notifiers][notifiers] module.

## Notifiers
The `notifiers` module is a front-end for providing alerts through a variety of channels e.g. email, chat services, sms, etc. I'm chronically attached to my phone, so a text message is likely to catch my attention. Fortunately, `notifiers` has a Twilio integration.

Getting started with Twilio is pretty easy. After creating an account I was given a bunch of trial credit (~$15). Sending a text message with Twilio costs $0.0075, so you can send ~133 messages for $1. If I run enough experiments to blow through my trial credit, something has gone terribly wrong with my PhD. I also needed to create a Twilio number, which is the number that the text messages will be coming from. This costs $1/month, which is in my budget even as a grad student.

Sending a notification (text message in this case) is as easy as calling the `notify()` function for whatever notification provider you're interested in. You can also set some of the arguments to the `notify()` call via environment variables so that you don't have to store your account details and phone numbers in git for the world to see.
```
NOTIFIERS_TWILIO_ACCOUNT_SID="my_account_sid"
NOTIFIERS_TWILIO_AUTH_TOKEN="my_auth_token"
NOTIFIERS_TWILIO_TO="my_phone_number"
NOTIFIERS_TWILIO_FROM="my_twilio_number"
```

At this point sending a text message is trivial:
```python
twilio = notifiers.get_notifier("twilio")
twilio.notify(message="Experiment complete")
```

Now I can run experiments without having to monitor them and it took a whopping 3 lines of code (`import notifiers` is the third one). That's pretty awesome if you ask me. I could see myself adding period status updates, but I'm not sure how much I want to spam my phone. In the end I'm pretty happy with both `notifiers` and Twilio, and I'll probably find an excuse to use them in the future.

You may be wondering why I'm using the entire `notifiers` package if I'm only using the Twilio provider. The answer is that there's not really a good reason, but the ability to scale from text messages with Twilio to entire email reports based on experiment results is an interesting possibility.

[click]: https://click.palletsprojects.com/en/7.x/
[progressbar]: https://click.palletsprojects.com/en/7.x/utils/#showing-progress-bars
[notifiers]: https://github.com/liiight/notifiers
