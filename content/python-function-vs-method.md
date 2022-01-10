+++
title = "Python functions vs. methods deep dive"
date = 2020-11-15
draft = true
[extra]
show_date = true
+++

This post will dig into the real differences between a method and a function in Python. You may not have a use for some of this information, but it will help you understand Python. The better you understand your tools, the more effectively you can use them. Also it's just fun to learn "how Python do what it do."

Most of the information I'll cover here comes from the [Python data model][data_model]. I'll be referring to that document frequently, so let's call it PDM for short. My goal here is to take the some of the information in that document and make it crystal clear through a few short examples.

Unfortunately you're not able to link to many of the subsections of the PDM, so I'll just point you to the "Callable types" section for much of this.

## Functions
We'll begin with a humble function.
```python
def func(x):
    pass
```
The PDM calls this a "user-defined function" in contrast to a "built-in function" like `len()`.

Remember that everything is an object in Python, and that includes functions. That means you can store custom attributes on functions just like you would any other object e.g. `func.foo = bar`. Python objects have two properties that will come in handy in the following discussion: an identity and a type. The identity of an object is what distinguishes two objects of the same type and value. Calling `id(x)` on the object `x` will return an integer that represents the identity of `x`. For CPython this integer is the memory address of `x`. The type of `x` can be inspected by calling `type(x)`.

Functions have a number of attributes that contain information about the function, most of which are writable. For example:
- `__name__`, the name of the function
- `__module__`, the module that the function was defined in
- `__annotations__`, the function's type annotations
- `__doc__`, the function's docstring
- `__dict__`, a dictionary that holds *arbitrary function attributes* like `func.foo`
- and many more

You can see this for yourself in the REPL:
```
>>> def func(x):
...     pass
...
>>> func.__name__
'func'
>>> id(func)
4427942640
>>> type(func)
<class 'function'>
```

For my last trick, try this:
```
>>> func.__doc__ = "a user defined function called 'func'"
>>> help(func)
```
which should present you with the following:
```
Help on function func:

func(x)
    a user defined function called 'func'
(END)
```

Now let's make `func` a little more useful by making it display the identity and type of its argument:
```python
def func(x):
    print(f"id={id(x)}")
    print(f"type={type(x)}")
```
This is what the output looks like:
```
>>> func(5)
id=4424743488
type=<class 'int'>
```

## When is a function not a function?
Here's a question: when is a function not a function? Let's investigate by putting a function into a class via different means.

The first way is through a typical class definition.
```python
class MyClass:
    def __init__(self):
        pass

    # Same function definition as before,
    # just a different name
    def func_classdef(x):
        print(f"id={id(x)}")
        print(f"type={type(x)}")
```
The second way is by assigning a function to an attribute of the class:
```
>>> MyClass.func_classattr = func
```

Are `func_classdef` and `func_classattr` still `function`s? Let's find out!
```
>>> type(MyClass.func_classdef)
<class 'function'>
>>> type(MyClass.func_classattr)
<class 'function'>
```
The answer is yes, they're both still functions.

Now let's make an instance of `MyClass` and inspect the functions again.
```
>>> inst = MyClass()
>>> type(inst.func_classdef)
<class 'method'>
>>> type(inst.func_classattr)
<class 'method'>
```

Ok, our functions are `method`s rather than `function`s when accessed as attributes of an instance. What if we assign the function to a new attribute of the instance?
```
>>> inst.func_instattr = func
>>> type(inst.func_instattr)
<class 'function'>
```
Huh, so it's back to being a `function`. The difference is that `func_classattr` and `func_classdef` are both attributes of the class that `inst` is an instance of, whereas `func_instattr` is not.

Let's dig into why this difference is what makes the difference between a `function` and a `method`.

[data_model]: https://docs.python.org/3/reference/datamodel.html
