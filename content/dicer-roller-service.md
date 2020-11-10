+++
title = "How to build a dice roller service in Rust"
date = 2020-04-29
draft = false
[extra]
show_date = true
+++

Note: I originally wrote this article for LogRocket. You can find the original [here](https://blog.logrocket.com/how-to-build-a-dice-roller-in-rust/).

Let’s get this out of the way: I’m a huge Dungeons & Dragons nerd. There’s something special about getting a bunch of adults in a room together to play pretend. 

Most of D&D involves using your imagination to make choices for your character, but the outcomes of some actions are determined by dice rolls. For instance, if you want to take a mighty swing at a goblin with your longsword, first you need to roll to see if you hit. You roll a twenty-sided dice (d20), add some numbers to your roll, and the Dungeon Master tells you whether you hit. If you hit, you roll more dice to determine how much damage you do. If, for example, you roll a 20 on your d20 when trying to hit, that means you’ve landed a critical hit, which inflicts a bunch of extra damage.

Where am I going with this? In this tutorial, I'll demonstrate how to create a web service to roll these dice for you when you visit a certain URL. This will be a relatively basic project suitable for experienced programmers who are new to Rust.


## Getting started

We’ll use Rocket for our web service. Although it uses nightly Rust rather than stable Rust, it’s easy to use and should work just fine. 

To begin, make sure you have nightly Rust installed.
```
$ rustup toolchain install nightly
```

Next, create a `cargo` project called `roll-server`.
```
$ cargo new roll-server
```

Make nightly Rust the default just for this project.
```
$ cd roll-server
$ rustup override set nightly
```

Add Rocket to your `Cargo.toml` and disable the default features. At the time of writing, there is a bug in one of its dependencies (`ring`) that prevents Rocket from building.
```toml
[dependencies]
rocket = { version = "0.4.4", default-features = false }
```

Next, modify your `main.rs` to look like the example from Rocket’s “Getting Started” guide, just to make sure everything is working as intended.

```rust
#![feature(proc_macro_hygiene, decl_macro)]
#[macro_use] extern crate rocket;

fn main() {
    rocket::ignite().mount("/", routes![index]).launch();
}

#[get("/")]
fn index() -> &'static str {
    "Hello, world!"
}
```

Run the project with `cargo run`. If you visit `localhost:8000`, you should see `Hello, World!` in your browser. Now you’re ready to dig into the project.


## Routes

There are two main routes in our application: `/roll/<dice>` and `/roll/crit/<dice>`. The first rolls whatever dice you specify in the `<dice>` portion of the route. The second applies some special rules to the dice roll to calculate damage on a critical hit.

In Rocket you handle requests to certain paths by creating a function and placing an attribute on top that describes the path. For instance, to respond to the path `/foo/bar`, you would create the following function.
```rust
#[get("/foo/bar")]
fn my_handler() -> &'static str {
    "foo bar"
}
```

In our case, both the `/roll/<dice>` and `/roll/crit/<dice>` paths begin with `/roll`. Rather than explicitly write out `/roll` in each of our handlers, let’s mount the `/<dice>` and `/crit/<dice>` handlers under the `/roll` path. The skeleton of the application is as follows.

```rust
// main.rs
fn main() {
    rocket::ignite()
        .mount("/roll", routes![normal, critical])
        .launch();
}

#[get("/<dice>")]
fn normal(dice: String) -> String {
    format!("normal: {}", dice)
}

#[get("/crit/<dice>")]
fn critical(dice: String) -> String {
    format!("critical: {}", dice)
}
```

If you run the application and visit `localhost:8000/roll/foo`, you should see `normal: foo`. Likewise, if you visit `localhost:8000/roll/critical/foo`, you should see `critical: foo`.

## Parsing

Now that you can extract a string from the path, you need to do something with it. However, you can’t just accept any string as part of the path. What if the user visited `/roll/foo`? What dice would they roll? 

Instead, we’ll only accept strings that are valid dice notation. This is a compact way of representing the number and size of the dice to be rolled. The notation is of the form `<number>d<size>`, so `4d12` would represent four 12-sided dice.

To determine which strings are valid dice notation with a regular expression, add the regex crate to your `Cargo.toml`.

```toml
[dependencies]
rocket = { version = "0.4.4", default-features = false}
regex = "1"
```

Next, create the file `parse.rs`, which is where you’ll put all of your parsing logic. We’re going to parse a string like `4d6` into a struct `RollCmd` that represents the number of dice and the size of the dice.

We’ll limit the number of dice to 255 because that’s already a ton of dice and it fits nicely into a `u8`. Taking that one step further, we can recognize that it doesn’t make sense to roll zero dice, so instead we’ll parse into a `NonZeroU8`. The dice sizes are fixed numbers, so we’ll use an enum to represent the available sizes. Finally, we need a type to represent the various ways in which things can go wrong. We’ll use an `enum` for that as well.

Putting all of these pieces together, you should have the following type definitions.

```rust
// parse.rs
use std::num::NonZeroU8;

#[derive(Debug, PartialEq)]
pub(crate) enum ParseError {
    InvalidDiceNumber,
    InvalidDiceSize,
    UnableToParse,
}

#[derive(Debug, PartialEq, Copy, Clone)]
pub(crate) enum DiceSize {
    D4,
    D6,
    D8,
    D10,
    D12,
    D20,
    D100,
}

#[derive(Debug, PartialEq)]
pub(crate) struct RollCmd {
    pub num: NonZeroU8,
    pub size: DiceSize,
}
```

The next piece of the puzzle is the regular expression. Use the regex `^([1-9]\d*)d(\d+)$`. Any simpler, and you’ll allow invalid input. Any stricter, and you’ll lose information about which parts didn’t parse properly.

Let’s take a look at the finished product, then break it down into smaller pieces.

```rust
// parse.rs
pub(crate) fn parse_dice_str(dice_str: &str) -> Result<RollCmd, ParseError> {
    let dice_regex = Regex::new(r"^([1-9]\d*)d(\d+)$").unwrap();
    let caps = dice_regex.captures(dice_str).ok_or(ParseError::UnableToParse)?;
    let dice_num = caps.get(1)  // Option<Match>
        .ok_or(ParseError::InvalidDiceNumber)?  // Match
        .as_str().parse::<NonZeroU8>()  // Match -> str -> Result<NonZeroU8, Err>
        .map_err(|_| {ParseError::InvalidDiceNumber})?;  // NonZeroU8
    let dice_size = caps.get(2)
        .ok_or(ParseError::InvalidDiceSize)?
        .as_str()
        .parse::<DiceSize>()?;
    Ok(RollCmd {
        num: dice_num,
        size: dice_size
    })
}
```

First, we compiled the regex with `Regex::new`, then we unwrapped it. This skips any error handling and is generally frowned upon. I know that this regex will compile properly, so it’s OK in this case. Next we applied the regex to the string supplied by the user. We then used the `?` operator to either get the matches or immediately return an error.

The next piece is more complicated, so I annotated the types. We’ll do the same trick with the `?` operator, then try to parse the string into a `NonZeroU8`. If an error occurs, we’ll throw it away and return our own error.  Parsing the dice size is largely the same, but this time we’ll return a `ParseError` directly from `parse` by telling the compiler how to convert a string into a `DiceSize` and specifying the type of error to return if it goes wrong.

```rust
// parse.rs
use std::str::FromStr;

impl FromStr for DiceSize {
    type Err = ParseError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "4" => Ok(DiceSize::D4),
            "6" => Ok(DiceSize::D6),
            "8" => Ok(DiceSize::D8),
            "10" => Ok(DiceSize::D10),
            "12" => Ok(DiceSize::D12),
            "20" => Ok(DiceSize::D20),
            "100" => Ok(DiceSize::D100),
            _ => Err(ParseError::InvalidDiceSize)
        }
    }
}
```


## Rolling the dice

Now that we know what to roll, we can work on how to roll. We’ll use the `rand` crate to generate our random dice rolls. Go ahead and add it to your `Cargo.toml`.
```
rand = "0.7"
```

Now create a file called `roll.rs`. This is where you’ll write the code that handles the dice rolls. The dice rolls are going to be `usize`s (`NonZeroUsize` would make more sense, but the math operations are defined for `usize`). 

Here is the struct that holds the dice rolls and the functions that will generate them:

```rust
// roll.rs
#[derive(Debug, PartialEq)]
pub(crate) struct Rolls(pub Vec<usize>);

pub(crate) fn roll_normal(cmd: &RollCmd) -> Rolls {
    todo!()
}

pub(crate) fn roll_critical(cmd: &RollCmd) -> Rolls {
    todo!()
}

pub(crate) generate_rolls(cmd: &RollCmd) -> Vec<usize> {
    todo!()
}
```

The `generate_rolls` function handles all the common dice-rolling operations, then `roll_normal` and `roll_critical` do their own specific jobs. Let’s look at how the random numbers are generated.

```rust
// roll.rs
pub(crate) fn generate_rolls(cmd: &RollCmd) -> Vec<usize> {
    let mut rng = thread_rng();
    let distribution = Uniform::new_inclusive(1, usize::from(cmd.size));
    let rolls: Vec<usize> = (0..cmd.num.get())
        .map(|_| {
            distribution.sample(&mut rng).into()
        }).collect();
    rolls
}
```

This makes a random roll `cmd.num` times. The rolls are taken from a uniform probability distribution from `[1, cmd.size]`, meaning that each number on the dice is equally likely to appear. We make the rolls, collect them in a `Vec`, and return them.

If you’re paying close attention, you may have noticed the `usize::from(cmd.size)` on the third line. This operation converts a `DiceSize` into a `usize`. We tell the compiler how to do this by implementing the `From` trait.

```rust
// parse.rs
impl From<DiceSize> for usize {
    fn from(d: DiceSize) -> Self {
        match d {
            DiceSize::D4 => 4,
            DiceSize::D6 => 6,
            DiceSize::D8 => 8,
            DiceSize::D10 => 10,
            DiceSize::D12 => 12,
            DiceSize::D20 => 20,
            DiceSize::D100 => 100,
        }
    }
}
```

Once we have dice rolls, we can pass them off to `roll_normal` and `roll_critical`. For `roll_normal`, we’ll just return the dice rolls. For `roll_critical`, we’ll add a full-damage dice roll to the dice that have already been rolled (e.g., `4d6` becomes `4d6 + 24`).

```rust
// roll.rs
pub(crate) fn roll_normal(cmd: &RollCmd) -> Rolls {
    let rolls = generate_rolls(cmd);
    Rolls(rolls)
}

pub(crate) fn roll_crit(cmd: &RollCmd) -> Rolls {
    let mut rolls = generate_rolls(cmd);
    let num = usize::from(u8::from(cmd.num.get()));
    let size = usize::from(cmd.size);
    let crit = num.checked_mul(size).unwrap();
    rolls.push(crit);
    Rolls(rolls)
}
```

When we multiply the number and size of the dice, we are given back a `Result` because the multiplication can overflow. We unwrap this `Result` because our maximum number of dice, 255, and our maximum dice size, 100, can never cause this overflow.

## Responding

At this point, we’ve done all of the computation and we need to respond to the request while taking parsing errors into account. In our route handlers, we’ll return a `Result` where the `Err` will be a type that sets the HTTP status to `400 Bad Request`. Rocket has a built-in type that does this for us: `rocket::response::status::BadRequest`.

We’ll use the `?` operator again to handle errors, which means we need to tell the compiler how to convert a `ParseError` into a `BadRequest`.

```rust
// parse.rs
use rocket::response::status::BadRequest;

impl From<ParseError> for BadRequest<String> {
    fn from(p: ParseError) -> Self {
        match p {
            ParseError::InvalidDiceNumber => {
                BadRequest(Some(String::from("Number of dice must be <= 255")))
            }
            ParseError::InvalidDiceSize => BadRequest(Some(String::from(
                "Dice size must be 4, 6, 8, 10, 12, 20, or 100",
            ))),
            ParseError::UnableToParse => BadRequest(Some(String::from(
                "Unable to parse, must be of the form <number>d<size>",
            ))),
        }
    }
}
```

The `Some(foo)` in each branch sets the body of the response to `foo` so that the user has some idea what went wrong.

Next, stitch the rolls together into a string of the form.
```
1 + 2 + 3 + 4 = 10
```

You can do this with a new function called `assemble_response`.
```rust
// main.rs
fn assemble_response(rolls: &Rolls) -> String {
    let roll_str: String = rolls
        .0
        .iter()
        .map(|d| d.to_string())
        .collect::<Vec<String>>()
        .join(" + ");
    let sum_str = rolls.0.iter().sum::<usize>().to_string();
    [roll_str, sum_str].join(" = ")
}
```

We’re almost done! All we have to do is put these pieces together in our `normal` and `critical` handlers that we made way back in the beginning of the project.

```rust
// main.rs
#[get("/<dice>")]
fn normal(dice: String) -> Result<String, BadRequest<String>> {
    let cmd = parse_dice_str(dice.as_ref())?;
    let rolls = roll_normal(&cmd);
    let resp = assemble_response(&rolls);
    Ok(resp)
}

#[get("/crit/<dice>")]
fn critical(dice: String) -> Result<String, BadRequest<String>> {
    let cmd = parse_dice_str(dice.as_ref())?;
    let rolls = roll_crit(&cmd);
    let resp = assemble_response(&rolls);
    Ok(resp)
}
```

## Conclusion

Hopefully you had as much fun building this dice rolling service as I did! There’s still plenty of work to do; if you want to dive a little deeper, here are some ideas to get you started:
- Roll character stats when the user visits `/stats`, which will entail rolling `4d6` six times and dropping the lowest number from each roll
- Keep a running total of the dice that have been rolled since the server started. To do this, you’ll need to explore Rocket’s State documentation.

The code for this project is available on GitHub. If you have questions or want to submit either of the projects mentioned above, new contributors are always welcome!
