+++
title = "Nix journey part 1: My grand unified theory of Nix documentation"
date = 2023-03-05
description = "Since the last post I've been in contact with some members of the Nix community with regards to joining the documentation team. From that discussion and my experience with other ecosystems I've had some ideas rolling around about what the ideal Nix documentation strategy/ecosystem would look like to me, so I'm putting those ideas in writing to start a discussion. These ideas aren't super concrete and I don't speak for anyone else, but they're my vision for how Nix documentation could better serve experienced users and onboard new ones."
+++

Since the last post I've been in contact with some members of the Nix community with regards to joining the documentation team. From that discussion and my experience with other ecosystems I've had some ideas rolling around about what the ideal Nix documentation strategy/ecosystem would look like to me, so I'm putting those ideas in writing to start a discussion and generate ideas. These ideas aren't super concrete and I don't speak for anyone else, but they're my vision for how Nix documentation could better serve experienced users and onboard new ones.

## Planning the work

I see this being a multi-stage process:
1. Take stock of the existing documentation
1. Decide on the new structure
1. Migrate existing documentation
1. Edit and improve

I think if you can plan the work and break it into manageable chunks you make it more likely that the community can pitch in with small, low-effort contributions. The heavy lifting is taking stock of the existing documentation to determine the closure of ideas that it covers. Once you know _what_ needs to be migrated, deciding _where_ to migrate it will still require effort, but it can require less effort and doesn't require as much expertise.

There's a large body of existing documentation that is underutilized because (1) people don't know that it exists and (2) some of it is impenetrable to someone who doesn't already know what it means. For that reason I believe the first priority should be reorganzing the existing documentation in a cohesive, discoverable way rather than generating new content (though there is a place for new content that I'll touch on later). During the migration each chunk of documentation can be evaluated in the context of improving the onboarding experience.

## Information architecture
I'd like to see the new documentation follow the [Diataxis][diataxis] documentation framework. This framework breaks down documentation into four categories that serve different purposes:
- Tutorials
    - Learning oriented, takes the user by the hand
- How-to guides
    - Task oriented, "follow these steps to achieve XYZ"
- Explanation
    - Understanding oriented, explain how things work and why they were designed a particular way
- Reference
    - Information oriented, factual information, specifications, CLI usage, etc

I'm not the one who came up with this idea, it's mentioned on the Documentation Team's site as well. I'm simply adding my support for moving in this direction.

In my ideal documentation world each of these sections would link to each other i.e. pages would cite their sources. Maybe this is the former academic in me, but I think it's a good thing if a tutorial mentioning a particular topic can say "learn more about how this works at this other page" or when it asks a reader to run a particular command it then says "you can see all of the command line options for this tool at this other page." I think this serves a few purposes:
- It deduplicates knowledge across the documentation, no need to repeat yourself when you can link to an explanation or reference page
- It provides a more cohesive learning experience i.e. "you don't need to visit another site to learn about XYZ, we've got a page on that over here"
- It backs up claims made in the documentation so there's less dogma and folk knowledge (e.g. "do XYZ because this reference pages states that it's required in ABC context" rather than "do this because more experienced people in the community say this is how you should do it")

## Site structure
I think all of the documentation should be under one site. This deduplicates the work to make site-wide changes to page templates, styles, names, etc. I think a single static-site generator can meet the needs of the entire documentation site with maybe one exception which I'll mention later. Another benefit of having all of the documentation under a single site is that you can give the reader a visual indicator of which section they're in, providing context to what they're reading and where they are in the Nix documentation landscape. I'm imagining a sidebar with accordians/expandable links for the different major sections (tutorials, how-to guides, explanation, and reference) with the current section being expanded.

Some of the documentation is built with `mdBook`, which is generally a good fit for reference materials (like the Nix Reference Manual), but I think it's less of a good fit when trying to integrate it into a larger site. The main benefit of `mdBook` is that it's very little effort to go from a directory of markdown files to some HTML with a navigable sidebar and everything. If you're already using a static-site generator for other things, you already have that ability.

There are other practicalities that certain static-site generators provide. I use Zola and it's super fast and has a built-in link checker that checks both internal and external links (`zola check`). I just ran the link checker for the first time and (1) holy shit I have 108 external links and (2) 4 of them are broken so I guess I have homework. With something like `zola check` congrats you now have tests for your website.

## SEO and analytics
I know someone is already shitting their pants in anger at the word "analytics", but I really, truly just want some data on which pages people find useful and which pages need work. People working on the documentation need to know where to focus their very limited (and mostly volunteered) time and effort. There are privacy-preserving options out there that collect so little information they don't even need a GDPR or cookie banner. We can have nice things, nuance being one of them.

