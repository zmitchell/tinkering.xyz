+++
date = "2017-03-13T16:53:14-04:00"
draft = false
description = "Student loan simulations"
tags = [
    "python",
    "optimization",
    "money"
]
title = "Minimizing Student Loan Interest with Python - Part 2"
+++

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
