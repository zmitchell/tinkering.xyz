+++
title = "The elegance of lazy sequences in Clojure"
date = 2021-03-25
draft = true
description = "Lazy sequences are everywhere in Clojure and they make a lot of the magic possible. Let's look at how they work!"
[extra]
show_date = true
+++

## Outline
- Setting the scene
    - When you see this example, what do you see?
        - Example that would take a really long time with eager sequences.
    - Why doesn't this take a really long time?
    - The example uses lazy sequences.
- Why am I talking about this
    - Many examples just slap `lazy-seq` on the front of a form and it just works.
    - You see a lot of examples that use `lazy-seq` in conjunction with `cons`. Why is that?
    - I want to demystify lazy sequences for new Clojure users.
    - The underlying code is surprisingly simple.
- When are lazy sequences used?
    - Pretty frequently
        - ex.) `map`, when passed a function and a collection
- Introducing the model system
    - The `iterate` function
        - `(iterate f x)`
        - Returns a lazy sequence of `x`, `f(x)`, `f(f(x))`, ...
    - The actual implementation is in Java.
        - clojure/jvm/lang/Iterate.java
    - Let's look at a Clojure implementation.
        - `(defn iterate [fn val] (cons val (lazy-seq (iterate fn (fn val)))))`
        - Notice that it uses a `cons` cell and recursion.
            - This seems important, but I'm too tired to formulate why.
- What does `lazy-seq` do?
    - Clojure implementation
        - https://github.com/clojure/clojure/blob/38bafca9e76cd6625d8dce5fb6d16b87845c8b9d/src/clj/clojure/core.clj#L683
        - `(defmacro lazy-seq [& body] (list 'new 'clojure.lang.LazySeq (list* '^{:once true} fn* [] body)))`
        - Creates a list of the form:
            - `(new clojure.lang.LazySeq (fn* [] body))`
                - `list*` treats its last argument as a sequence and prepends the other arguments to it.
        - What is `fn*`?
            - https://github.com/clojure/clojure/blob/38bafca9e76cd6625d8dce5fb6d16b87845c8b9d/src/clj/clojure/core.clj#L4513
            - It's used to define a "function expression"
                - You can see that here:
                    - https://github.com/clojure/clojure/blob/38bafca9e76cd6625d8dce5fb6d16b87845c8b9d/src/jvm/clojure/lang/Compiler.java#L7104
        - This list is basically an anonymous function whose body is the expression passed to `lazy-seq`.
        - So this list `(new ...)` calls the `LazySeq` constructor with an anonymous function whose body is the expression passed to `lazy-seq`.
    - If we back up, what does our `iterate` function look like?
        - `(defn iterate [& body] (cons value <LazySeq object>))`
