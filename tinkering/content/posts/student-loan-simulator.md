+++
date = "2017-03-09"
title = "Using Python and SciPy to Minimize Total Interest Paid on Student Loans"
tags = [
    "python",
    "optimization",
    "money"
]
draft = false
+++

# Motivation
First off, my wife and I live in the United States. I'm not sure how student loans work in other countries, so keep that in mind as I pretend to know what I'm talking about.

My wife and I both have student loans (shocker). I'm still in graduate school, so I don't have to start making payments on my student loans yet. On the other hand, my wife has a Grown Up job, so she has to make student loan payments.

The question I wanted to answer was how to best distribute a lump sum between the different loans that we have to reduce the total amount of interest that we'll have paid once all of the loans are paid off.

# Interest
Before diving into the details, let's talk about how interest is calculated for student loans. We have two different kinds of loans: subsidized and unsubsidized federal student loans.

### Subsidized
This is a pretty nice deal. The loan doesn't accrue interest while you're in school, while you're in your grace period (typically six months after graduating), or while your loans are in deferrment (while I'm in graduate school). 

### Unsubsidized
This type of loan is always accruing interest. What's more is that any unpaid interest capitalizes (becomes part of the principal) at the end of your grace period. In other words, any interest that's unpaid becomes part of the loan that you accrue interest on. This sucks because you're effectively penalized for not making interest payments on your student loans while you're in school.

# Monthly Payments
There is a ton of different student loan repayment plans. Some plans adjust your monthly payments based on your income, and others just payoff the loan in a specified number of years. In general, the longer it takes to payoff the loan, the more you pay in interest. 

For the sake of simplicity and minimizing the amount of interest I'll pay over time I went with the standard repayment plan. The standard repayment plan has a term of 10 years, or 120 monthly payments. Monthly payments always target interest first, and what's left over is applied to the principal. 

As part of this program I needed to calculate these monthly payments. Initially I thought you would calculate the monthly payment by dividing the principal up into 120 equal chunks plus accrued interest. Well, that's not how things really work. In actuality, your monthly payments are constant, but over time you pay less towards interest and more towards the principal.

I thought about how to derive the formula for the monthly payment for about 5 minutes, and then just looked for it on the internet. Most of the search results are just calculators that tell you what your payments are, but not how to calculate them, so I'm listing the formula here:

M = (r * P) / (1 + (1 + r)^(-n))

where "M" is the monthly payment, "r" is the monthly interest rate (yearly rate divided by 12, not as a percent), and "n" is the number of payments you have to make. 

The typical use case for this formula is calculating what your payments will be before you have to start paying them, but it also works if you have already made some payments. Just use your current principal for "P", and your payments remaining for "n."

# Loan Details
My wife has been making student loan payments for a little while, but my payments won't start for quite some time. One of my loans is subsidized, but all of the other loans are unsubsidized.

The process I wanted to simulate looks like this:

- Make a big initial payment on some loans
- Make payments on my wife's loans for a while
- The interest on my loans will be added to their respective principals, their respective interests will be set back to zero, and we'll have to start making payments on my loans
- Make payments on all of the loans until they're paid off  
  

If you read some personal finance blogs or student loan websites, you'll generally get pretty good advice, but that advice tends to be pretty general. Some people say you should pay off the smallest loan first, then put the money you were spending on that loan towards the next smallest loan, and so on. This is called the "snowball" method. Other people say you should focus on the loan that costing you the most in interest. This is called the "avalanche" method.

Our situation isn't the typical situation in which you have a handfull of loans that all start at the same time, so I was skeptical of any generally prescribed plan. With that in mind, I got to work.

# The Program
I've become more and more interested (get it?) in Go lately, but when I saw how much interest we were accruing each day, I decided that I would do this in Python just to knock it out as quickly as possible.

### Loan Information
I started out by making a class to hold all of the information related to each loan. For each loan, I need to have a name for the loan, the current principal, the current interest, the yearly interest rate as a percent, how many payments are left, how many months are left until payments start, and whether the loan accrues interest before payments start.

From that information I came up with methods for making payments, accruing interest, keeping track of payments remaining and months until payments start, and keeping track of the total interest paid.

### Payoff Algorithm
The basic process is shown in the function below. I've ommitted a few small things here and there, but this is pretty close to what runs in my actual code.

```python
def payoff_loans(loans):
    active_loans = active_loan_indices(loans)
    monthly_budget = 1000.0
    while len(active_loans) > 0:
        make_payments(loans, active_loans, monthly_budget)
        accrue_interest(loans)
        increment_payoff_times(loans)
        active_loans = active_loan_indices(loans)
    return
```

Behind the scenes, each loan object has a record of how many months are left until payments start, whether payments have started already, how many payments are left, etc. This information is used to determine when a given loan is active (payments are being made on it).

### Optimization
For the optimization I used the `scipy.optimize.minimize` function. The `minimize` function requires a function to minimize and some parameters for the optimization procedure. I wanted to minimize the amount of interest I paid, so I wrote a function around the `payoff_loans` function.

```python
def minimization_func(loan_weights):
    weight_sum = sum(loan_weights)
    normalized_weights = [w / weight_sum for w in loan_weights]
    initial_budget = 1000.0 # lump sum to distribute
    initial_payments = [initial_budget * nw for nw in normalized_weights]
    loans = make_loans()
    for payment, loan in zip(initial_payments, loans):
        loan.make_payment(payment)
    payoff_loans(loans)
    return total_paid_interest(loans)
```

The argument to this function is a list of weights. These weights are used to divide up the initial budget we have and make our initial payments. Each time a list of weights is supplied to `minimization_func` initial payments for each loan are calculated, the program simulates the process of paying off the loans, and the total interest is calculated. The `minimize` function goes through several iterations of coming up with weights, determining whether that made the total interest higher or lower, and making tweaks to the weights to see if it can do better.

# Results
TODO
