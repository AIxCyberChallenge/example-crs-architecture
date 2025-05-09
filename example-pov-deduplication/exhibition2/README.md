# Exhibition 2 PoV Deduplication Strategy

This directory contains scripts containing the code that was used for the deduplication process of PoVs during Exhibition 2 with some slight tweaks ( that do not affect the functionality of the code ) to make them more portable and usable for competitors.

After the end of a challenge task, this methodology is used to determine Challenge Vulnerabilities.
A Challenge Vulnerability is defined implicitly by all duplicate PoVs found by all CRSs for that challenge, plus the competition-designed PoVs prepared for the synthetic vulnerabilities.

As an example, consider the following scenario for a single challenge task:

* There are two competition-designed PoVs: PoV-1, and PoV-2
* CRS A submits three PoVs: PoV-3, PoV-4, PoV-5
* CRS B submits one PoV: PoV-6

Now consider the results of deduplication:

* PoV-1 is duplicate of PoV-3
* PoV-3 is duplicate of PoV-6
* PoV-5 is duplicate of PoV-6

The resulting Challenge Vulnerabilities would by defined by the variant pov sets:

* Vuln 1: [PoV-1, PoV-3, PoV-5, PoV-6]
* Vuln 2: [PoV-2]
* Vuln 3: [PoV-4]


# Requirements

This methodology has been tested on Python 3.11, specifically.

# Setting Up

We're assuming a Unix-like for your usage. If you're on Windows, you should be able to replicate the following command outline pretty easily without breaking a sweat!

1. **From this directory,** clone clusterfuzz.
2. Check out the correct commit for clusterfuzz.
3. Create a new virtual environment, and activate it.
4. Install from `requirements.txt`.

The following should handle this:

```bash
git clone https://github.com/google/clusterfuzz.git \
    && git -C clusterfuzz checkout $(cat clusterfuzz-commit-hash) \
    && python3.11 -m venv venv \
    && . venv/bin/activate \
    && python -m pip install -r requirements.txt
```

You should now be able to run the scripts!

# Directory Overview

`deduplicate_povs.py`: The most important script in the directory! Given an input file with serialized PoVs ( see its top-level docstring for more information ), it will print a message letting you know whether or not our system would've determined the input PoVs to be duplicates.

`generate_crash_state.py`: A tool for generating crash states and instrumentation keys for use by `deuplicate_povs.py`. We'll include a brief explanation of these in this README, but the docstrings of the scripts should be helpful as well.

`sample_deduplciation_input.json`: A sample of the kind of structure `deduplicate_povs.py` is expecting for its input. You can create your own and run it through the script!

`sample_fuzz_output.txt`: A sample fuzzer output that can be used as the input to `generate_crash_state.py`. You can use your own outputs with that script, too!

`clusterfuzz-commit-hash`: We need clusterfuzz to do deduplication, so we keep the commit that we've got pinned at the moment in this file.

# Usages

Running deduplication on some input file:

```bash
python3 deduplicate_povs.py -i sample_deduplication_input.json
```

Generating crash states and instrumentation keys from a fuzzer input and writing them to a JSON document:

```bash
python3 generate_crash_state.py -i sample_fuzz_output.txt -o my_file.json
```


# Crash State? Instrumentation Key?

A "Crash State" is a string that's produced by clusterfuzz using a rather large library of heuristics to determine whether or not two PoVs are duplicates of one-another based on their fuzzer outputs. We generate these crash states from fuzzer outputs for a part of our deduplication pipeline, and use the same method that clusterfuzz does.

An "Instrumentation Key", however, is a creation of the AIxCC team. Certain fuzz outputs don't yield clean crash states, so we devise a key based on the instrumentation signatures found in them when they're available. The sample fuzz output contained in this repository contains some samples.

