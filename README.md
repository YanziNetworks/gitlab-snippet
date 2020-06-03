# GitLab Snippets

This script provides an implementation of the gitlab project snippets [API] in
pure POSIX shell. The scripts requires an installation of `curl` and depends on
the [submodule] [yu.sh] (but read [on](#packaging)). To operate on snippets, you
will need an authentication [token].

The script mainly targets the use from within gitlab [ci] jobs, permitting
storage of project-wide data between runs. While [ci] provides [caching],
caching across runners spread out to several hosts requires cloud-level storage.
This script uses the gitlab instance for storage, at the expense of a slightly
lesser flexible interface: you need to explicitly pinpoint the files that needs
caching. However, the script also provides history over cached data, as snippets
really are git repositories.

  [API]: https://docs.gitlab.com/ee/api/project_snippets.html
  [submodule]: https://git-scm.com/book/en/v2/Git-Tools-Submodules
  [token]: https://docs.gitlab.com/ee/api/README.html#authentication
  [yu.sh]: https://github.com/YanziNetworks/yu.sh
  [ci]: https://docs.gitlab.com/ee/ci/
  [caching]: https://docs.gitlab.com/ee/ci/caching/index.html

## Examples

### Listing Snippets

Provided an access token `XXX` able to access the project `efrecon/test` at
gitlab, the following would list out the IDs of the snippets accessible to that
token:

```shell
./snippet --token XXX --project efrecon/test
```

`snippet` takes commands after a list of global options. The default command is
`list`, it was the command used in the previous example. Consequently, the
following example, would perform exactly the same operation, but making the
command `list` explicit:

```shell
./snippet --token XXX --project efrecon/test list
```

`snippet` also uses single `--` to separate between options and their values
from what comes next. In other words, the following call would still perform
exactly the same operation.

```shell
./snippet --token XXX --project efrecon/test -- list
```

### Getting Snippets

Provided a snippet ID `145` at the same project, the following would return the
raw content of the snippet.

```shell
./snippet --token XXX --project efrecon/test get 145
```

### Creating Snippets

To create a snippet, more information is necessary. The options given to the
`create` command below are the ones that are mandatory when creating snippets.

```shell
./snippet --token XXX --project efrecon/test \
    create \
        --title "test" \
        --content "This is a test" \
        --filename "test.txt" \
        --visibility private
```

If you want to create a snippet with longer content, you can use the
`--content-file` instead, which picks the content from a file. The following
example, would create a snippet with the content of the `snippet` script itself:

```shell
./snippet --token XXX --project efrecon/test \
    create \
        --title "snippet" \
        --content-file ./snippet \
        --filename "snippet.sh" \
        --visibility private
```

## Usage

The script supports a number of global single- or double-dashed (long) options
followed by a CRUD-like command, e.g. `get`, `create`, etc. Some of the commands
take themselves long/short options in the same vein. Long double-dashed options
can either be separated or use the equal sign, e.g. `--option value` or
`--option=value`. The end of a series of options (before a command or final
arguments to a command), can always be specified with a `--` alone.

### Global Options

#### `-g` or `--gitlab`

Specify the hostname of the remote gitlab instance to talk to. This defaults to
`gitlab.com`. The value of this option is only used whenever `--root` is empty,
which is however the default.

#### `-r` or `--root`

Fully qualified path to the root of the gitlab API, e.g.
`https://gitlab.com/api/v4`. The default is for the `--root` to be empty, in
which case the root of the API is constructed out of the value of the `--gitlab`
option.

#### `-t` or `--token`

Authentication [token] when talking to the API. You need a properly working
token.

#### `-p` or `--project`

Identifier or name of the project. This should either be the numerical
identifier of the gitlab project, or the path to the project, e.g.
`diaspora/diaspora`. `snippet` will automatically URL encode this for you.

#### `-v` or `--verbose`

Verbosity level, from `trace` to `error`. The default is `info`.

### Commands

In order to ease automation, creation and listing commands will typically print
out the identifier of the relevant snippet(s) on the standard out, so this
information can be used in further commands.

#### `list`

This is the default command, i.e. it is what runs when snippet is called without
any command specification. The command prints out the identifiers of the
snippets accessible by the token at the project on the standard out.

#### `get` or `read`

This command takes the identifier of an existing snippet as an argument and will
print out its raw content on the standard out.

#### `search`

This command searches for snippets matching the extended regular expressions
passed through the options and prints their identifiers. Recognised options are:

+ `-t` or `--title` is the regex to match against the title of the snippet.
+ `-d` or `--description` is the regex to match against the description of the
  snippet.
+ `-f` or `--filename` is the regex to match against the filename of the
  snippet.
+ `-v` or `--visibility` is the regex to match against the visibility of the
  snippet.

#### `details`

This command takes the identifier of an existing snippet and prints out the
parsed JSON output of the gitlab snippet description. When passed the `--json`
flag, the command will, instead print out the unparsed entire gitlab snippet
description.

#### `create` or `add`

This command will create a snippet and return its identifier. On error, it will
log the error at the `error` level. It takes a number of options, most of them
being mandatory:

+ `-t` or `--title` is the mandatory title of the snippet.
+ `-d` or `--description` is the optional description of the snippet.
+ `-f` or `--filename` is the mandatory filename of the snippet.
+ `-v` or `--visibility` is the mandatory visibility of the snippet. It should
  be one of `private`, `internal` or `public`.
+ `-c` or `--content` is the textual content of the snippet.  One of
  `--content-file` or `--content` must be present.
+ `--content-file` is file containing the content of the snippet. One of
  `--content-file` or `--content` must be present.

#### `update` or `change`

This command takes the same options as the `create` command and, in addition,
the identifier of an existing snippet. It will modify the snippet and return its
identifier on success.

#### `delete` or `remove`

This command takes the identifier of a snippet and removes it.

## Packaging

The current implementation depends on a number of internal modules and on the
utility library [yu.sh]. To make it easier to ship the script to "raw" servers,
the script supports [amalgamation]. To create a single binary that can easily be
copied to a target machine, run the following commands from the root directory
of the project:

```shell
./lib/yu.sh/bin/amalgamation.sh snippet > snippet.sh
chmod a+x ./snippet.sh
```

  [amalgamation]: https://www.sqlite.org/amalgamation.html
