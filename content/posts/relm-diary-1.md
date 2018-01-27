+++
title = "relm Developer Diary #1"
date = 2018-01-27T14:46:04-05:00
draft = false
tags = ["rust", "relm"]
categories = []
+++

This is going to be the first of many articles discussing my contributions to `relm`. The first order of business is starting my work updating `relm`'s dependency on `syn` from 0.11.x to 0.12.x.
<!--more-->

Let's briefly discuss how some of the `relm` internals work. You stick the `#[widget]` attribute on top of an `impl Widget for Foo` block, and that whole block gets passed to a procedural macro. That macro then parses the contents of the block, looking for a `model` method, an `update` method, and a `view!` macro that describes the layout.

Some information is extracted from your definitions of the `update` and `model` methods, but the contents of the `view!` macro are not standard Rust syntax, so we have to parse that manually. Doing this manually makes it easy to accidentally let things slip by undetected, like invalid syntax, and also means that what is or isn't valid syntax isn't precisely specified.

My job is to replace that manual parsing system with something more systematic. Lucky for us, `syn` provides a trait, `Synom`, for telling `syn` how to parse custom syntax. The `syn` crate provides you with a variety of combinators (mini-parsers) that you can use to tell it how to parse your syntax. Unless you're using some kind of exotic syntax you should be able to put the combinators together like Lego blocks to build up your parser.

What's even better is the newest version of `syn` has support for tracking span information (row/column information from your code), so that you can provide targeted error messages. This is a hue benefit because the current system just sticks error messages at the `#[widget]` invocation. That's not great when your `impl` block is hundreds of lines long. By updating our dependency on `syn` we'll get the ability (this will be its own major undertaking) to provide better error messages for free!

This is all great, and I was excited to get started, but there's a big problem I haven't mentioned. The current version of `syn` as of writing this is `0.12.x`, and `relm` currently uses `0.11.x`. There was a major rewrite between those two versions, which breaks basically everything in `relm` that could possibly be broken.

So, the first order of business is updating `relm` to use the latest version of `syn`, and then I'll get to rewriting the parser. I also know that documentation is a pain point for `relm`, so I'll be documenting things as I go.

```rust
fn main() -> gtk::Button {
    let foo: i32 = 4;
    let bar = gtk::Window::new();
}
```
