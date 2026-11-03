# homebrew-tap

Speedscale formulae for [Homebrew](https://brew.sh)

## Installation

`brew install speedscale/tap/<formula>`

Or `brew tap speedscale/tap` and then `brew install <formula>`.

## Validation

Run `python3 test/proxymock_wrapper_test.py` with Homebrew on your PATH. The tests evaluate the proxymock formula with isolated installation paths and a fixture executable, then check installation, upgrade, argument forwarding and exit status. They never initialize the installed CLI or change your agent settings or keychain.