One of the problems I see with the current documentation is SEO. Information that people can't find might as well not exist. For example, let's say I vaguely remember that the documentation for `mkShell` was in a section about "builders" ([Special Builders](https://nixos.org/manual/nixpkgs/stable/#chap-special)) and I do a search for "nix builders". My default search engine is DuckDuckGo, and the first page of search results (in order) are:
- A construction company
- A different construction company
- Nix builds as a service
- A rehosted version of a related page ([Trivial Builders](https://ryantm.github.io/nixpkgs/builders/trivial-builders/))
- The Facebook page of one of the above construction companies
- A custom home builder
- A different page from the site of one of the above construction companies
- Generic Builders - Nix Pills
- Distributed Builds - NixOS Wiki
- A review of one of the above construction companies

If I do the same search on Google the results are better, but still not good:
- A construction company
- Remote Builds - Nix Reference Manual
- Nix builds as a service
- Construction company
- Distributed Builds - NixOS Wiki
- `nixpkgs/trivial-builders.nix` on GitHub (so close Google, so close!)
- Review of a construction company
- How to Learn Nix, Part 32: Builders - Ian Henry

The page I'm looking for is not in the first page of results on either search engine. Ok, maybe my search was too obscure, but I don't think I'm being unreasonable here. Even with more precise search terms it's very common for other resources to come up before the official Nix pages. I've mentioned page templates a few times now, and I want to emphasize here that I don't mean just the appearance of the pages, but also information in `<head>` that can be used for SEO. Another benefit of all the documentation being under one site is that there's only one site to monitor for SEO.

## Open progress
I think another important aspect is to make progress visible, so the unified documentation site would start out with sections full of `WIP` pages. This serves a few purposes:
- The community can follow the progress
- The community can see that documentation is being actively worked on
- The community can see what the vision is for the structure of the documentation

If someone sees a page with a `WIP` section and they happen to know something about it, they can decide to chip in and fill in some of the details.

## Section breakdowns
This is a rough outline of some of the content that I think should belong in each section. You'll notice that I've left out two things: NixOS and flakes. I've left out NixOS because I know even less about NixOS than I do about using Nix in general. I've left out flakes because I think the structure of the documentation is orthogonal to whether flakes are experimental or here to stay. For those of you like me who are new to the Nix community, apparently there's disagreement about whether flakes are good. They seem fine to me but I don't know much about the tradeoffs.

### Tutorials
As mentioned above, this section is meant to take a reader by the hand and lead them through a learning experience. I also mentioned above that there's a certain place for new content. I think this is the place. Some of the material I think belongs here:
- Installation
- Walking a reader through their first build
- Taking a project that isn't packaged for Nix and walking through exactly how to package it

### How-to
This section is supposed to be a pragmatic, step-by-step resource for accomplishing specific tasks in practice. I think this section can draw inspiration from the NixOS Wiki. Some of the material I think belongs here:
- How to package for Nix
    - Guides for specific languages
        - Languages that have their own build systems
            - Those that generate lock files and how to leverage them
            - Those that don't generate lock files
        - Languages without a build system (C/C++)
    - Guides for integrating with language-agnostic build systems
        - Meson, Bazel, etc
    - Packaging idioms
        - `callPackage` vs alternatives
        - "import from derivation", "fixed output derivation", and other terms I don't understand
- Day-to-day development and workflows using Nix
    - Setting up a development shell
    - Hooking up an editor/IDE to a Nix environment
    - Using Nix in CI
    - Deployments using Nix
    - Building containers with Nix
- Contributing
    - Docs, Nixpkgs, etc

### Reference
This section is supposed to be very light on prose and heavy on detailed description of rules, specifications, requirements, and options. Basically this section is filled with facts that can be backed up by pointing at the implementation e.g. "this command has these options". I think much of what's in the Nix Reference Manual should go here. Some of the materials I think should go here:
- Nix language reference
- How derivations work
    - Required inputs
    - Build phases
    - How attributes are turned into environment variables and paths in the store
- Common modifications made to ensure purity
    - `$PATH`, etc
- Environment variables set in development shells

I think this section would also contain browsable, searchable API docs. A few readers of my previous post pointed out that [noogle.dev][noogle] exists, which is a site where you can _search_ the functions that are in `builtins`, `lib`, and `stdenv`. I think that's a step in the right direction, but the ability to browse is _crucial_. I'll often be looking up a particular method on Rust's `Iterator` trait only to find a new method I've never seen before. Discoverability is very, very valuable for the onboarding experience. I also think it's important for these docs to be generated from comments that live alongside the code so that they don't go stale. Some of the material I'd like to be browsable and searchable:
- API docs
    - Builtins
    - Builders
    - Fetchers
    - Stdenv
    - lib
- Nixpkgs

You might be saying "you can already search Nixpkgs". Yes, you can, but I think we can take this further in how we present the results. When search results are presented to you there can be a short description and some metadata, but I think each result should get its own page. Right now you can't link to a particular package. The dedicates package page could show more detailed information like the history of changes to this particular package. It should be quick and easy to determine which Nixpkgs revision I want to get a particular version e.g. the current version of package X is v1.5, what is the latest Nixpkgs that has v1.2.3. Maybe this is a weird way to go about this or it's showing my lack of Nix knowledge since I'm still pretty new, but this is just one example of the kind of information we could surface in individual package pages. This is also the one area where I think server-side computation would need to happen.

### Explanation
This section explains the how and why of Nix. Since this is most likely to be low-level details of how Nix works I envison calling this section "Nitty Gritty Nix". I think much of what's in Nix Pills would go here. I have less of an idea what should go here simply because I don't know many of the details of how Nix works, but here are some of the materials I think should go here:
- When and how are things added to the Nix store?
- We know everything is based on hashes, but how are the hashes computed? What are the inputs?
- Cross-compilation as a first class citizen and its impact on the language/ecosystem
    - buildInputs vs. nativeBuildInputs and propagation

## Conclusion
So, obviously this looks very different from today's Nix documentation and it would require an enormous amount of work. However, I think having a vision for how things _should_ look is important before starting any major endeavors. Do you agree with this vision? Do you think things should look wildly different? I'd love to hear your thoughts.

[diataxis]: https://diataxis.fr
[noogle]: https://noogle.dev