+++
title = "Polsim - a case study for small-scale scientific computing in Rust"
date = 2019-06-06T11:33:37-05:00
draft = false
categories = []
description = "...in which I teach you more about polarization than you ever cared to know"

[extra]
show_date = false
+++

<!-- Math rendering -->
<script src='https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/latest.js?config=TeX-MML-AM_CHTML' async></script>
<script type="text/x-mathjax-config">
MathJax.Hub.Config({tex2jax: {inlineMath: [['$','$'], ['\\(','\\)']]}});
</script>

Let's get this out of the way: `polsim` is a command line utility for doing **pol**arization **sim**ulations. I'm a physicist by day (shell of a man by night), and I work with lasers on a daily basis. My PhD is based on a measurement technique[^1] that's polarization-sensitive, so it would be useful to be able to predict or ballpark the polarization of a laser beam without too much trouble. The code can be found on GitHub:

* [`polarization`](https://github.com/zmitchell/polarization): the library that handles the simulations
* [`polsim`](https://github.com/zmitchell/polsim): the command line utility for using `polarization`

The motivation for this post is to recount my experiences developing a scientific tool written in Rust in the context of someone with a scientific background[^2]. I'll explain why I made certain choices, and I'll document the things that I struggled with along the way.

# Polarization

I'm not here to teach you physics, but a little bit of background is required. I'll keep it to a minimum so that I don't give you nightmares.

Polarization is loosely defined as how light oscillates as it travels through space. See the image below:

![circular and linear polarization](https://upload.wikimedia.org/wikipedia/commons/0/09/Circular.Polarization.Circularly.Polarized.Light_Homogenous_Circular.Polarizer_Left.Handed.svg)

Technically speaking, polarization is a vector, meaning that it has a size and a direction, which is why the polarization is represented by an arrow in the figure above (the size is the length of the arrow, the direction is the direction the arrow is pointing). The red line is the path traced out by the tip of the polarization vector. For linearly polarized light, the vector just swings back and forth along some line (this is the middle portion of the image). For circularly polarized light, the vector traces out a circle if you look at the beam head-on[^3], or a spiral if you look at the beam traveling through space[^4].

The polarization of a beam changes when it interacts with other objects, for instance, when the beam reflects from a surface or passes through some optical element (e.g. a polarizer). We want to be able to predict what will happen to the polarization of a beam after it interacts with a series of optical elements. Conversely, we could also look at the polarization before and after some optical elements and ask "what could have made my beam look this way". This kind of modeling is what `polsim` is for.

Luckily, there are standard techniques for this kind of modeling so I don't need reinvent that wheel. The formalism that `polsim` is based on is called [Jones calculus][jones-calc]. Jones calculus is relatively simple but approximates reality well enough for my purposes. There is a more complete formalism called [Mueller calculus][mueller-calc] but it's more complex and I don't need the additional information it provides.

# Jones calculus

Jones calculus informs the structure of `polsim` so I need to discuss this a little bit. In Jones calculus your polarization is a vector (basically a one-column matrix) of complex numbers

$$
\vec{E} = \begin{bmatrix} A \\\\ B e^{i\delta} \end{bmatrix} = \begin{bmatrix} \text{complex} \\\\ \text{complex} \end{bmatrix}
$$

and optical elements, the things that interact with your beam, are 2x2 matrices of complex numbers:

$$
M = \begin{bmatrix}
m_{00} & m_{01} \\\\ m_{10} & m_{11} \end{bmatrix} = \begin{bmatrix} \text{complex} & \text{complex} \\\\ \text{complex} & \text{complex} \end{bmatrix}
$$

You obtain the final polarization by multiplying the initial polarization by all the elements that the beam interacts with, like so:

$$
E_{f} = M_{N} \times \ldots \times M_2 \times M_1 \times E_i
$$

So, when you really get down to it, you're just multiplying 2x2 matrices together. That fact means that I don't need a ton of computational horsepower, freeing me up to make decisions based on preference rather than necessity. I'll discuss this further when it comes to which linear algebra crate I chose.

In principle you could do all of this multiplication by hand. In fact, if you're trying to see how one particular parameter of an optical element influences the final result, it's often a good idea to do this multiplication by hand to get an analytical solution. However, these matrices can get ugly and doing the arithmetic by hand is tedious:

$$
\begin{bmatrix} \cos^{2}\left(\theta\right) + e^{i\varphi} \sin^{2}\left(\theta\right) & \sin\left(\theta\right)\cos\left(\theta\right) - e^{i\varphi} \sin\left(\theta\right)\cos\left(\theta\right) \\\\ \sin\left(\theta\right)\cos\left(\theta\right) - e^{i\varphi} \sin\left(\theta\right)\cos\left(\theta\right) & \sin^{2}\left(\theta\right) + e^{i\varphi} \cos^{2}\left(\theta\right) \\\\ \end{bmatrix}
$$

No one has ever used this matrix without looking it up.

# Crate choices

Now that I have the background out of the way, I can walk through some of the necessary building blocks:

- complex numbers
- vectors (essentially a 1-column matrix)
- matrices

There's no complex number support in the Rust standard library, so I had to look elsewhere. The most mature and feature-complete solution is the [`num`][num] crate and its `num::complex::Complex` type. The type `Complex<T>` is parameterized by some numerical type `T` e.g. `f32` or `f64`.

My choice in the linear algebra space was made more difficult by the wealth of linear algebra crates that are available. A [quick search on crates.io][cratesio-linalg] for the query "linear algebra" returns 95 results. There are really two options that stand out: [`ndarray`][ndarray] and [`nalgebra`][nalgebra]. The `ndarray` crate seems to be a generic multi-dimensional array, similar to what NumPy provides in the Python world, whereas `nalgebra` seems to be more focused on square matrices and vectors for computer graphics. I only need square (2x2) matrices, so I went with `nalgebra`, though I'm sure I would have been able to achieve the same results with `ndarray`.

I use the `nalgebra::Vector2<T>` and `nalgebra::Matrix2<T>` types to represent beams and optical elements respectively, where `T` is `num::complex::Complex<f64>`.

# The polarization crate
Getting back to the code, I needed to translate the physics of the problem into Rust. To do this I made a crate called `polarization` which does the actual simulation work. `polsim` allows users to define simulations in a declarative fashion, does validation on those simulation definitions, then hands things off to `polarization` to do the simulation. 

There were two distinct "entities" that I wanted to model, beams and optical elements, so I described each one with its own trait. In Jones calculus the polarization of a beam is represented by a two-element vector. We refer to this type of vector as a "Jones vector". Some examples of things I expect to be able to do with a beam are get its intensity (brightness), pull out the x/y-component, get the underlying vector so I can multiply it with a matrix, and a variety of other things. I came to the following (truncated) definition:

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

The crate isn't actually generic over the `JonesVector` trait (you'll see functions take and return `Beam` explicitly), but the plan is to rectify that at some point.

For optical elements I again define a trait to encode the behavior that all optical elements should have. This trait is smaller because most of the behavior will be element-specific.

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

In order to perform this simulation you need exactly one beam and at least one element for the beam to propagate through. You can represent a vacuum (which won't change the polarization of the beam) with an identity matrix, so you really have no excuse for doing a simulation without at least one optical element. Another point to consider is that the order in which the beam encounters the optical elements determines the order in which the matrices should be multiplied together[^6]. I'm not just going to let you multiply matrices together willy-nilly, sorry. 

I define a type called `OpticalSystem` so that there is an adult in the room. You add a beam and some elements to the system, call `OpticalSystem::propagate()`, and the system will return a `Result<Beam, JonesError>`. When you put it all together, a very simple simulation looks like this:

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

# Debugging
The first thing I struggled with was using a debugger. This was my first time using a debugger, so I was already in uncharted territory. At the time I was working on this I was using neovim and a terminal as my "IDE", but since then I've moved to CLion and I can say that its debugger is relatively pleasant to use.

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

There's quite a bit more output now. If you wade through the sea of colons[^5], you can see the the entire second half of this output is just defining the type of a matrix named `acc` (this is inside of a `fold`, and `acc` is the accumulator). The point here is that the actual types of matrices in `nalgebra` can be very verbose. There is a language feature on the horizon called const-generics that should eventually alleviate some of the pain here.

Getting back to debugging, lets try to find the values inside this matrix `acc`. You can list the variables in this stack frame with the command `fr v`. There are three variables in this stack frame, but I'll only show one because there's a lot to wade through.

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

I know from experience which element of the matrix (row/column) each of these values is supposed to appear in, but there's no other indicator which `data` belongs to which row/column. I know I'm really harping on this debugging thing, but debugging is a crucial part of the developer experience. That's not to say that effort hasn't been put towards this, just that there's still plenty of work to be done.

# Testing
This is science, so you should be able to rely on the correctness of the results. It's generally a good practice to test your code, but that goes doubly so for a scientific tool. In order to really cover my bases I'm using property based testing (PBT).

For those of you not familiar with PBT here's a quick introduction. A unit test for a function that does addition might check a statement like "the sum of 2 and 3 is 5". In this type of test you know (and supply) the exact input and verify that it produces some known exact output. This test is simple to write and simple to come up with, but doesn't provide much confidence that the addition function would work for other inputs.

In PBT you make more general statements about your program and verify them several times with a sequence of randomly generated inputs. This type of test might check a statement like "the sum of two positive integers **x** and **y** is also positive". The test would randomly generate several positive integers and make sure their sum is greater than zero, giving you the confidence that your addition function works for a wide range of inputs.

There's always a tradeoff, however. Your test suite will generally take longer to run since you're running each test several times. You will also spend some amount of time debugging broken tests when you discover  edge cases **in your tests** due to the randomly generated inputs.

I think PBT and science should be best friends, and here's why: science provides you a wealth of properties to test. Different scientific fields may have more or less difficulty identifying properties that map well to software tests, but for a "hard", quantitative field like experimental physics, there's more properties to test than I care to implement.

For example, here is a very short list of properties I test just in `polarization`:
- The intensity of a beam that's passed through two crossed polarizers should be zero.
- The intensity of a beam shouldn't change if it's rotated by an arbitrary angle.
- A beam that's rotated 360 degrees should look exactly the same as the original beam.
- An optical element that's rotated 360 should look exactly the same as the original element.

My PBT crate of choice is [`proptest`][proptest]. If you've ever used [`hypothesis`][hypothesis] in the Python world, `proptest` is similar in spirit. The central idea is that there are "strategies" that produce instances of a given type, and your test specifies that its inputs should come from some strategies.

There are strategies for many primitive and built-in types like `f64`, `Vec<T>`, etc. You can also create your own strategies or compose strategies together. Those two features allow you to generate instances of complicated types such as `OpticalSystem`.

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

Most of this is boilerplate so here's the important bit:
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

# polsim

With all of that out of the way, we can finally talk about `polsim` itself. Simulations are defined in a TOML file using a syntax I've laid out in the documentation. Here's what it looks like:

```toml
[beam]
polarization = "linear"
angle = 90
angle_units = "degrees"

[[elements]]
element_type = "polarizer"
angle = 45
angle_units = "degrees"

[[elements]]
element_type = "qwp"
angle = 0
angle_units = "degrees"
```

It might look odd to have to define the angle units everywhere, but that's done on purpose. It can be more convenient to use degrees in one place or radians in another, and I'm planning on incorporating other angles types in the future (wavelengths and fractions of `pi`). On top of that, you definitely don't want your simulation results to be wrong because you meant radians where `polsim` thought you meant degrees.

I use `serde` to deserialize this TOML file into a struct so that I can do some validation. The structs that this gets deserialized into are a bit ugly because I have to account for all possible beam and element definitions. For example, the `polarization` field in the beam definition determines which other fields are required in the beam definition. Here's the struct that a beam gets deserialized into:

```rust
#[derive(Debug, Deserialize, Serialize)]
pub struct BeamDef {
    pub polarization: PolType,
    pub angle: Option<f64>,
    pub angle_units: Option<AngleType>,
    pub x_mag: Option<f64>,
    pub x_phase: Option<f64>,
    pub y_mag: Option<f64>,
    pub y_phase: Option<f64>,
    pub phase_units: Option<AngleType>,
    pub handedness: Option<HandednessType>,
}
```

The next step is to validate the beam definition:

```rust
fn validate_element(elem: &ElemDef) -> Result<OpticalElement> {
    match elem.element_type {
        ElemType::Polarizer => {
            validate_polarizer(elem).chain_err(|| "invalid polarizer definition")
        }
        ElemType::HWP => validate_hwp(elem).chain_err(|| "invalid half-wave plate definition"),
        ElemType::QWP => validate_qwp(elem).chain_err(|| "invalid quarter-wave plate definition"),
        ElemType::Retarder => validate_retarder(elem).chain_err(|| "invalid retarder definition"),
        ElemType::Rotator => {
            validate_rotator(elem).chain_err(|| "invalid polarization rotator definition")
        }
    }
}
```

You'll note that I'm using `error-chain` here for my error handling. I've never been very clear on what the in-vogue method of error handling is in the Rust ecosystem, but `error-chain` makes it very easy to spell out exactly where a user went wrong in their simulation definition:

```
$ polsim has_error.toml
error: invalid system definition
caused by: invalid element definition
caused by: invalid polarizer definition
caused by: invalid angle definition
caused by: missing parameter in definition: 'angle_units'
```

If a user defines a simulation with more than one instance of a given optical element, `polsim` won't point out which one has the error, so there's some work to do there.

Another area that needs work is the output because it's currently very basic:

```
$ polsim examples/circular_polarizer.toml
intensity: 5.00000e-1
x_mag: 5.00000e-1
x_phase: 0.00000e0
y_mag: 5.00000e-1
y_phase: 1.57080e0
```

or

```
$ polsim --table examples/circular_polarizer.toml
+------------+------------+-----------+------------+-----------+
| intensity  | x_mag      | x_phase   | y_mag      | y_phase   |
+------------+------------+-----------+------------+-----------+
| 5.00000e-1 | 5.00000e-1 | 0.00000e0 | 5.00000e-1 | 1.57080e0 |
+------------+------------+-----------+------------+-----------+
```

The goal is to have the initial and final polarization plotted with `gnuplot`, and some preliminary work on that front suggests that it shouldn't be very difficult.

# Future work
There's a wealth of improvements that could be made to this project, so I'll just drop a list of them right here.

* Migrate to the Rust 2018 edition.
* Add `wavelength` and `pi` angle units.
* Plot the initial and final polarization ellipses using `gnuplot`.
* Add a way to sweep a parameter to see how the result changes as the input changes.
* Improve support for custom optical element types.
* Add support for reflections from metals/dielectrics (blocked by a bug).

# Conclusion

This was a fun project to work on because it gave me an excuse to bring Rust into my day job, but I'm ready to focus my efforts on other projects for now. I would be more than happy to mentor anyone that wants to contribute, and I've put a good deal of effort into making sure that the documentation is thorough and easy to read.

As for the state of the Rust ecosystem, I still don't think it's quite there yet for the average scientist. I felt pretty comfortable with Rust because I'm a programming nerd, but I still see Python as the tool of choice for most physicists. Here's an illustrative example: find a modified Bessel function of the second kind of order 0. In Python (even if you don't know what I just asked) your first step is to search the SciPy documentation (the function is called `k0` there). In Rust, without looking I'm not confident that function exists yet. In the Python world you know that `X` exists somewhere, you just need to find it, but that certainty that `X` exists isn't there yet for Rust. Give it time and I think Rust will start to show up in some surprising places.

I don't want this to come off as too negative towards Rust, I love it and wish more scientific software was written in it. When it comes to handling communication between equipment or data collection, I see Rust being a superpower due to its speed, safety, and ease of use. I've been toying with the idea of reimplementing the program that controls/coordinates the equipment in my experiment because I inherited the spaghettiest of spaghetti code, but at the same time I'd like to graduate at some point.

Like I mentioned at the beginning, this was just meant to document my experience, but hopefully you at least learned a little bit about polarization. Feel free to open an issue on either of the `polsim` or `polarization` repositories if you have any questions!

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
