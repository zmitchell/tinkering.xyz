+++
title = "polsim - a small case study for scientific computing in Rust"
date = 2019-06-06T11:33:37-05:00
draft = true
categories = []
description = "...in which I teach you more about polarization than you ever cared to know"

[extra]
show_date = false
+++

Let's get this out of the way: `polsim` is a command line utility for doing **pol**arization **sim**ulations. I'm a physicist by day (shell of a man by night), and I work with lasers on a daily basis, so it's not uncommon for me to helicopter-parent my beam and want to know what it's up to at a number of points in my experiment[^1].

The motivation for this post is to recount my experiences developing a scientific tool written in Rust in the context of someone with a scientific background[^2]. I'll explain why I made certain choices, and I'll document the things that I struggled with along the way.

# Polarization

I'm not here to teach you physics, but a little bit of background is required. I'll keep it to a minimum so that I don't give you nightmares.

Polarization is loosely defined as how light oscillates as it travels through space. More specifically, it's a vector, which you can think of as a mathematical object with a size and direction (fight me mathematicians). See the image below:

![circular and linear polarization](https://upload.wikimedia.org/wikipedia/commons/0/09/Circular.Polarization.Circularly.Polarized.Light_Homogenous_Circular.Polarizer_Left.Handed.svg)

The red line is the path traced out by the tip of the polarization vector. For linearly polarized light, the vector just swings back and forth along some line (this is the middle portion of the image). For circularly polarized light, the vector traces out a circle if you look at the beam head-on[^3], or a spiral if you look at the beam traveling through space[^4].

The polarization of a beam changes when it interacts with other objects, for instance, when the beam reflects from a surface or passes through a some optical element (e.g. a polarizer). We want to be able to answer questions like "what will my beam look like after passing through these elements." Conversely, we could also look at the polarization before and after some optical elements and ask "what could have made my beam look this way". This kind of modeling is what `polsim` is for.

Luckily, there are standard techniques for this kind of modeling, so I don't need reinvent the wheel in that regard. The formalism that `polsim` is based on is called [Jones calculus][jones-calc] (don't worry, there's no actual calculus involved). Jones calculus is relatively simple but approximates reality well enough for my purposes. There is a more complete formalism called [Mueller calculus][mueller-calc] but it's more complex and I don't need the additional information it provides.

# Jones calculus

Again, I'll keep this to a minimum, but it informs the structure of `polsim`, so I need to discuss this a little bit. In Jones calculus your polarization is a vector (basically a one-column matrix) of complex numbers

$$
\vec{E} = \begin{bmatrix} A \\ B e^{i\delta} \end{bmatrix} = \begin{bmatrix} \text{complex} \\ \text{complex} \end{bmatrix}
$$

and optical elements, the things that interact with your beam, are 2x2 matrices of complex numbers:

$$
M = \begin{bmatrix}
m_{00} & m_{01} \\
m_{10} & m_{11}
\end{bmatrix} = \begin{bmatrix}
\text{complex} & \text{complex} \\
\text{complex} & \text{complex}
\end{bmatrix}
$$

You obtain the final polarization by multiplying the initial polarization by all the elements that the beam interacts with, like so:

$$
E_{f} = M_{N} \times \ldots \times M_2 \times M_1 \times E_i
$$

So, when you really get down to it, you're just multiplying 2x2 matrices together. That fact means that I don't need a ton of computational horsepower, freeing me up to make decisions based on preference rather than necessity. I'll discuss this further when it comes to which linear algebra crate I chose.

In principle you could do all of this multiplication by hand. In fact, if you're trying to see how one particular parameter of an optical element influence the final result, it's often a good idea to do this multiplication by hand to get an analytical solution. However, these matrices can get ugly, and doing the arithmetic by hand is tedious:

$$
\begin{bmatrix}
\cos^{2}\left(\theta\right) + e^{i\varphi} \sin^{2}\left(\theta\right) & \sin\left(\theta\right)\cos\left(\theta\right) - e^{i\varphi} \sin\left(\theta\right)\cos\left(\theta\right) \\\\
\sin\left(\theta\right)\cos\left(\theta\right) - e^{i\varphi} \sin\left(\theta\right)\cos\left(\theta\right) & \sin^{2}\left(\theta\right) + e^{i\varphi} \cos^{2}\left(\theta\right) \\\\
\end{bmatrix}
$$

No one has ever used this matrix without looking it up.

# Translation to Rust

Now that I have the background out of the way, I can walk through some of the necessary building blocks. I need the following:

- complex numbers
- vectors (essentially a 1-column matrix)
- matrices

## Complex numbers
There's no complex number support in the Rust standard library, so I had to look elsewhere. The most mature and feature-complete solution is the [`num`][num] crate and its `num::complex::Complex` type. The type `Complex<T>` is parameterized by some numerical type `T` e.g. `f32` or `f64`. I chose `Complex<f64>` for my simulations, meaning that every complex number looks like this `<f64> + i<f64>`.

## Linear algebra
My choice in the linear algebra space was made more difficult by the wealth of linear algebra crates that are available. A [quick search on crates.io][cratesio-linalg] for the query "linear algebra" returns 95 results. There are really two options that stand out: [`ndarray`][ndarray] and [`nalgebra`][nalgebra]. The `ndarray` crate seems to be a generic multi-dimensional array, similar to NumPy in the Python world, whereas `nalgebra` seems to be more focused on square matrices and vectors for computer graphics. I only need square (2x2) matrices, so I went with `nalgebra`, though I'm sure I would have been able to achieve the same results with `ndarray`.

I use the `nalgebra::Vector2<T>` and `nalgebra::Matrix2<T>` types to represent beams and optical elements respectively, where `T` is `num::complex::Complex<f64>`.

# Pain point #1 - Using a debugger
The first thing I struggled with was using a debugger. This was my first time using a debugger, so I was already in uncharted territory. I had just been using neovim and a terminal as my "IDE", so I can't really speak to debugging support in CLion, though anecdotally I've heard/read that it works well.

Let's start with some minor things, like how values are printed in the debugger. I'll first set a breakpoint inside of a closure:

```
(lldb) br set -f system.rs -l 348
Breakpoint 1: where = polarization-b20b1f754e235950`polarization
::jones::system::OpticalSystem::composed_elements
::_$u7b$$u7b$closure$u7d$$u7d$
::h19d2e65336af7615 + 577 at system.rs:348:30, address = 0x00000001001e8c11
```

Most of this looks fine except for the `_$u7b$$u7b$closure$u7d$$u7d$` piece. I think this is supposed to read `{{closure}}`, but this isn't a big deal because you can still basically read what it says. Now let's let the program run until we hit that breakpoint.

```
(lldb) r
...
Process 33329 stopped
* thread #2, name = 'jones::system::test::test_beam_passes_through', stop reason = breakpoint 1.1
    frame #0: 0x00000001001e8c11 polarization-b20b1f754e235950`polarization::jones::system::OpticalSystem
    ::composed_elements::_$u7b$$u7b$closure$u7d$$u7d$::h19d2e65336af7615((null)=0x000070000ef72f98,
    acc=Matrix<num_complex::Complex<f64>, nalgebra::base::dimension::U2, nalgebra::base::dimension::U2,
    nalgebra::base::matrix_array::MatrixArray<num_complex::Complex<f64>, nalgebra::base::dimension::U2,
    nalgebra::base::dimension::U2>> @ 0x000070000ef73030, elem=0x0000000100c16aa0) at system.rs:348:30
```

There's quite a bit more output now. If you wade through the sea of colons[^5], you can see the the entire second half of this output is just defining the type of a matrix named `acc` (this is inside of a `fold`, and `acc` is the accumulator). The point here is that the actual types of matrices in `nalgebra` can be very verbose. If I had to speculate as to why, it would be that you can't currently parameterize the definition of a type with a value, or, put another way, you can't make a generic matrix with a user-defined number of rows/columns without resorting to some type-system magic. There is a language feature on the horizon called const-generics, that should eventually let you do just this, but as it stands, so maybe this will simply just take some time.

Getting back to debugging, lets try to find the values inside this matrix `acc`. You can list the variables in this stack frame with the command `fr v`. There are three variables in this stack frame, but I'll only show one because, as you can see below, there's a lot to wade through.

```
(nalgebra::base::matrix::Matrix<num_complex::Complex<double>, nalgebra::base::dimension::U2,
nalgebra::base::dimension::U2, nalgebra::base::matrix_array::MatrixArray<num_complex::Complex<double>,
nalgebra::base::dimension::U2, nalgebra::base::dimension::U2> >) acc = {
  data = {
    data = {
      data = {
        parent1 = {
          parent1 = {
            parent1 = <Unable to determine byte size.>

            parent2 = <Unable to determine byte size.>

            data = (re = 1, im = 0)
          }
          parent2 = {
            parent1 = <Unable to determine byte size.>

            parent2 = <Unable to determine byte size.>

            data = (re = 0, im = 0)
          }
          _marker = {}
        }
        parent2 = {
          parent1 = {
            parent1 = <Unable to determine byte size.>

            parent2 = <Unable to determine byte size.>

            data = (re = 0, im = 0)
          }
          parent2 = {
            parent1 = <Unable to determine byte size.>

            parent2 = <Unable to determine byte size.>

            data = (re = 1, im = 0)
          }
          _marker = {}
        }
        _marker = {}
      }
    }
  }
  _phantoms = {}
}
```

Again, you can see that there's quite a lot of information here, but there's really only four relevant lines:

```
...
data = (re = 1, im = 0)
...
data = (re = 0, im = 0)
...
data = (re = 0, im = 0)
...
data = (re = 1, im = 0)
...
```

I know from experience which element of the matrix (row/column) each of these values is supposed to appear in, but there's no other indicator which `data` belongs to which row/column. I know I'm really harping on this debugging thing, but debugging is a valuable skill, so as much effort as possible should be put into reducing the friction here. That's not to say that effort hasn't been put towards this, just that there's still plenty of work to be done[^6].

If you're on macOS there's a special hell you live in which requires that you codesign `gdb` in order to use `rust-gdb`, which requires differents steps and works with varying results on different versions of macOS. I've also run into a few bugs with `rust-lldb`. The latest one, which I'm running into as I write this post, gives me the following error right when `rust-lldb` is launched:

```
warning: ignoring unknown option: --one-line-before-file=command script import "/Users/zmitchell/.rustup/toolchains/stable-x86_64-apple-darwin/lib/rustlib/etc/lldb_rust_formatters.py"
warning: ignoring unknown option: --one-line-before-file=type summary add --no-value --python-function lldb_rust_formatters.print_val -x ".*" --category Rust
warning: ignoring unknown option: --one-line-before-file=type category enable Rust
(lldb) target create "target/debug/deps/polarization-b20b1f754e235950"
Traceback (most recent call last):
  File "<string>", line 1, in <module>
  File "/Users/zmitchell/.rustup/toolchains/stable-x86_64-apple-darwin/lib/rustlib/x86_64-apple-darwin/lib/python2.7/site-packages/lldb/__init__.py", line 1481, in <module>
    class SBAddress(object):
  File "/Users/zmitchell/.rustup/toolchains/stable-x86_64-apple-darwin/lib/rustlib/x86_64-apple-darwin/lib/python2.7/site-packages/lldb/__init__.py", line 1647, in SBAddress
    __swig_getmethods__["module"] = GetModule
NameError: name '__swig_getmethods__' is not defined
Traceback (most recent call last):
  File "<string>", line 1, in <module>
NameError: name 'run_one_line' is not defined
Traceback (most recent call last):
  File "<string>", line 1, in <module>
NameError: name 'run_one_line' is not defined
Traceback (most recent call last):
  File "<string>", line 1, in <module>
NameError: name 'run_one_line' is not defined
...(repeated several times)
```

Using a debugger can feel like being dropped into an eldritch horror to the uninitiated *even when it's working properly*, so this is not a good look for a language that markets itself as an entrypoint into systems programming.

# Encoding the physics as Rust
Getting back to the code, I needed to translate the physics of the problem into Rust. There were two distinct "entities" that I wanted to model, beams and optical elements, so I described each one with its own trait.

## Beams
In Jones calculus the polarization of a beam is represented by a two-element vector. We refer to this type of vector as a "Jones vector", hence the name of the trait. The trait should encode the behavior I expect from a beam e.g. return the intensity (brightness) of the beam, return the underlying vector, etc. I came to the following (truncated) definition:

```rust
pub trait JonesVector {
    // Intensity of the beam
    fn intensity(&self) -> Result<f64>;

    // Returns the x-component of the beam
    fn x(&self) -> f64;

    // Returns the y-component of the beam
    fn y(&self) -> f64;

    // Returns the vector representation of the beam
    fn vector(&self) -> Vector2<Complex<f64>>;

    ...
}
```

I implement this trait for a type called `Beam`:

```rust
// Basically a container for the Vector2<T>
pub struct Beam {
    vec: Vector2<Complex<f64>>,
}
```

The crate isn't actually generic over the `JonesVector` trait (i.e. you'll see functions take and return `Beam` explicitly), but the plan is to rectify that at the same time I update to Rust 2018.

## Optical elements
Again, I define a trait to encode the behavior that all optical elements should have. This trait is smaller because most of the behavior of an optical element will be specific to that type of element.

```rust
pub trait JonesMatrix {
    // Rotate the element by the given angle
    fn rotated(&self, angle: Angle) -> Self;

    // Return the matrix representation of the element
    fn matrix(&self) -> Matrix2<Complex<f64>>;

    ...

}

// An ideal linear polarizer
pub struct Polarizer {
    mat: Matrix2<Complex<f64>>,

}

impl JonesMatrix for Polarizer {
    ...
}
```

One feature that I'm particularly excited about is parameter sweeps, or simulations that iterate over a range of values for a particular parameter (e.g. the angle of a particular polarizer). I've thought about how to do this, and one idea I've had is to simply create a new element type `SweepElement<T: JonesMatrix>` that would wrap an existing element and simply return a different matrix from its `JonesMatrix::matrix()` method for each iteration of the sweep. That sounds a lot like just implementing the `Iterator` trait, so there's probably a clever way to take advantage of that.

## Optical system
In order to perform this simulation you need exactly one beam, and at least one element for the beam to propagate through. You can represent a vacuum (which won't change the polarization of the beam) with an identity matrix, so you really have no excuse for doing a simulation without at least one optical element. Another point to consider is that the order in which the beam encounters the optical elements determines the order in which the matrices should be multiplied together[^6]. I'm not just going to let you multiply matrices together willy-nilly, sorry. 

I define a type called `OpticalSystem` to be the adult in the room. You add a beam and some elements to the system, then call `OpticalSystem::propagate()`, which will return a `Result<Beam, JonesError>`. If you try to skip straight to dessert without eating your vegetables, `OpticalResult` will put you in time out by returning an error. When you put it all together, the simulation looks like this:

```rust
let initial_beam = Beam::linear(Angle::Degrees(0.0));
let pol = Polarizer::new(Angle::Degrees(45.0));
let qwp = QuarterWavePlate::new(Angle::Degrees(0.0));
let system = OpticalSystem::new()
    .add_beam(initial_beam)
    .add_element(pol)
    .add_element(qwp);
let final_beam = system.propagate().unwrap();
```

# Testing
This is science, so you should be able to rely on the correctness of the results. It's generally a good practice to test your code, but that goes doubly so for a scientific tool. In order to really cover my bases I'm using property based testing. I'll even go so far as saying that property-based testing is an excellent match for scientific applications.

For those of you not familiar with property-based testing or testing in general, a brief introduction will prove useful. The most basic form of testing is called unit testing. A unit test for a function that does addition might check a statement like "the sum of 2 and 3 is 5". In this type of test you know (and supply) the exact input and verify that it produces some known exact output. This test is simple to write and simple to come up with, but doesn't provide much confidence that the addition function would work for other inputs.

In property-based testing you make more general statements about your program and verify them several times with a sequence of randomly generated inputs. This type of test might check a statement like "the sum of two positive integers **x** and **y** is also positive". The test would randomly generate several positive integers and make sure their sum is greater than zero, giving you the confidence that your addition function works for a wide range of inputs.

There's always a tradeoff, however. I'll list some drawbacks and expand on each one below (click on the triangle to expand each one):
{% details(summary="Test suite take longer to run.") %}
Each test is run many times (once for each random input), so a property-based test will necessarily take longer to run.
{% end %}

{% details(summary="Identifying properties isn't always easy.") %}
Sometimes identifying a property is easy e.g. the sum of two positive integers must also be positive. Think about how specific that property is though. Does that really mean that our addition worked properly? The same property also holds for multiplication, so it seems this property alone isn't enough to verify our addition function. A better property would be to compare the output of our addition function to the output of a known-working addition function such as one built-in to your language of choice.
{% end %}

{% details(summary="There's a tradeoff between specificity and complexity.") %}
Another issue is that general properties are easier to identify and test than specific properties. In my experience, the more specific the property gets the more complex the test becomes.
{% end %}

{% details(summary="Not all inputs are valid.") %}
If your function takes an `f64` argument, are all `f64`s really valid inputs to your function? If you're trying to test how your function handles invalid input, go ahead and feed it invalid input. If, on the other hand, you're trying to verify that a well-behaved input behaves properly, you'll have to decide how to filter out which `f64`s to accept or reject before proceeding with your test. Most property-based testing frameworks provide methods to do this filtering in one way or another, but some will also yell at you if you reject too many times.
{% end %}

## Property-based testing and scientific software
I think property-based testing and science should be best friends, and here's why: science provides you a wealth of properties to test. Different scientific fields may have more or less difficulty identifying properties that map well to software tests, but for a hard, quantitative field like experimental physics, there's more properties to test than I care to implement.

For example, here is a very short list of properties I test just in `polarization`:
- The intensity of a beam that's passed through two crossed polarizers should be zero.
- A beam that's rotated 360 degrees should look exactly the same as the original beam.
- An optical element that's rotated 360 should look exactly the same as the original element.

## proptest
My property-based testing crate of choice is [`proptest`][proptest]. If you've ever used [`hypothesis`][hypothesis] in the Python world, `proptest` is similar in spirit. The central idea is that there are "strategies" that produce instances of a given type, and your test specifies that its inputs should come from some strategies.

There are some really nice aspects of this system, such as being able to make more than one strategy for a given type e.g. only positive `f32`s, `i32`s between 5 and 23, etc. The really killer features, however, are the ability to define strategies for your own types, and the ability to compose strategies. Those two features allow you generate instances of complicated types such as `OpticalSystem`.

You tell `proptest` how to randomly generate an instance of your type by implementing the `Arbitrary` trait. Here's what that looks like for my `Angle` type:

```rust
pub enum Angle {
    Degrees(f64),
    Radians(f64),
}

impl Arbitrary for Angle {
    type Parameters = ();
    type Strategy = BoxedStrategy<Self>;

    fn arbitrary_with(_: Self::Parameters) -> Self::Strategy {
        prop_oneof![
            (any::<f64>()).prop_map(|x| Angle::Degrees(x)),
            (any::<f64>()).prop_map(|x| Angle::Radians(x)),
        ]
        .boxed()
    }
}
```

Most of this is boilerplate, here's the important bit:
```rust
prop_oneof![
    (any::<f64>()).prop_map(|x| Angle::Degrees(x)),
    (any::<f64>()).prop_map(|x| Angle::Radians(x)),
]
```
The `prop_oneof!` macro instructs `proptest` to randomly select one strategy from a list of strategies, and is useful for generating the different variants of an enum. The `any::<T>()` function produces a strategy that generates instances of the type `T`. Both lines in the macro are generating `f64`s and mapping them into the variants of the `Angle` enum. So, if I were to call `any::<Angle>()` I would get a strategy that produces a random stream of `Angle::Degrees(some f64)` and `Angle::Radians(some f64)`. In fact, I do exactly that to generate `Beam`s:

```rust
impl Arbitrary for Beam {
    type Parameters = PolarizationKind;
    type Strategy = BoxedStrategy<Beam>;

    fn arbitrary_with(args: Self::Parameters) -> Self::Strategy {
        match args {
            PolarizationKind::Linear => any_linear_beam().boxed(),
            // ... omitted
        }
    }
}

pub fn any_linear_beam() -> impl Strategy<Value = Beam> {
    any::<Angle>().prop_map(|angle| Beam::linear(angle))
}
```

There's always a tradeoff, and property based testing is no exception. I found several times that my tests were failing not because the logic being tested was wrong, but because I had constructed a bad test in one way or another. Property based testing is great for finding edge cases, but sometimes it finds them in your tests rather than your business logic. Expect to spend some time debugging the tests.


# Footnotes
[^1]: It's an ultrafast circular-dichroism spectrometer, if you must know.

[^2]: At this point I've been programming for about half as long as I've been doing science, so I'm not a complete n00b. That last statement is probably inviting the wrath of The Internet. YOLO

[^3]: APPLY DIRECTLY TO THE FOREHEAD

[^4]: How is it possible for the polarization to spiral? I'm glad you asked! You can always break down the polarization into two separate pieces that oscillate perpendiular to one another e.g. x- and y-components. If the two components oscillate in lock-step with each other i.e. in phase with each other, you get linear polarization. If one of the components lags behind the other one by a fixed amount, you get elliptical polarization. Circular polarization is a special case of elliptical polarization for which the two components have the same size and one component lags by a quarter of a cycle (a phase of `pi/2`).

[^5]: Admit it, you thought I was going to make a joke about colons here. You know what they say happens when you assume.

[^6]: For you math-inclined folks, these matrices don't commute.

[jones-calc]: https://en.wikipedia.org/wiki/Jones_calculus
[mueller-calc]: https://en.wikipedia.org/wiki/Mueller_calculus
[num]: https://github.com/rust-num/num
[cratesio-linalg]: https://crates.io/search?q=linear+algebra
[ndarray]: https://github.com/rust-ndarray/ndarray
[nalgebra]: https://github.com/rustsim/nalgebra
[proptest]: https://github.com/AltSysrq/proptest
[hypothesis]: https://github.com/HypothesisWorks/hypothesis
