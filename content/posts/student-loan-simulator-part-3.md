+++
description = "Case studies"
tags = [
    "python",
    "optimization",
    "money"
]
title = "Minimizing Student Loan Interest with Python - Part 3"
date = "2017-03-18T18:53:50-04:00"
draft = true
+++

Ok, I've discussed the [basics][part-1] of student loans and the [program][part-2] I wrote to simulate the loan payoff process, so let's finally get into some results. I'll assume you've read those posts so that I don't have to explain reiterate all of the detail. The code for this project can be found [here][code].

Let's get some terminology out of the way. In each case (unless otherwise specified) I've received a chunk of money from somewhere (security deposit, tax return, the will of a long lost relative who was an oil baron, etc). I'm going to call this money the "lump sum." 

The `scipy.optimize.minimize` function needs you to give it a hint as to where it should start its search. In this case it will need a hint for each loan, so I'm going to call that list of hints the "guesses." Unless otherwise specified, my guesses will just be the lump sum divided by the number of loans.

Recall from Part 2 that monthly payments work by making the minimum payments on each active loan and putting the rest of the monthly budget towards one loan. Which loan the budget surplus is applied to is determined by which targeting method I've chosen. I can target the loan with the highest interest rate, the lowest principal, or any other method I cook up. Unless otherwise specified I'm targeting the loan with the highest interest rate.

# Sanity Check 1
Before I can believe what my program is telling me, I need to make sure that it behaves as expected. If I get the expected results for a simple case, that's a step in the right direction. The first thing I'll do is see how it decides to allocate funds between identical loans. Here's the setup:

- 4 identical loans
- each loan has a $5k principal
- each loan has a 5% interest rate
- all of the loans start payments immediately
- $1k to distribute
- The lump sum is distributed   
  

I would expect the simulator to distribute the money evenly between the four loans, but that means the expected behavior is the same as my guesses, so we can't draw any deep conclusions from the results if everything works as expected.

```text
Guesses: [250.0, 250.0, 250.0, 250.0]
Starting Budget: 1000.0
Loan 1: $250.00
Loan 2: $250.00
Loan 3: $250.00
Loan 4: $250.00
```

So the program does actually evenly distribute the lump sum between the loans. Exciting. We don't really know yet whether it's just copying my guesses, or whether that's really the optimum solution.

Something else to keep in mind is that there's no mathematical difference between 4 $5k loans with 5% interest rates and a single $20k loan with a 5% interest rate. I'll pay the same interest no matter where I put the money. I was reminded of this when I discovered that the program would just use whatever guesses I supplied. We'll take a look at the influence of the guesses in the next case.

# Sanity Check 2
Minimization algorithms can have a problem telling the difference between a local minimum and the global minimum, or in other words the lowest point in the neighborhood and the absolute lowest point. To avoid problems like this many algorithms let you tweak some parameters to narrow down the space that the algorithm will search through. 

Some algorithms allow you to specify a guess or guesses as to where to start the search for the minimum. The upside is that the algorithm can find the minimum quickly if you give it a guess near the actual minimum. The downside is that the algorithm can get stuck in a local minimum (not what you're looking for) or not find a minimum at all if supplied with a bad guess. 

With that in mind, I wanted to see how resilient my program was to stupid guesses. To test this I wanted to give it guesses that were weighted towards the wrong loan. Rather than calculate the guesses by hand, I wrote a function that takes a list of weights and generates the guesses from the lump sum and the weights.

In this scenario I'll have two loans with the same principal, but different interest rates. I have the weights set to 10:1, with the higher weight towards the loan with the lower interest rate.

```text
Weights: [20, 1, 1, 1]
Guesses: [869.57, 43.48, 43.48, 43.48]
Starting Budget: 1000.0
Loan 1: $869.57
Loan 2: $43.48
Loan 3: $43.48
Loan 4: $43.48
```
```text
Weights: [100, 1, 1, 1]
Guesses: [970.87, 9.71, 9.71, 9.71]
Starting Budget: 1000.0
Loan 1: $970.87
Loan 2: $9.71
Loan 3: $9.71
Loan 4: $9.71
```

Wait a minute, that's not what I thought was going to happen! Wasn't it supposed to distribute the money evenly? Well, no, it wasn't. The reason the program is just copying my guesses is that my guesses don't matter in this case. Think about it for a second, what's the difference between 4 equal loans with the same interest rate, and one large loan with that same interest rate? There isn't one. Since all the loans have the same interest rate, I pay the same interest no matter where I put the money.

[part-1]: /posts/student-loan-simulator-part-1/
[part-2]: /posts/student-loan-simulator-part-2/
[code]: www.google.com
