+++
title = "An optimization story"
date = 2022-01-09
draft = true
toc = false
[extra]
show_date = true
+++

Buckle up, this is a long one.

As part of my research I've been doing some modeling of absorption spectra from first principles i.e. start with the precise location of all the atoms in a protein and predict how much light it will absorb at any given wavelength. Luckily, the vast majority of this work is done by collaborators running simulations on supercomputers. That process goes like this:
- Grab the structure of the protein (the precise location of all of the atoms in the protein) from the [Protein Database](https://www.rcsb.org). People spend entire careers trying to obtain these structures. I'm studying the [Fenna-Matthews-Olson (FMO) complex](https://en.wikipedia.org/wiki/Fenna–Matthews–Olson_complex).
- Put the protein in a box and fill the remaining space with water molecules.
- Calculate the forces between the atoms to predict where they'll move. Apply some clever optimizations so that the simulation completes before the heat death of the universe. More careers are spent speeding up these calculations or making them more precise.
- The protein structure you grabbed from the database may not be the exact structure as you'd find in nature, so let the protein jiggle around like this for a while until the atoms in the protein find equilibrium positions to jiggle around.
- Save snapshots of the protein structure during this equilibrium-jiggling for post-processing.

Part of this post-processing is distilling the positions, charges, etc of all of these atoms (roughly 7000 in the case of FMO) into a few pieces of information about the parts of the protein that we care about. Many PhDs happen in this space.

For instance, there are 8 bacteriochlorophyll molecules in FMO and they have some interesting spectroscopic properties. The relevant pieces of information to me are:
- A [Hamiltonian](https://en.wikipedia.org/wiki/Hamiltonian_(quantum_mechanics)), which is a matrix (8x8 in this case) representing a quantum-mechanical description of each molecule and its interactions with the other 7 molecules.
- The [transition dipole moment](https://en.wikipedia.org/wiki/Transition_dipole_moment) of each molecule.
- The position of each molecule.

From this information I can calculate the [absorption spectrum](https://simple.wikipedia.org/wiki/Absorption_spectroscopy) (how much light is absorbed at each wavelength) and the [circular dichroism (CD) spectrum](https://en.wikipedia.org/wiki/Circular_dichroism). We don't need to get into what CD is right now, just know that it's another spectrum I calculate. Once I have these spectra I compare them against experimentally measured spectra to see how our understanding is matching up against reality.

As is common in physics, part of this research entails figuring out how many details we can ignore and still get an answer that looks mostly correct. Reducing the FMO complex to an 8x8 matrix already throws away a huge number of details, but they happen to be details that we can't calculate in a reasonable amount of time.

This brings us to my current task. I know that the simulations and experimental spectra don't match perfectly, so I wondered if I could fit small tweaks to the Hamiltonian in order to get them to match. If those tweaks are within the modeling error of the simulations, that's great and it means we're on the right track. If not, it means we're leaving out important details.

Here's the problem, though, sometimes this fit takes 8 hours to complete. The goal is to run the simulations in about 5 minutes (\~100x speedup) while still being able to read the code. We've found our rabbit hole, let's dive in!

## Problem description
First let's describe the shape of my data. A complete configuration consists of:
- a Hamiltonian (8x8 array)
- the transition dipole moments (8x3 array, one row per molecule, one column each for x-, y-, and z-coordinates)
- the positions (same layout as the dipole moments).

The number of configurations used to compute the spectrum can vary. Empirically determined configurations have been published and consist of a single configuration each. The simulations our collaborators are doing produce a single configuration per snapshot, and in this case I've been supplied with 100 snapshots.

In order to calculate the absorption spectrum I first need to compute the [eigenvalues and eigenvectors](https://simple.wikipedia.org/wiki/Eigenvalues_and_eigenvectors) of the Hamiltonian (this is also called [diagonalization](https://en.wikipedia.org/wiki/Diagonalizable_matrix#Diagonalization) of the Hamiltonian). Then I use those eigenvectors to compute *new* transition dipole moments that are weighted sums of the original dipole moments (the eigenvectors are essentially 1D arrays containing the weights). These are called "excitonic" transition dipole moments. From these excitonic transition dipole moments I calculate the "stick spectrum" for absorption and CD. We call this a stick spectrum because it just tells you the location and magnitude (and sign, in the case of CD) of each peak in the spectrum rather than the smooth continuous curve you would normally associate with a spectrum. From this stick spectrum we compute a "broadened" spectrum by placing a Gaussian (smooth bell curve) on top of each stick in the stick spectrum. If I have a single configuration, I'm done. If I have multiple configurations, I do this for each one and average them together.

Once I have spectra I compute the differences between the computed and measured spectra and try to minimize this error. The parameters being fit are the small tweaks (shifts) to the diagonal elements of the Hamiltonian (the same shifts are applied to all configurations if there are multiple configurations).

It's also worth going over my naming conventions. From looking at my code you'll see `ham` and `pigs` everywhere, and you may conclude from that that I have an unhealthy obsession with pork. This isn't true, in fact I'm a vegetarian. In reality `ham` is short for "Hamiltonian", and `pigs` is short for "pigments". A pigment is a light absorbing molecule (like a chlorophyll). Additionally, the mathematical symbol for a dipole moment is the Greek letter "mu", so `mus` is the array of dipole moments. The letter `r` is used to denote position, so `rs` is an array of positions. The snapshot files containing the Hamiltonian, dipole moments, and positions are named `conf*.csv`, so I call this collection of information a `conf`.

The code I use to run these simulations can be found here: [savikhin-lab/fmo_analysis](https://github.com/savikhin-lab/fmo_analysis).

## Finding the bottleneck
The first step when optimizing anything is finding out which part is slow. It was pretty obvious that the 100-conf fits were the ones taking a long time. Computing spectra for multiple confs just computes individual spectra in a loop, so I decided to profile a fit of a single conf.

When it comes to Python one of my go-to tools is [py-spy](https://github.com/benfred/py-spy). `py-spy` is a sampling profiler, meaning that it periodically pauses your program, records the call stack, then compiles the results into a [flamegraph](https://www.brendangregg.com/flamegraphs.html) so that you can see in which functions your program is spending the most time.

I ran `py-spy` on my `fit_shifts.py` script and this what it looked like:
![flamegraph of the fitting program](/images/fmo_analysis_fitting_single_flamegraph.svg)

This is the important part:
- 87.5% `make_stick_spectrum`
- 10% `make_broadened_spectrum`

The takeaway here is that `make_stick_spectrum` dominates the execution time. Note that this is *after* I made some optimizations several weeks ago. 

{% details(summary="Aside: sometimes NumPy is slow!") %}
It turns out that NumPy's cross product function `np.cross` is very slow for small arrays, 10x slower than computing it manually:
```python
m1 = np.array([1., 0., 0.])
m2 = np.array([0., 1., 0.])
# Built in, 39us
cross = np.cross(m1, m2)
# Manually, 3.9us
mu_cross = np.empty(3)
mu_cross[0] = m1[1] * m2[2] - m1[2] * m2[1]
mu_cross[1] = m1[2] * m2[0] - m1[0] * m2[2]
mu_cross[2] = m1[0] * m2[1] - m1[1] * m2[0] 
```
This isn't a knock against NumPy. NumPy tries to work well for a wide variety of cases, provide a consistent API, provide nice error messages, etc and it generally succeeds. However, there's going to be some overhead for any particular case and you may be able to squeeze out some extra performance by stripping out the pieces you don't need. Another area I've done this is `np.savetxt` because I always know the data I'm going to save will be a certain shape.
{% end %}

This is what `make_stick_spectrum` looks like:
```python
def make_stick_spectrum(config: Config, ham: np.ndarray, pigs: List[Pigment]) -> Dict:
    """Computes the stick spectra and eigenvalues/eigenvectors for the system."""
    ham, pigs = delete_pigment(config, ham, pigs)
    n_pigs = ham.shape[0]
    if config.delete_pig > n_pigs:
        raise ValueError(f"Tried to delete pigment {config.delete_pig} but system only has {n_pigs} pigments.")
    e_vals, e_vecs = np.linalg.eig(ham)
    pig_mus = np.zeros((n_pigs, 3))
    if config.normalize:
        total_dpm = np.sum([np.dot(p.mu, p.mu) for p in pigs])
        for i in range(len(pigs)):
            pigs[i].mu /= total_dpm
    for i, p in enumerate(pigs):
        pig_mus[i, :] = pigs[i].mu
    exciton_mus = np.zeros_like(pig_mus)
    stick_abs = np.zeros(n_pigs)
    stick_cd = np.zeros(n_pigs)
    for i in range(n_pigs):
        exciton_mus[i, :] = np.sum(np.repeat(e_vecs[:, i], 3).reshape((n_pigs, 3)) * pig_mus, axis=0)
        stick_abs[i] = np.dot(exciton_mus[i], exciton_mus[i])
        energy = e_vals[i]
        if energy == 0:
            # If the energy is zero, the pigment has been deleted
            # so put it somewhere far away to avoid dividing by zero
            energy = 100_000
        wavelength = 1e8 / energy  # in angstroms
        stick_coeff = 2 * np.pi / wavelength
        for j in range(n_pigs):
            for k in range(n_pigs):
                r = pigs[j].pos - pigs[k].pos
                # NumPy cross product function is super slow for small arrays
                # so we do it by hand for >10x speedup.
                mu_cross = np.empty(3)
                mu_cross[0] = pigs[j].mu[1] * pigs[k].mu[2] - pigs[j].mu[2] * pigs[k].mu[1]
                mu_cross[1] = pigs[j].mu[2] * pigs[k].mu[0] - pigs[j].mu[0] * pigs[k].mu[2]
                mu_cross[2] = pigs[j].mu[0] * pigs[k].mu[1] - pigs[j].mu[1] * pigs[k].mu[0] 
                stick_cd[i] += e_vecs[j, i] * e_vecs[k, i] * np.dot(r, mu_cross)
        stick_cd[i] *= stick_coeff
    out = {
        "ham_deleted": ham,
        "pigs_deleted": pigs,
        "e_vals": e_vals,
        "e_vecs": e_vecs,
        "exciton_mus": exciton_mus,
        "stick_abs": stick_abs,
        "stick_cd": stick_cd
    }
    return out
```
Even to my eyes it's not immediately obvious where the bottleneck would be in this function. In order to continue looking for the bottleneck we'll use another tool: `line_profiler`. A flamegraph tells you which function is slow, but not *what about it* is slow. That's where `line_profiler` comes in as it annotates each line with its fraction of the runtime of the function. Running `line_profiler` on `make_stick_spectrum` generates this report:

{% details(summary="Click here to expand the report") %}
```
Timer unit: 1e-06 s

Total time: 0.010513 s
File: /Users/zmitchell/code/research/fmo_analysis/fmo_analysis/exciton.py
Function: make_stick_spectrum at line 37

Line #      Hits         Time  Per Hit   % Time  Line Contents
==============================================================
    37                                           def make_stick_spectrum(config: Config, ham: np.ndarray, pigs: List[Pigment]) -> Dict:
    38                                               """Computes the stick spectra and eigenvalues/eigenvectors for the system."""
    39         1          8.0      8.0      0.1      ham, pigs = delete_pigment(config, ham, pigs)
    40         1          2.0      2.0      0.0      n_pigs = ham.shape[0]
    41         1          4.0      4.0      0.0      if config.delete_pig > n_pigs:
    42                                                   raise ValueError(f"Tried to delete pigment {config.delete_pig} but system only has {n_pigs} pigments.")
    43         1        768.0    768.0      7.3      e_vals, e_vecs = np.linalg.eig(ham)
    44         1         32.0     32.0      0.3      pig_mus = np.zeros((n_pigs, 3))
    45         1          5.0      5.0      0.0      if config.normalize:
    46                                                   total_dpm = np.sum([np.dot(p.mu, p.mu) for p in pigs])
    47                                                   for i in range(len(pigs)):
    48                                                       pigs[i].mu /= total_dpm
    49         8         36.0      4.5      0.3      for i, p in enumerate(pigs):
    50         7         63.0      9.0      0.6          pig_mus[i, :] = pigs[i].mu
    51         1         46.0     46.0      0.4      exciton_mus = np.zeros_like(pig_mus)
    52         1          3.0      3.0      0.0      stick_abs = np.zeros(n_pigs)
    53         1          3.0      3.0      0.0      stick_cd = np.zeros(n_pigs)
    54         8         12.0      1.5      0.1      for i in range(n_pigs):
    55         7        478.0     68.3      4.5          exciton_mus[i, :] = np.sum(np.repeat(e_vecs[:, i], 3).reshape((n_pigs, 3)) * pig_mus, axis=0)
    56         7         84.0     12.0      0.8          stick_abs[i] = np.dot(exciton_mus[i], exciton_mus[i])
    57         7         10.0      1.4      0.1          energy = e_vals[i]
    58         7         23.0      3.3      0.2          if energy == 0:
    59                                                       # If the energy is zero, the pigment has been deleted
    60                                                       energy = 100_000
    61         7         14.0      2.0      0.1          wavelength = 1e8 / energy  # in angstroms
    62         7         15.0      2.1      0.1          stick_coeff = 2 * np.pi / wavelength
    63        56        102.0      1.8      1.0          for j in range(n_pigs):
    64       392        689.0      1.8      6.6              for k in range(n_pigs):
    65       343       1167.0      3.4     11.1                  r = pigs[j].pos - pigs[k].pos
    66                                                           # NumPy cross product function is super slow for small arrays
    67                                                           # so we do it by hand for >10x speedup. It makes a difference!
    68       343       1112.0      3.2     10.6                  mu_cross = np.empty(3)
    69       343       1230.0      3.6     11.7                  mu_cross[0] = pigs[j].mu[1] * pigs[k].mu[2] - pigs[j].mu[2] * pigs[k].mu[1]
    70       343        953.0      2.8      9.1                  mu_cross[1] = pigs[j].mu[2] * pigs[k].mu[0] - pigs[j].mu[0] * pigs[k].mu[2]
    71       343       1020.0      3.0      9.7                  mu_cross[2] = pigs[j].mu[0] * pigs[k].mu[1] - pigs[j].mu[1] * pigs[k].mu[0] 
    72       343       2611.0      7.6     24.8                  stick_cd[i] += e_vecs[j, i] * e_vecs[k, i] * np.dot(r, mu_cross)
    73         7         11.0      1.6      0.1          stick_cd[i] *= stick_coeff
    74         1          3.0      3.0      0.0      out = {
    75         1          1.0      1.0      0.0          "ham_deleted": ham,
    76         1          1.0      1.0      0.0          "pigs_deleted": pigs,
    77         1          1.0      1.0      0.0          "e_vals": e_vals,
    78         1          1.0      1.0      0.0          "e_vecs": e_vecs,
    79         1          1.0      1.0      0.0          "exciton_mus": exciton_mus,
    80         1          2.0      2.0      0.0          "stick_abs": stick_abs,
    81         1          1.0      1.0      0.0          "stick_cd": stick_cd
    82                                               }
    83         1          1.0      1.0      0.0      return out
```
{% end %}

This is what we learn from the report:
- 7.3% diagonalizing the Hamiltonian (line 43)
- 4.5% computing exciton dipole moments (line 55)
- 0.8% computing stick absorption (line 56)
- 77% computing stick CD (lines 65-72)

So, let's focus on computing CD!

## Optimizing CD
At this point I decided to make myself some tools. I made a script for running `line_profiler` and a script for timing the execution of a single function, then checked both of these into git so that I can reuse them at a later date without needing to reinvent the wheel.

My execution timing script boils down to this:
```python
from time import perf_counter
from fmo_analysis import exciton


def main():
    ham, pigs = ...
    n = 10_000
    times = []
    for _ in range(n):
        t_start = perf_counter()
        stick = exciton.make_stick_spectrum(config, ham, pigs)
        t_stop = perf_counter()
        times.append(t_stop - t_start)
    per_call = sum(times) / n * 1e3
    print(f"{per_call:.4f}ms per call")


if __name__ == "__main__":
    main()
```

The execution time varies from moment to moment depending on what else is running on my laptop, what's in cache, etc so the exact times should be taken with a grain of salt. Our starting point is 3.48ms per call to `make_stick_spectrum`.

### Avoiding superfluous lookups
The first thing that jumped out at me is that we're repeatedly looking up the two pigments `pigs[j]` and `pigs[k]` in the inner loop. Looking these pigments up once at the beginning of the loop e.g. `pig_j = pigs[j]` takes us from 3.48ms to 2.78ms for a 20% speedup. The CD calculation now looks like this:
```python
for j in range(n_pigs):
    for k in range(n_pigs):
        pig_j = pigs[j]
        pig_k = pigs[k]
        r = pig_j.pos - pig_k.pos
        # NumPy cross product function is super slow for small arrays
        # so we do it by hand for >10x speedup. It makes a difference!
        mu_cross = np.empty(3)
        mu_j = pig_j.mu
        mu_k = pig_k.mu
        mu_cross[0] = mu_j[1] * mu_k[2] - mu_j[2] * mu_k[1]
        mu_cross[1] = mu_j[2] * mu_k[0] - mu_j[0] * mu_k[2]
        mu_cross[2] = mu_j[0] * mu_k[1] - mu_j[1] * mu_k[0]
        # Calculate the dot product by hand, 2x faster than np.dot()
        r_mu_dot = r[0] * mu_cross[0] + r[1] * mu_cross[1] + r[2] * mu_cross[2]
        stick_cd[i] += e_vecs[j, i] * e_vecs[k, i] * r_mu_dot
```

### Skipping half of the calculations
It turns out that if you swap `j` and `k` nothing changes. Swapping `r_j` and `r_k` gives you a minus sign. Swapping `mu_j` and `mu_k` also gives you a minus sign. These two minus signs cancel out when you calculate `(r_j - r_k) * (mu_j x mu_k)`. This means we only need to calculate the CD contribution for each pair of pigments once and then double it (i.e. `2 * cd(j,k)`) rather than calculating it separately for `j,k` and `k,j` (i.e. `cd(j,k) + cd(k,j)`).
```python
for j in range(n_pigs):
    for k in range(j, n_pigs):  # Notice the "j" here now!
        pig_j = pigs[j]
        pig_k = pigs[k]
        r = pig_j.pos - pig_k.pos
        # NumPy cross product function is super slow for small arrays
        # so we do it by hand for >10x speedup. It makes a difference!
        mu_cross = np.empty(3)
        mu_j = pig_j.mu
        mu_k = pig_k.mu
        mu_cross[0] = mu_j[1] * mu_k[2] - mu_j[2] * mu_k[1]
        mu_cross[1] = mu_j[2] * mu_k[0] - mu_j[0] * mu_k[2]
        mu_cross[2] = mu_j[0] * mu_k[1] - mu_j[1] * mu_k[0]
        # Calculate the dot product by hand, 2x faster than np.dot()
        r_mu_dot = r[0] * mu_cross[0] + r[1] * mu_cross[1] + r[2] * mu_cross[2]
        # Notice the "2" here now!
        stick_cd[i] += 2 * e_vecs[j, i] * e_vecs[k, i] * r_mu_dot
```
This takes us from 2.78ms to 1.71ms for a 162% speedup.

### Skipping the diagonal
The key calculation is this `(r_j - r_k) * (mu_j x mu_k)` piece. Both `(r_j - r_k)` and `(mu_j x mu_k)` are zero if `j = k`, so we can skip those calculations entirely. This is all we need to change:
```python
for j in range(n_pigs):
    for k in range(j+1, n_pigs):  # Notice the "+1" here!
```
This takes us from 1.71ms to 1.41ms for an 18% speedup.

### Caching some computations
If you look at the `(r_j - r_k) * (mu_j x mu_k)` piece, you'll notice a distinct lack of `i`. This means we're calculating it over and over again for no reason on every iteration of the outer loop. We can calculate this part once and reuse it. The outer loop looks like this now:
```python
r_mu_cross_cache = make_r_dot_mu_cross_cache(pigs)
for i in range(n_pigs):
    exciton_mus[i, :] = np.sum(np.repeat(e_vecs[:, i], 3).reshape((n_pigs, 3)) * pig_mus, axis=0)
    stick_abs[i] = np.dot(exciton_mus[i], exciton_mus[i])
    energy = e_vals[i]
    if energy == 0:
        # If the energy is zero, the pigment has been deleted
        energy = 100_000
    wavelength = 1e8 / energy  # in angstroms
    stick_coeff = 2 * np.pi / wavelength
    e_vec_weights = make_weight_matrix(e_vecs, i)
    stick_cd[i] = 2 * stick_coeff * np.sum(e_vec_weights * r_mu_cross_cache)
```
where `make_r_mu_cross_cache` and `make_weight_matrix` look like this:
```python
def make_r_dot_mu_cross_cache(pigs):
    """Computes a cache of (r_i - r_j) * (mu_i x mu_j)"""
    n = len(pigs)
    cache = np.zeros((n, n))
    for i in range(n):
        for j in range(i+1, n):
            r_i = pigs[i].pos
            r_j = pigs[j].pos
            r_ij = r_i - r_j
            mu_i = pigs[i].mu
            mu_j = pigs[j].mu
            mu_ij_cross = np.empty(3)
            mu_ij_cross[0] = mu_i[1] * mu_j[2] - mu_i[2] * mu_j[1]
            mu_ij_cross[1] = mu_i[2] * mu_j[0] - mu_i[0] * mu_j[2]
            mu_ij_cross[2] = mu_i[0] * mu_j[1] - mu_i[1] * mu_j[0]
            cache[i, j] = r_ij[0] * mu_ij_cross[0] + r_ij[1] * mu_ij_cross[1] + r_ij[2] * mu_ij_cross[2]
    return cache


def make_weight_matrix(e_vecs, col):
    """Makes the matrix of weights for CD from the eigenvectors"""
    n = e_vecs.shape[0]
    mat = np.zeros((n, n))
    for i in range(n):
        for j in range(i+1, n):
            mat[i, j] = e_vecs[i, col] * e_vecs[j, col]
    return mat
```
This takes us from 1.41ms to 0.94ms for a 33% speedup.

### Letting NumPy take control
The more you can keep execution in C and out of Python, the faster your program is going to run. In practice this means letting NumPy do iteration for you and apply functions to entire arrays since it can iterate and apply functions in C, which is much faster. Consider this example:
```python
np.sum(e_vec_weights * r_mu_cross_cache)
```
Both `e_vec_weights` and `r_mu_cross_cache` are matrices and what I'm doing here is multiplying them together elementwise, which creates a new array containing the product, then summing the elements of that new matrix. There's another operation similar to this called the "dot product" or "inner product", but in order to get a single number out of it you need two 1D arrays. Luckily there's a built-in method to do this (`flatten`), and since these two matrices are the same shape I know they'll be flattened such that corresponding elements line up, exactly how I need them such that I can compute the dot product:
```python
np.dot(e_vec_weights.flatten(), r_mu_cross_cache.flatten())
```
This is roughly 3x faster than the previous method shown above. It's not a big speedup overall in this program, but I thought it would be instructive anyway!

This small change takes us from 0.94ms to 0.91ms for a 3% speedup.

## Calling LAPACK routines directly
At this point the breakdown of execution time looks like this:
- 50% computing eigenvalues and eigenvectors
- 16% making the cache
- 9% making the weights to go along with the cache
- 10% computing the exciton dipole moments

Calculating CD no longer dominates the execution time, so I moved my focus to diagonalization. I knew that my Hamiltonian matrix was [symmetric](https://en.wikipedia.org/wiki/Symmetric_matrix), so I wondered if there were diagonalization algorithms that could take advantage of this. Fortunately NumPy has one built in: `eigh`. Unfortunately it didn't seem to make much of a difference (within measurement error on my laptop). I suspect that there may be a bigger difference on a larger matrix.

I wondered again whether NumPy was adding some overhead. One of the things that makes NumPy so fast is that parts of it are wrappers around [LAPACK](https://en.wikipedia.org/wiki/LAPACK) and [BLAS](https://en.wikipedia.org/wiki/Basic_Linear_Algebra_Subprograms), which are industry standard libraries for efficient linear algebra algorithms and operations respectively. In order to test out this hypothesis I decided to call the LAPACK diagonalization routine directly as made available by the `scipy.lapack` module. The LAPACK routine used by `eig` is called SGEEV. Yeah, it's cryptic.

A tricky detail here is that LAPACK is written in FORTRAN, so it consumes and returns arrays with FORTRAN-ordering (column-major) rather than C-ordering (row-major), so you need to handle conversion between the two. Fortunately my Hamiltonian is symmetric so the FORTRAN ordering is actually identical to the C-ordering. This isn't the case for the return values, though.

This is what the new diagonalization code looks like:
```python
e_vals_fortran_order, _, _, e_vecs_fortran_order, _ = lapack.sgeev(ham)
e_vals = np.ascontiguousarray(e_vals_fortran_order)
e_vecs = np.ascontiguousarray(e_vecs_fortran_order)
```

This takes us from 0.91ms to 0.85ms for a 7% speedup.

At this point we've managed to reduce the execution time from 3.48ms to 0.85ms for a 4x speedup. The goal is 100x, so we're missing our target by 25x. That's a lot of x's and I'm running out of NumPy-fu. It's time to call in the big guns.

## Rust rewrite
I know it's a meme at this point, but I decided to rewrite it in Rust. I've taken a break from Rust for a while (nothing against the language, just haven't needed it), but I've used it on and off since 2015. I was already looking for a reason to write a Python-extension. I have a programming bucket-list and writing a Python-extension is on there (just for fun). There are four crates that make this possible:
- [PyO3](https://github.com/PyO3/pyo3), for Rust/Python interop
- [maturin](https://github.com/PyO3/maturin), for interacting with your extension during development and eventually publishing it to PyPI
- [ndarray](https://github.com/rust-ndarray/ndarray), Rust's equivalent to NumPy
- [rust-numpy](https://github.com/PyO3/rust-numpy), for converting NumPy objects to ndarray arrays.

Honestly, the Python interop was shockingly easy. I wouldn't even know how to begin doing this with C. It's not without friction, but that's mostly a documentation issue. For instance, I had trouble putting my Rust source alongside my Python source in my Python package and having it build properly when I use `poetry` to build my Python package. The documentation makes it sound like this is the preferred method, but I was short on time and ended up just making a separate package, [ham2spec](https://github.com/savikhin-lab/ham2spec), so that I could upload it to PyPI and have it downloaded and installed like any other dependency. I shouldn't have to build and upload my Rust extension to a server somewhere to get it picked up properly as a dependency of my local project, but here we are. I was rushed to get this working, so it's entirely possible I missed something simple.

That aside, this is what the development process looks like:
- Create a new project with `maturin new`
- Write your Rust code
- Package it up and expose it to Python locally with `maturin develop`
- Fire up a Python interpreter and play around with your module to give things a cursory glance
- Repeat
- Publish your module with `maturin publish`

There was some trial and error around converting between Rust types and Python types, and I still don't have a good mental model for how the interop works. There's also some interior mutability magic happening. Take this for instance:
```rust
let dict = PyDict::new();
let bar = 42;
dict.set_item("foo", bar).unwrap();
```
Setting the value of `"foo"` is clearly a mutating operation, but we haven't declared `dict` as `mut`. Interior mutability isn't unheard of in Rust (see [this section](https://doc.rust-lang.org/book/ch15-05-interior-mutability.html) of The Book) but it makes it hard to understand the rules of the game when you're already fumbling around.

I also decided to interface with LAPACK directly via the [lapack](https://github.com/blas-lapack-rs/blas-lapack-rs.github.io/wiki) crate. I have one use of `unsafe` in my crate and it's the call to `sgeev`. I'm ok with that.

The Rust code just does the number crunching, so I've left all the glue code in Python for convenience. The Rust code is a pretty direct translation from the Python code. I had an inkling from the beginning that I would need to write the number crunching code in Rust, but the algorithmic optimizations were easier to implement in Python first so I tried those out before writing anything in Rust. The only real deviations are the use of all the nice iterators that Rust provides, especially the `Zip` iterator that ndarray provides for iterating over multiple arrays in lock-step. With Rust you also have more control over where memory allocations happen, so just by having that control I've probably unconsciously avoided some allocations in hotspots without trying too hard.

This direct translation executes in 35us for a total speedup of \~100x, but there's a bit of a catch. The Rust code takes 3 arrays as arguments (8x8 Hamiltonian, 8x3 dipole moments, 8x3 positions), whereas the previous Python function is called with an 8x8 array for the Hamiltonian and a list of `Pigment` objects, which are each just containers for a position and a dipole moment array. Doing the conversion to arrays brings the execution time to 45us. I'm still counting this as a win since I don't *have* to do this conversion, I'm just doing it to preserve backwards compatibility with a bunch of simulations I've already written.

Just for kicks I decided to profile `ham2spec` to see if there was any low-hanging fruit for optimization. In order to do this I had to create a crate example since my crate is a library, not a binary, and examples get compiled into their own binaries. I made this example and profiled it with `cargo-flamegraph`. The profiling output showed that the runtime of `compute_stick_spectrum` (my Rust equivalent of the `make_stick_spectrum` function from my Python code) looked like this:
- 45% diagonalization
- 23% computing exciton dipole moments
- 24% computing CD

If I could somehow magically eliminate my own calculations entirely and let diagonalization dominate the execution time I would only make this function \~2x faster. I already know that we've eliminated the stick spectrum bottleneck, so this isn't worth it.

The only thing left to do is make sure the output of the new code and old code match up...

## Matching outputs
It's at this point that I must make a confession. I haven't been eating my vegetables. Well, I have, like I said I'm a vegetarian. What I really mean is that I didn't have a test suite for either `fmo_analysis` or `ham2spec`. I know, blasphemy.

I'm the last person you need to convince about writing tests. I've [given talks](https://www.youtube.com/watch?v=RdpHONoFsSs&list=PLgC1L0fKd7UkVwjVlOySfMnn80Qs5TOLb&index=9) about esoteric testing techniques. I've also [written about](https://tinkering.xyz/polsim/#testing) the need for better testing in scientific software. So, how did we get here?
- Burnout. Graduate school is hard. Doing anything that doesn't directly move you towards graduation has a high activation energy.
- I'm the only person on the planet using this software, so I'll just run into all the bugs myself and fix them. Right?
- I was given the original simulation implementation as a single large script, so I wrote `fmo_analysis` partly to organize things for my own understanding of what the original code did.
- This started as a small CLI that I threw together and it quickly grew beyond that scope.
- My dog ate my test suite.

Suffice to say that now I have test suites for both `fmo_analysis` and `ham2spec`, but let's talk about how I got there.

### The problem
I ran my fitting script again and noticed that the `"function output"` value, which tells you the value of the function you're trying to minimize, was much worse than before. This means that the match between my fitted spectra and the experimental spectra was much worse. My fitting script spits out a plot for visual comparison, so I pulled that up and they didn't match at all. *Oh no*.

I decided I would compare three versions of `fmo_analysis`:
- A known-good version before I started optimizing
- The last pure-Python version
- The current Rust/Python version

I decided I would compare these using `git-worktree`, though in hindsight I could have also used something like `git-bisect`. I first learned about `git-worktree` from [a post by Hillel Wayne](https://www.hillelwayne.com/post/cross-branch-testing/). In short `git-worktree` lets you create an entire directory structure from a given commit, branch, etc via hard-links to objects in your git repository. I created a script to compute spectra using each version, saving both intermediate and final results so that I could compare outputs step-by-step. Then I created another script to compare the various outputs of the stick spectrum computation.

### Diagonalization
I first checked to make sure the eigenvalues and eigenvectors matched up, since that was a calculation I wasn't responsible for and thus was unlikely to mess up on my own. The eigenvalues matched up, which was reassuring. The eigenvectors, however, did not match up.

The eigenvectors initially appeared totally jumbled, but eventually I realized that they were transposed, some rows had the opposite sign, and the absolute values were only the same up to a certain number of decimal places. The transposition wasn't entirely unexpected. I wasn't very confident that I had converted between F-ordering and C-ordering correctly.

{% details(summary="Aside: converting between orderings") %}
In both NumPy and ndarray the array consists of a few pieces of information:
- The buffer containing the actual data
- The dimensions of the array
- The strides, or "how many elements do I have to traverse in the buffer to get to the next item along a particular axis"

You can see that [here in ndarray](https://github.com/rust-ndarray/ndarray/blob/307234e71dac87d72d7c1d955ed9f68e5e902623/src/lib.rs#L1285) and [here in NumPy](https://numpy.org/devdocs/reference/c-api/types-and-structures.html#c.PyArrayObject).

When you ask for the transpose of an array (swapping the rows and columns) it's these dimensions and strides that are modified, not the underlying data. For instance, this is how `ndarray::ArrayBase::reversed_axes` is implemented:
```rust
/// Transpose the array by reversing axes.
///
/// Transposition reverses the order of the axes (dimensions and strides)
/// while retaining the same data.
pub fn reversed_axes(mut self) -> ArrayBase<S, D> {
    self.dim.slice_mut().reverse();
    self.strides.slice_mut().reverse();
    self
}
```
This is a good idea because the data structures for dimensions and strides are small and quickly modified, whereas copying the contents of the array into a new array in a different order is comparitively much slower. In order to actually transpose the data in the buffer you have to do this:
```rust
let transposed = my_arr
    .reversed_axes()
    .as_standard_layout()  // Returns a CowArray (Cow = copy-on-write)
    .to_owned();  // Necessary to get an owned array
```
{% end %}

My dad is an electrical engineer and always told me "when in doubt, test the test." Eventually I remembered that and checked how I was saving the (allegedly "known-good") eigenvectors and discovered my mistake.

Early on in the design of `fmo_analysis` I decided that I would add an option save all of the data spit out when I compute a stick spectrum in case I needed diagnostics at some point in the future (like right now). This includes the eigenvalues, eigenvectors, exciton dipole moments, stick absorption, and stick CD. The pigment positions, pigment dipole moments, and exciton dipole moments are stored one per row, so I thought I would be consistent and save the eigenvectors one per row as well. This is transposed relative to how the eigenvectors are returned by `np.eig`.

Well, I forgot I did that because this is the first time I've ever had to look at this diagnostic data (usually it only exists long enough to use it to compute a broadened spectrum). This is akin to leaving your keys in a special spot so that you don't forget them, and then spending 20 minutes looking for your keys because they aren't where you normally leave them.

This explains the transposition, but entire eigenvectors still have the wrong sign! I really went down a rabbit hole on this one. On top of that it was all three versions that had different signs! To save time I'll just list the things I investigated:
- Am I actually passing the same matrix to each version?
- Are the matrices all `float32`s?
- Can I get the `np.eig` and `scipy.lapack.sgeev` versions to match?
- Are NumPy and SciPy using the same LAPACK libraries?
- Am I taking the "right-eigenvectors" i.e. not the "left-eigenvectors"

After pulling out a sufficient amount of my own hair I finally [posted an issue](https://github.com/scipy/scipy/issues/15350) on the SciPy repository asking why I get different signs using `np.eig` and `scipy.lapack.sgeev` even though they use the same `_geev` routine under the hood.

The answer, of course, is that they don't use the same routine under the hood. It turns out that `np.eig` automatically converts its input to `float64` before diagonalization, diagonalizes with `dgeev` (`sgeev` is 32-bit, `dgeev` is 64-bit) and then converts the result back to the original data type. Also, eigenvectors are only unique up to a sign, so a flipped sign isn't "wrong" and can be caused by small fluctations in intermediate calculations (such as differences in precision). It's been almost a decade (*woof*) since I took a linear algebra class, so this detail has lost to the sands of time in my memory. Furthermore, the sign flips don't change the spectra.

Once I converted all three versions to 64-bit computations the absolute values all started matching. Signs may still flip, but now I account for this in my tests. 

Had you asked me beforehand "what is the best way to migrate a calculation from an old version to a new version" I probably would have told you something like this (what I *didn't* do):
- Verify that the existing version does what you expect
- Make some validation data to compare the new version against
- Work incrementally, validating each piece before continuing on to the next

Why didn't I do that? Well, for much of this process I was just *in the zone*, cranking out code without much rigor. I also had a reference implementation that I was essentially translating, so I was confident that there wasn't much that could go wrong. That confidence was misplaced, obviously. Now that I have first hand experience with lost time doing things the sloppy way rest assured that it won't happen again.

## Broadened spectra
Once everything was *correct*, I got back to work optimizing. My stick spectrum computations were 100x faster, so it was time to look at how that translated to computing a broadened spectrum. As a refresher, computing a broadened spectrum looks like this:
- Compute the stick spectrum from a Hamiltonian
- Compute a broadened spectrum from a stick spectrum

I timed the execution of the `known_good` system computing a spectrum from 100 Hamiltonians and it took 381ms. It's no wonder that a fit takes forever when each iteration of the minimization routine takes almost 400ms.

Then I timed the execution of the new system doing the same computation and it took 40ms. That's only 10x faster! My stick spectrum computations were 100x faster than the old version, so why is this so much slower? As a reminder, this was the original breakdown of execution time:
- 87.5% `make_stick_spectrum`
- 10% `make_broadened_spectrum`

If you could somehow magically eliminate the execution time of everything except for `make_broadened_spectrum` you would get at best a 10x speedup. We effectively *did* elminate the execution time of everything else, so we're seeing exactly that 10x speedup we would expect. So, how do we make it faster?

### Making it parallel
The process of computing a broadened spectrum from each Hamiltonian falls into the category of [embarrassingly parallel](https://en.wikipedia.org/wiki/Embarrassingly_parallel), so we don't even need to do much work to make this parallel. I literally changed a `for_each` to a `par_for_each`:
```rust
Zip::from(abs_arr.columns_mut())
    .and(cd_arr.columns_mut())
    .and(hams.axis_iter(Axis(0)))
    .and(mus.axis_iter(Axis(0)))
    .and(rs.axis_iter(Axis(0)))
    .par_for_each(|mut abs_col, mut cd_col, h, m, r| { // <-- parallel iteration here!
        let stick = compute_stick_spectrum(h, m, r);
        let broadened = compute_broadened_spectrum_from_stick(
            stick.e_vals.view(),
            stick.stick_abs.view(),
            stick.stick_cd.view(),
            config,
        );
        abs_col.assign(&broadened.abs);
        cd_col.assign(&broadened.cd);
    });
}
```

This brought the execution time from 40ms to 17.6ms for a 227% speedup. My puny laptop only has 2 cores (but it does have Hyper-threading), so this is in the ballpark of what I would expect. I do have a new 16" Macbook Pro on the way with many more cores to throw at this, so we'll see if I get linear scaling with the number of cores or not.

At this point we're still only 22x faster than the original execution time of 381ms for computing a broadened spectrum from 100 Hamiltonians.

### Doing less work
I ran `cargo-flamegraph` on an example calculation and it showed that calls to `exp` account for 55% of the execution time. On one hand, that's not a function I can make faster by modifying its code, so that's discouraging. On the other hand it means that most of the execution time is spent doing calculations and nothing too weird.

I remember reading a post or a comment somewhere from Andrew Gallant, the original brain behind [ripgrep](https://github.com/BurntSushi/ripgrep), that said something along the lines of "one of the easiest ways to make a program faster is to make it do less work." That's always stuck with me. How does it apply here?

We're placing a Gaussian on top of each stick in the stick spectrum, but the contribution from each Gaussian diminishes as you get further away from the peak. If you get far enough away from the peak, the contributions become vanishingly small. If that's the case, why do those calculations at all?

I decided that instead of computing each Gaussian for all x-values in the domain I would only compute each Gaussian within a user-configurable range of the peak.
```rust
/// Determine the indices for which you actually need to compute the contribution of a band
pub fn band_cutoff_indices(center: f64, bw: f64, cutoff: f64, xs: &[f64]) -> (usize, usize) {
    let lower = xs.partition_point(|&x| x < (center - cutoff * bw));
    let upper = xs.partition_point(|&x| x < (center + cutoff * bw));
    (lower, upper)
}

/// Computes the band and adds it to the spectrum
pub fn add_cutoff_bands(
    mut spec: ArrayViewMut1<f64>,
    energies: ArrayView1<f64>,
    stick_strengths: ArrayView1<f64>,
    bws: &[f64],
    cutoff: f64,
    x: ArrayView1<f64>,
) {
    Zip::from(energies)
        .and(stick_strengths)
        .and(bws)
        .for_each(|&e, &strength, &bw| {
            let denom = gauss_denom(bw);
            let (lower, upper) = band_cutoff_indices(e, bw, cutoff, x.as_slice().unwrap());
            let band = x
                .slice(s![lower..upper])
                .mapv(|x_i| strength * (-(x_i - e).powi(2) / denom).exp());
            spec.slice_mut(s![lower..upper]).add_assign(&band);
        });
}
```

This takes us from 17.6ms to 10ms with a cutoff of 3 for a 176% speedup. Now we're sitting at 38x faster than the original.

### Making it more efficient
I'm reaching the end of my expertise, but I still had a couple of ideas:
- Can I optimize the layout of the data to reduce cache misses?
- Can I take advantage of instruction-level parallelism?
- Does the assembly reveal anything weird?

Some of you are probably shouting "SIMD! Use SIMD!", and I hear you. The thing is I barely know how to use SIMD on x86 and I'm about to get an Apple Silicon (Arm-based) Macbook Pro, and I know next to nothing about NEON. Furthermore, I don't want to support functionality that depends on which architecture it's operating on, and I especially don't want to hand that maintenance off to the next graduate student to come along who may or may not even know how to program. 