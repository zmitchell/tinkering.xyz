+++
date = "2017-03-13T16:53:14-04:00"
draft = false
description = "The simulation program"
tags = [
    "python",
    "optimization",
    "money"
]
title = "Minimizing Student Loan Interest with Python - Part 2"
+++

In [Part 1][student-loans-part-1] of this series I discussed the ins and outs of student loans and in this installment I'll be discussing the program I wrote to simulate paying off our student loans. If you haven't read Part 1 I recommend doing that before continuing so that you can familiarize yourself with the terminology. The code for this project can be found [here][code].

# Loan Information
I started out by making a class to hold all of the information related to each loan. For each loan I need the following pieces of information:

- a name or label
- the current principal
- the current interest
- the interest rate
- how many payments are left
- how many months until payments start
- whether the interest is deferred
- the total interest paid  
  

I store most of those fields using `@property`, which is the first time I've really used the `@property` decorator. If you've never heard of `@property`, [here's][property-post] a nice overview. In a nutshell, `@property` lets you write methods that are accessed like properties i.e. `foo.set_bar(value)` becomes `foo.bar = value` and `value = foo.get_bar()` becomes `value = foo.bar`. You can even use `@property` to give your class properties whose values are calculated each time they are accessed.

# Payoff Algorithm
The question I wanted to answer was this: if I receive a big check, how should I distribute the money between my student loans to minimize the total interest I'll pay over the lifetime of my loans? The two functions below outline the loan payoff process.

```python
def interest_func(payments):
    loans = make_loans(print_report=False)
    for payment, loan in zip(payments, loans):
        loan.make_payment(payment)
    payoff_loans(loans, print_report=False)
    return total_paid_interest(loans)

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

The first step is to supply `interest_func` with a list of dollar amounts to pay towards the corresponding loans. This list of dollar amounts represents how I've decided to split up the hypothetical big check I've received. How the individual dollar amounts are chosen will be discussed later. 

The next step is handled by `payoff_loans`, which handles the process of making monthly payments until all of the loans are paid off. This function is where the monthly budget is set, payments are made, interest is accrued, etc.

The last step, totaling the interest, occurs back in `interest_func`. 

# Optimization
Rather than figuring out how to allocate funds for each loan myself, I use the optimization toolkit provided by SciPy, specifically `scipy.optimize.minimize`. `minimize` takes a function you want to minimize and finds the input for which the output of that function is a minimum (if a minimum exists). For example, if you gave `minimize` the function `f(x) = x^2` it would give you back `x = 0` since that is the `x` for which `f(x)` has its lowest value.

```python

result = scipy.optimize.minimize(interest_func, 
    guess_weights, 
    method=my_method, 
    bounds=my_bounds, 
    constraints=my_constraint,
    options={'maxiter': 1000000})
```

The `scipy.optimize.minimize` function decides how to allocate funds to each loan using a guess I provide, passes that list of payments to `interest_func`, and gets back the amount of interest I'll pay. `minimize` tweaks how it allocates funds and sees how much interest I'll pay after the tweak. This process is repeated several times until the minimum amount of interest is found. 

How exactly `minimize` decides what tweaks to make is determined by the minimization method you choose via the `method` parameter. SciPy provides a variety of methods to choose from, but it's up to you to choose which method is the best fit for your problem. Some factors that can guide your choice are the smoothness of your function, whether you want to provide upper or lower bounds on the function inputs, and whether the function inputs need to satisfy some other constraints.

I've chosen to use the sequential least squares programming (SLSQP) method because it allows me to supply bounds and constraints on the inputs supplied to `interest_func`. Supplying bounds ensures that the dollar amounts are positive. Supplying a constraint function ensures that the dollar amounts always add up to the big chunk of money I started with.

# Targeting Payments
The last detail to discuss is how payments are made on a monthly basis. Each month starts with an identical budget. The minimum payments are made on active loans from that monthly budget, leaving me with a surplus each month. What I decide to do with the surplus makes a difference. I came up with three different ways to use the surplus in the program:

- pay towards the loan with the highest interest rate
- pay towards the loan that costs the most in interest in terms of sheer dollar amount
- pay towards the loan with the lowest principal  
  

Regardless of which method is chosen the surplus is put towards one loan at a time. If a loan payment is larger than the remaining balance, the amount that is overpaid is put back into the monthly surplus to be used towards other loans. I'll examine the differences between the different payoff methods in the next part of the series.

# Looking Ahead
In the next part of this series, I'll examine a few different cases using my student loan simulator.

[student-loans-part-1]: /posts/student-loan-simulator-part-1/
[code]: www.google.com
[property-post]: http://stackabuse.com/python-properties/
