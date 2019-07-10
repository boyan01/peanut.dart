# What is the difference of source PEANUT.dart

Remove git environment requirements, the product file will be output to .peanutOutput

---

Do you ever want to `pub run build_runner build` into another branch? This is
your ticket.

## Install

```
$ pub global activate -sgit https://github.com/boyan01/peanut.dart.git
```

## Run

```
$ cd ~/my_dart_proj/
$ peanut
```

This will build your project into a temporary directory, and then it will update
the local `gh-pages` branch with its contents.

## Options

```console
$ peanut --help
Usage: peanut [<args>]

Arguments:
-d, --directories                The directories that should be built.
                                 (defaults to "web")

-b, --branch                     The git branch where the built content should
                                 be committed.
                                 (defaults to "gh-pages")

-c, --build-config               The configuration to use when running
                                 `build_runner`.

    --[no-]release               (defaults to on)
-m, --message                    (defaults to "Built <directories>")
    --[no-]source-branch-info    Includes the name of the source branch and SHA
                                 in the commit message
                                 (defaults to on)

    --post-build-dart-script     Optional Dart script to run after all builds
                                 have completed, but before files are committed
                                 to the repository.

    --builder-options            Builder options YAML or a path to a file
                                 containing builder options YAML.
                                 See the README for details.

    --[no-]verbose               Print more details when running.
    --dry-run                    Verifies configuration and prints commands that
                                 would be executed, but does not do any work.

-h, --help                       Prints usage information.
    --version                    Print the current version.
```

## Configuration file

You can also configure `peanut` with a configuration file. Convenient if you
have one-off settings you'd rather not time you deploy.

The `peanut.yaml` from this repository:

```yaml
# Configuration for https://pub.dev/packages/peanut
directories:
- example
```

## Examples

- https://github.com/dart-lang/sample-pop_pop_win/
  - Output: https://dart-lang.github.io/sample-pop_pop_win/
  - No custom configuration.
- https://github.com/kevmoo/pubviz
  - Output: http://kevmoo.github.io/pubviz/
  - Custom `peanut.yaml` file to specify `builder-options` and `example` as the
    source directory.
- https://github.com/flutter/samples/tree/master/web
  - Output: https://flutter.github.io/samples/
  - Custom `peanut.yaml` file to specify `builder-options`, multiple source
    directories, and a custom post-build file.

## Git tricks

The easiest way to push your `gh-pages` branch to github (without switching from
your working branch) is:

```console
$ git push origin --set-upstream gh-pages
```

To create (or update) your local `gh-pages` branch to match what's on the
server.

```console
$ git update-ref refs/heads/gh-pages origin/gh-pages
```

This is also useful if you want to undo a `peanut` run.
