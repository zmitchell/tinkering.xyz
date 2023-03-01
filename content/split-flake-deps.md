+++
title = "Nix journey part 2: Flake dev-time, build-time, and run-time dependencies"
date = 2023-12-31
draft = true
description = "You might need a different set of dependencies at dev-time, build-time, and run-time. In Docker you would handle this via multi-stage builds. How do you make this work with Nix flakes? Let's find out!"
[extra]
show_date = true
+++

<!-- What does buildInputs represent? -->
<!-- What does nativeBuildInputs represent? -->
<!-- What does propagatedBuildInputs represent? -->
<!-- What's the difference between host, build, and target? -->

[cross_compilation]: https://nixos.org/guides/cross-compilation.html
[dependencies]: https://nixos.org/manual/nixpkgs/stable/#ssec-stdenv-dependencies