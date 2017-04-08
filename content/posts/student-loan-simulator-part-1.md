+++
date = "2017-03-09"
title = "Minimizing Student Loan Interest with Python - Part 1"
tags = [
    "python",
    "optimization",
    "money"
]
draft = false
description = "The basics of student loans"
+++

## Motivation
First off, my wife and I live in the United States. I'm not sure how student loans work in other countries, so keep that in mind as I pretend to know what I'm talking about.

My wife and I both have student loans (shocker). I'm still in graduate school, so I don't have to start making payments on my student loans yet. On the other hand, my wife has a Grown Up job, so she has to make student loan payments.

What I want to investigate is how much total interest do I pay when we pay off our student loans in different ways. There are formulas that let you calulate interest for single loans, but we have several loans with different principals, different interest rates, different numbers of payments remaining, and different dates at which payments start. It just seemed easier to have a computer do all of these calculations.

Then, let's say we get a big check like a tax return, a returned security deposit, etc. If we want to put that towards student loans, how should we spread out that money to reduce the total interest that we pay?

## Parts of a Loan
For those of you who are fortunate enough to not have to know how a loan works, let's start with a refresher course on the various parts of a loan. When a bank gives you a loan, they let you borrow a chunk of money and tell you a percentage. The chunk of money you're given is called the **principal** and the the percentage is the **interest rate**. 

By letting you borrow some money that you promise to pay back, a bank is providing a service. Any time a bank lets someone borrow money, there is some risk that the bank won't get its money back for one reason or another. So, in order to have a successful business, the bank charges you a fee for the service it's providing you and the risk it's taking on you. The fee the bank charges you is the **interest** you pay on your loan.

The interest you pay depends on how much money you're borrowing and how long it takes for you to pay it back. The interest rate is a percentage which is used to determine how much interest you pay the bank as a fraction of the amount that you borrowed. Rather than pay all of the interest up front, you accumulate or *accrue* interest every second that you still owe the bank money. The interest that you pay on your monthly payment is (typically) the interest that has accrued since the last payment.

## Types of Student Loans
There are a bunch of different types of student loans that you can get from the government or private banks. My wife and I have two different kinds of loans: subsidized and unsubsidized federal student loans.

Before diving in, it's worth mentioning the different time periods involved in the student loan process. The first time period is obviously while you're in school. While you're in the **deferrment** period, you don't have to pay back your student loans. In my case, I'm in deferrment because I'm in graduate school. The **grace** period is the time (typically six months) between leaving the deferrment period and the start of student loan payments. In my case, the grace period would be the six months between leaving graduate school and the start of my student loan payments.

### Unsubsidized
This type of student loan is always accruing interest, but you don't have to make payments until the end of the grace period. At the end of the grace period, all of the accrued interest is added to the principal, and the interest is set back to zero. This process is called **capitalization**. Now you have a loan with a larger principal that hasn't accrued any interest yet, but will accrue interest on the new, larger principal. 

In this case you essentially have to pay back a larger loan than you took out, but with the same interest rate. I guess this is better than having to make payments while you're in school, but it seems to penalize people who have long post-graduate programs (like physicists). 

The question this type of loan raises is whether my wife and I should try to pay down her current loans, or pay down my loans before they have a chance to capitalize. This is something I want to look at with my student loan simulator.



### Subsidized
This type of student loan doesn't accrue interest until after the grace period. I only have one of these loans, and it's the smallest loan that either of us have, so my gut tells me that we should put our money towards the other loans.



## Monthly Payments
There is a ton of different student loan repayment plans. Some plans adjust your monthly payments based on your income, and others payoff the loan in a specified number of years. In general, the longer it takes to payoff the loan, the more you pay in interest. 

For the sake of simplicity and minimizing the amount of interest we'll pay over time, I went with the standard repayment plan. The standard repayment plan has a term of 10 years, or 120 monthly payments. Monthly payments always target interest first, and what's left over is applied to the principal. 

As part of this program I needed to calculate these monthly payments. Initially I thought you would calculate the monthly payment by dividing the principal up into 120 equal chunks plus accrued interest. Well, that's not how things really work. In actuality, your monthly payments are constant, but over time you pay less towards interest and more towards the principal.

I thought about how to derive the formula for the monthly payment for about 1 minute, and then just looked for it on the internet. Most of the search results are just calculators that tell you what your payments are, but not how to calculate them, so I'm listing the formula here:

M = (r * P) / (1 + (1 + r)^(-n))

where "M" is the monthly payment, "r" is the monthly interest rate (yearly rate divided by 12, not as a percent), and "n" is the number of payments you have to make. 

The typical use case for this formula is calculating what your payments will be before you have to start paying them, but it also works if you have already made some payments. Just use your current principal for "P", and your payments remaining for "n."

## Loan Details
My wife has been making student loan payments for a little while, but my payments won't start for quite some time. One of my loans is subsidized, but all of the other loans are unsubsidized.

The process I wanted to simulate looks like this:

- (Maybe) make a big initial payment on some loans
- Make payments on my wife's loans for a while
- My loans capitalize
- Make payments on all of the loans until they're paid off  
  

If you read some personal finance blogs or student loan websites, you'll generally get pretty good advice, but that advice tends to be pretty general. Some people say you should pay off the smallest loan first, then put the money you were spending on that loan towards the next smallest loan, and so on. This is called the "snowball" method. You pay more in interest this way, but you get the warm, fuzzy feeling of having paid of a loan sooner. Other people say you should focus on the loan with the highest interest rate.

Our situation isn't the typical situation in which you have a handfull of loans that all start at the same time, so I was skeptical of any generally prescribed plan. With that in mind, I got to work.

## Looking Ahead
In the next part of this series, I'll describe the program I wrote to simulate the student loan payoff process.
