+++
description = "Case studies"
tags = [
    "python",
    "optimization",
    "money"
]
title = "Minimizing Student Loan Interest with Python - Part 3"
date = "2017-04-08"
draft = false
+++

Ok, I've discussed the [basics][part-1] of student loans and the [program][part-2] I wrote to simulate the loan payoff process, so let's finally get into some results. I'll assume you've read those posts so that I don't have to explain reiterate all of the detail. The code for this project can be found [here][code].

Let's get some terminology out of the way. In each case (unless otherwise specified) I've received a chunk of money from somewhere (security deposit, tax return, the will of a long lost relative who was an oil baron, etc). I'm going to call this money the "lump sum." 

The `scipy.optimize.minimize` function needs you to give it a hint as to where it should start its search. In this case it will need a hint for each loan, so I'm going to call that list of hints the "guesses." Unless otherwise specified, my guesses will just be the lump sum divided by the number of loans.

Recall from Part 2 that monthly payments work by making the minimum payments on each active loan and putting the rest of the monthly budget towards one loan. Which loan the budget surplus is applied to is determined by which targeting method I've chosen. I can target the loan with the highest interest rate, the lowest principal, or any other method I cook up. Unless otherwise specified I'm targeting the loan with the highest interest rate.

## Sanity Check - Identical Loans, Identical Guesses
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

## Sanity Check - Deliberately Bad Guesses
Minimization algorithms can have a problem telling the difference between a local minimum and the global minimum, or in other words they can have a hard time knowing if the minimum they've found is just the minimum value in some region, or the absolute minimum for the entire space. To avoid problems like this many algorithms let you tweak some parameters to narrow down the space that the algorithm will search through. 

