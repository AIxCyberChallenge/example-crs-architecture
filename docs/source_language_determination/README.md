# Project Source Language Determination

As part of evaluating a patch, Scantron has to determine if it only modifies files in the target project's language.

Scantron uses [go-enry](https://github.com/go-enry/go-enry) v2.9.2 to determine a file's language. This folder contains binaries so that you can run the same process outside of Scantron.
