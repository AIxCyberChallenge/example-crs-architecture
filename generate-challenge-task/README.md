# generate-challenge-task

This bash script will convert an OSS-Fuzz-compatible repo into the Challenge Task format.

It does not modify the source repository. In particular, it does not add challenges. We recommend using an exemplar repository if you want need your CRS to have a guaranteed vuln to find.

## Getting Started

### Step 1: Dependencies

Ensure the following are all installed to your working environment:

- [azure-cli](https://learn.microsoft.com/en-us/cli/azure/)
- [jq](https://jqlang.github.io/jq/)
- git
- tar
- curl

### Step 2: Git setup

Make sure that before you run the script, you have access to clone the target repository and the oss-fuzz tooling.

### Step 3: Azure Setup

- Set up an Azure Storage Account.
- Set up a Blob Container within above Storage Account.
- Get your account key and connection string. These are both accessible in the Storage Account menu by navigating to your Storage Account -> Security + Networking in the sidebar -> Access keys.

### Step 4: Setting Environment Variables

The `example.env` file demonstrates all environment variables that need to be populated.
They are the secrets used to access your CRS and the Azure Storage Container.
Set the environment variables in your shell or copy `example.env` to `.env` in your working directory. This file must be in the working directory to be detected.

Set the following variables in `.env`:

- CONTAINER_NAME

Name of the Azure Blob Storage Container that you created.

- STORAGE_ACCOUNT

Name of the Azure Storage Account that you created.

- STORAGE_KEY and CONNECTION_STRING

Use previously-mentioned values from step 3. Select and copy the key field and the connection string field to these variables from one of the keys in the Azure portal UI.

- CRS_API_KEY_ID and CRS_API_TOKEN

HTTP Basic credentials to access your CRS's API.

## Running the Script

### Usage

```bash
Usage: ./generate-challenge-task.sh [options]
    -v    Enable verbose output mode
    -c    URL to the CRS to send challenge task.
    -x    Execute the crs task challenge against the CRS URL in -c on script finish. If argument is not supplied, the curl will be written to a local file.
    -t    Target github repo to scan. Format: path to the remote that will work for git clone
    -r    Git ref to generate diff for delta mode.
    -b    Git ref to act as base for the diff. Default value is main. Often useful on a repo where the central branch is called master
    -o    OSS-Fuzz repo to generate oss-fuzz tooling package. Default https://github.com/google/oss-fuzz.git
    -p    Project folder name inside OSS-Fuzz corresponding to this repo (for example, for https://github.com/apache/commons-compress, this is apache-commons-compress)
    -l    Instead of uploading to Azure storage, leave tars on local filesystem. Placeholders for sas_urls will be inserted into curl
    -H    Set harnesses_included in task JSON to false. If not set, harnesses_included defaults to true
```

### Usage Examples

`./generate-challenge-task.sh -t <url_to_target_git_repo> -p <project_name_in_oss_fuzz> -c <crs_url>`

Above will run the script with limited output (no -v), producing a full scan Challenge Task,
and will write the curl command to the local file `task_crs.sh` since no `-x` was provided.
Note: The format of the repository should be one that works in `git clone <url>` e.g. `https://github.com/<org>/<reponame>.git`

`./generate-challenge-task.sh -t <url_to_target_git_repo> -p <project_name_in_oss_fuzz> -c <crs_url> -x`

Above will run the script as previous example, but it will attempt to execute the curl for the Challenge Task.
against the CRS URL provided instead of writing it to task_crs.sh

`./generate-challenge-task.sh -t <url_to_target_git_repo> -p <project_name_in_oss_fuzz> -c <crs_url> -r mybranch|tag|commit_hash`

Above will run the script in delta scan mode, which generates a diff between main and the ref
(commit hash, tag or branch name) provided in the -r argument. The curl will be written to task_crs.sh and will contain 3 sources instead of 2 because of the included PR diff tarball.

`./generate-challenge-task.sh -t <url_to_target_git_repo> -p <project_name_in_oss_fuzz> -c <crs_url> -r mybranch|tag|commit_hash -v -b mybranch|tag|commit_hash`

Above will do the same thing as prior, but with verbose output, and the base branch to diff against will be an arbitrary ref instead of main, due to the included -b flag.

`./generate-challenge-task.sh -t <url_to_target_git_repo> -p <project_name_in_oss_fuzz> -c <crs_url> -r mybranch|tag|commit_hash -v -o <oss-fuzz-tooling-repo-url>`

Above will additionally tar and upload and reference in resultant curl a custom oss-fuzz tooling repository.

`./generate-challenge-task.sh -t <url_to_target_git_repo> -p <project_name_in_oss_fuzz> -c <crs_url> -r mybranch|tag|commit_hash -l -o <oss-fuzz-tooling-repo-url>`

Above will in lieu of uploading the tars to Azure Storage, will store them locally in a directory called `repo-tars` next to the script. The curl that results will not be usable since the tar paths in the curl will be replaced with placeholders.

`./generate-challenge-task.sh -c https://my.crs.crsdomain.com -t https://github.com/isc-projects/bind9.git -p bind9 -r bind-9.20 -v -b bind-9.18`

This is an example script invocation with real-life values.
Note: bind9 was chosen as an arbitrary example and should not be interpreted to signal anything about the competition.

### Notes on types of acceptable refs

The following refs have been successfully utilized to create diffs:

- Full commit hashes
- Tags
- Branch names
