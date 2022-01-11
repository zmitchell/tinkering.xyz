+++
title = "Interacting with Assembly in Rust"
date = 2020-08-31
draft = false
[extra]
show_date = true
+++

Note: I originally wrote this article for LogRocket. You can find the original [here](https://blog.logrocket.com/interacting-with-assembly-in-rust/).

For many Rust developers the process of producing a binary from their Rust code is a straightforward process which doesn’t require much thought. However, modern compilers are complicated programs in and of themselves, and may yield binaries that perform very differently in response to a minor change in the source code. In diagnosing performance issues like this, inspecting the output of the compiler can be helpful. The Rust compiler is able to emit various types of output, one of which is assembly. Rust also has facilities for embedding assembly. In this article you’ll learn about tools provided by the language and the community for extracting and embedding assembly.


## Viewing assembly

To view the assembly output of various tools we’ll use the following example program:

```rust
const NAMES: [&'static str; 10] = [
    "Kaladin", "Teft", "Drehy", "Skar", "Rock", "Sigzil", "Moash", "Leyten", "Lopen", "Hobber",
];

fn main() {
    roll_call();
}

pub fn roll_call() {
    println!("SOUND OFF");
    for name in NAMES.iter() {
        println!("{}: HERE!", name);
    }
    let num_present = NAMES.len();
    println!("All {} accounted for!", num_present);
}
```

### rustc
The quickest and easiest way to generate assembly is with the compiler itself. This method doesn’t require installing any additional tools, but the output can be difficult to navigate. `rustc` can emit assembly with the `--emit asm`  option (documentation). To format the output with Intel syntax (instead of the default AT&T syntax) you can also pass the `-C llvm-args=-x86-asm-syntax=intel` option to `rustc`. However, it’s more common to interact with `cargo` than with `rustc` directly. You can pass this option to `rustc` in one of two ways:
```
$ cargo rustc -- --emit asm -C llvm-args=-x86-asm-syntax=intel
$ RUSTFLAGS="--emit asm -C llvm-args=-x86-asm-syntax=intel" cargo build
```

The assembly will be placed in `target/debug/deps/<crate name>-<hash>.s` (if compiled in release mode it will be under `target/release`). The assembly file contains all the assembly for the crate and can be hard to navigate.

### Godbolt Compiler Explorer
A simple way to examine short snippets of code is to run it through the Godbolt Compiler Explorer. This tool is a web application, and as such doesn’t require installation of any additional tools. Code entered in the left pane is compiled to assembly and displayed in the right pane. The code entered in the left pane acts like it’s inside of the `main` function, so you don’t need to enter your own `main` function. 

Sections of the code in the left pane are color coded so that the assembly in the right pane can be easily identified. For example, entering the `roll_call` function and `NAMES` array into the left pane displays the following view of the `roll_call` function.

![](/images/roll-call.png)

We can identify the assembly corresponding to the `println!("SOUND OFF")` macro by right-clicking that line and selecting “Reveal linked code” or by searching for the assembly that’s highlighted in the same color.

![](/images/roll-call-asm.png)

### cargo-asm
`cargo-asm` is a Cargo subcommand (found here) that displays the assembly for a single function at a time. The beauty of this tool is its ability to resolve symbol names and display the source code interleaved with the corresponding assembly. Note, however, that `cargo-asm` appears to only work with library crates. Put the `NAMES` array and `roll_call` function into a library crate called `asm_rust_lib` then call `cargo-asm` as follows (note: the `--rust` option interleaves the source code as this is not the default).
```
$ cargo asm --rust asm_rust_lib::roll_call
```

The first few lines of the output should look appear as follows.

![](/images/roll-call-rustc-asm.png)

Rust developers learning assembly may find the ability to compare unfamiliar assembly to the corresponding (familiar) Rust code particularly useful.

## Including assembly

We could always compile assembly into an object file and link that into our binary, but that adds more complexity than we’d like, especially if we only need to include a few lines of assembly. Luckily Rust provides some facilities to make this process easy, especially in simple cases.

### llvm_asm!

Until recently the official method for including inline assembly into Rust code was the `asm!` macro, and required Rust nightly. This macro was essentially a wrapper around LLVM’s inline assembler directives. This macro has been renamed to `llvm_asm!` while a new `asm!` macro is worked on in Rust nightly, but a nightly compiler is still required to use `llvm_asm!`.

The syntax for the macro is as follows:
```
llvm_asm!(assembly template
   : output operands
   : input operands
   : clobbers
   : options
   );
```

The “assembly template” section is a template string that contains the assembly. The input and output operands handle how values should cross the Rust/assembly boundary. The “clobbers” section lists which registers the assembly may modify to indicate that the compiler shouldn’t rely on values in those registers remaining constant. The “options” section, as you can imagine, contains options, notably the option to use Intel syntax. Each section of the macro requires a specific syntax, so it’s highly recommended to read the documentation for more information.

Note that using the `llvm_asm!` macro requires an `unsafe` block since assembly bypasses all of the safety checks normally provided by the compiler.

### asm!

The new `asm!` macro provides a nicer syntax for using inline assembly than the `llvm_asm!` macro. An understanding of LLVM inline assembler directives is no longer necessary, and the documentation is extensive compared to that of `llvm_asm!`. The new syntax is closer to the normal format string syntax used with the `println!` and `format!` macros while still allowing the Rust/assembly boundary to be crossed with precision. Consider the small program shown below.

```rust
let mut x: u64 = 3;
unsafe {
    asm!("add {0}, {number}", inout(reg) x, number = const 5);
}
```

The `inout(reg) x` statement indicates that the compiler should find a suitable general purpose register, prepare that register with the current value of `x`, store the output of the `add` instruction in the same general purpose register, then store the value of that general purpose register in `x`. The syntax is nice and compact given the complexity of crossing the Rust/assembly boundary.

## Conclusion

Assembly is a language that many developers don’t use on a daily basis, but it can still be fun and educational to see how code manipulates the CPU directly. A debugger wasn’t mentioned above, but modern debuggers (GDB, LLDB) also allow you to disassemble code and step through it instruction by instruction. Armed with the tools above and a debugger, you should be able to explore the assembly that your code is translated into in a multitude of ways.
