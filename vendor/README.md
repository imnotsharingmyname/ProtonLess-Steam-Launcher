# Vendored dependencies

## cJSON

Tracked in this repo as `cJSON.c` and `cJSON.h`. MIT. Used only by the signature
database loader.

## Dobby

Not tracked. `.gitignore` ignores `vendor/dobby/`, so a fresh checkout has to fetch
it before `make dobby` will work:

    git clone https://github.com/jmpews/Dobby.git vendor/dobby
    git -C vendor/dobby checkout 5dfc8546954ce3b3198132ab13fddb89ee92cdd7

That commit is `Fixup typo`, 2024-03-14, and is the revision every measurement in
this project was taken against. Apache-2.0.

Dobby is pinned rather than tracked at a moving `main` because the inline hook
trampolines are architecture-specific and a newer revision changes code generation.
Do not advance the pin without a good reason as well as verifying that hooks still
install on a supported Steam version.

Build it with `make dobby`. The libraries land in `build/dobby/` and the top-level
`Makefile` links them from there.