One common parameter to tweak is the point at which the algorithm should begin its search. The algorithm can find the minimum quickly if you give it a guess near the actual minimum, but it can get stuck in a local minimum (not what you're looking for) or not find a minimum at all if supplied with a bad guess. 

In this scenario I had two loans with $5k principals, but one had a 5% interest rate, and the other had a 5.1% interest rate. The expected behavior to put the money towards the loan with the higher interest rate. To sabotage the program I gave it guesses that were weighted towards the loan with the lower interest rate to see how bad I could make my guesses before it would start to allocate money to the loan with the lower interest rate. I made it all the way up to a ratio of 1,000,000:1 and just gave up. I wasn't able to get the program to make a mistake this way.

```text
Loan 1: P $5000.00 | I $0.00 5.10%
Loan 2: P $5000.00 | I $0.00 5.00%
Guesses: [0.000999999000001, 999.999000001]
Starting Budget: 1000.0
Monthly Budget: 159.47
Loan 1: $1000.00
Loan 2: $0.00
```

One thing that makes a difference to the quality of this test is how long the loans take to pay off. As you can probably imagine, differences in payoff strategies will become more apparent as the loans take longer to pay off. I realized this when the program would allocate money incorrectly for guesses that were only slightly off. I later realized the monthly budget was set too high so the loans were beign paid off before any real differences in payoff strategy could have an effect. With that in mind I set the monthly budget to 1.5x the sum of the minimum monthly payments for this test, which greatly increased the resistance to bad guesses.

## Case - Equal Principals, Different Rates
Now we'll throw a handful of loans at the program that all have different interest rates and see what it does with a few different payment strategies. We'll take 5 loans with $5k principals, and give each one a different interest rate. The last sanity check showed that your guesses don't really matter, so I'll just give the loans equal guesses.

```text
Loan 1: P $5000.00 | I $0.00 3.00%
Loan 2: P $5000.00 | I $0.00 3.50%
Loan 3: P $5000.00 | I $0.00 4.00%
Loan 4: P $5000.00 | I $0.00 4.50%
Loan 5: P $5000.00 | I $0.00 5.00%
Starting Budget: 1000.0
Guesses: [200.0, 200.0, 200.0, 200.0, 200.0]
Monthly Budget: 379.80
```

You may recall from the previous post that the monthly budget is applied by first making the minimum payments on all of the active loans, leaving a surplus that can be applied in a number of different ways. I'll look at applying the surplus to the loan with the highest interest rate, the lowest principal, and the highest principal. I'll compare the total interest paid, and how long it takes to pay off the loans. I've included the distribution of the lump sum and how much interest was paid for each method below. All three methods completed in 74 months, but the highest interest rate method ended with a payment of ~$3 in the last month, so I'm going to say it really completed in 73 months.

```text
Highest Interest Rate
Loan 1: $0.00
Loan 2: $0.00
Loan 3: $0.00
Loan 4: $0.00
Loan 5: $1000.00
Interest Paid: $2747.79
```
```text
Highest Principal
Loan 1: $199.99
Loan 2: $200.00
Loan 3: $200.00
Loan 4: $200.00
Loan 5: $200.01
Interest Paid: $2962.26
```
```text
Lowest Principal
Loan 1: $0.00
Loan 2: $47.73
Loan 3: $230.60
Loan 4: $410.98
Loan 5: $310.70
Interest Paid: $2799.28
```

The first interesting thing to note is that targeting the lowest principal and the highest interest rate resulted in very nearly the same total interest despite distributing the lump sum in very different ways. For simple loan situations I could see this being worth the extra interest you pay because you get a warm fuzzy feeling from knocking out loans sooner and more frequently, which could help with the emotional burden of being saddled with a mountain of debt.

The second interesting thing is the difference in how the lump sum is distributed in each case. Targeting the highest interest rate puts the entire sum towards the highest interest rate loan. Targeting the lowest principal puts money towards all but the first loans and seems to give progressively more money to loans with higher interest rates. I say "seems" because loan 4 has a lower interest rate than loan 5, but is given $100 more than loan 5. I'm not really sure what's going on there. Targeting the highest principal loan seems to just use my guesses.

## Case - Our Loans
Now let's take a look at a more realistic, more complicated scenario. We have 3 loans that are currently being paid and 4 that won't start payments for a few years. Of those 4 that haven't started payments yet, 3 are currently accruing interest. For more information on how student loan interest works, refer back to [part 1][part-1] of the series. For the loan amounts I picked some random numbers and rounded to make things a little nicer to look at. Here's what the loans look like:

```text
Loan 1: P $7000.00  | I $2700.00 | 6.80%
Loan 2: P $6900.00  | I $1500.00 | 6.80%
Loan 3: P $9500.00  | I $3100.00 | 6.80%
Loan 4: P $5800.00  | I $0.00    | 3.40%
Loan 5: P $27000.00 | I $3000.00 | 5.40%
Loan 6: P $8500.00  | I $350.00  | 6.40%
Loan 7: P $24000.00 | I $8200.00 | 6.20%
Starting Budget: 15000.0
Guesses: 2142.86 for each
Monthly Budget: 1500.00
```

Although I randomly generated the loan amounts, the loan starting dates, payments remaining, and interest rates are close to our real situation. Loans 1-3 haven't started payments yet, but are accruing interest. Loan 4 hasn't started payments yet, but isn't accruing interest yet. Loans 1-4 will use the standard 10 year repayment plan (120 payments). Loans 5-7 have already started payments, and have ~90 payments left. Here are the results:

```text
Highest Interest Rate
Loan 1: $3005.06
Loan 2: $3223.74
Loan 3: $0.00
Loan 4: $0.00
Loan 5: $0.00
Loan 6: $8771.20
Loan 7: $0.00
Months: 72
Interest Paid: $33823.60
```
```text
Highest Principal
Loan 1: $6628.04
Loan 2: $8371.96
Loan 3: $0.00
Loan 4: $0.00
Loan 5: $0.00
Loan 6: $0.00
Loan 7: $0.00
Months: 73
Interest Paid: $34740.63
```
```text
Lowest Principal
Loan 1: $0.00
Loan 2: $8393.03
Loan 3: $0.00
Loan 4: $0.00
Loan 5: $0.00
Loan 6: $6606.97
Loan 7: $0.00
Months: 73
Interest Paid: $34396.28
```

It looks like targeting payments towards the highest interest rate saves you ~$1k over targeting the highest principal and ~$400 over targeting the lowest principal. This would lead me to believe that there's not a significant difference between the highest interest and lowest principal targeting methods. Sure, there's a $400 difference between the two cases with these randomly generated loan amounts, but that's over 6 years and on top of ~$34k in interest. You could save $400 by buying groceries differently, cutting back on Starbucks, or something else very minor *for a single year*. I guess the point I'm trying to make here is that if you are struggling with the emotional toll of your seemingly never ending student loan debt, maybe target your payments towards the loan with the lowest principal so you can get a sense of accomplishment before paying off the next loan.

[part-1]: /posts/student-loan-simulator-part-1/
[part-2]: /posts/student-loan-simulator-part-2/
[code]: https://github.com/zmitchell/student-loan-simulator
