# Example Competition Server

## Changelog

All notable changes to the competition-test-api docker container will be noted here.

### v1.2-rc5 - 2025-06-03

#### Added

- Added the optional `harnesses_included` flag to the `/webhook/trigger_task/` API. This boolean flag allows you to specify to the server whether you would like it to treat this challenge as a harnessed or unharnessed flag. If unset, this
  flag defaults to true.

### v1.2-rc4 - 2025-05-20

#### Fixed

- Our projects in oss-fuzz now use git-lfs to facilitate building fuzzers. In v1.2-rc3, we did not have git-lfs installed in the competitor-test-server Docker image. This is fixed in this release.

### v1.2-rc3 - 2025-05-20

This release includes the fixes intended for v1.2-rc2, but were mistakenly not included. Please see the "Fixed" section
in the v1.2-rc2 release notes for details.

### v1.2-rc2 - 2025-05-19

**UPDATE**: The fixes for this release were mistakenly not included in this release. Please use v1.2-rc3 for the below fixes

This release has no major changes. It only adds some bugfixes. This release should work with the Exhbition 2 challenges.

#### Fixed

- Fixed bug that prevents setting the correct sanitizer. This is similar to the bug that occurred in Exhibition 2 that caused non-`address` sanitizers to fail
- Fixed race condition that caused issues when triggering the `request/delta` endpoint

### v1.2-rc1 - 2025-04-23

This release makes the competition-test-api compliant with API spec v1.2. This includes the most notable
change.

#### Added

- **_BREAKING CHANGE_**: Added the `v1/request/delta` endpoint. An working example of this endpoint is provided in the [Running the server](#running-the-server) section below. Alongside this new endpoint, is the new
  `generate` field in the scantron YAML config.

- Added the `protocol` config option, which tells the competition server what protocol source TARs (i.e. the challenge and fuzz-tooling repositories) are sent over. This field can either be `http` or `https` If unset,
  this defaults to `http`.

- Added the `crs-status` executable to the competition-test-api Docker image. `crs-status` polls the CRS's status endpoint at a fixed time interval. This fixed time interval is set by the `crs_status_poll_time_seconds`
  scantron YAML config field. If unset, this config field is set to `60`. An example of running the crs-status executable is provided in the example compose.yaml located [here](./compose.yaml).

### v1.1-rc7 - 2025-04-03

#### Added

- Added ability to trigger SARIF broadcasts

#### Fixed

- Fixed bug that caused freeform submissions to fail

### v1.1-rc6 - 2025-03-26

#### Fixed

- Fixed incorrect directory naming for fuzz-tooling
- Fixed crash detection for java projects

### v1.1-rc5 - 2025-03-25

#### Fixed

- Fixed server error caused during a bundle submission

### v1.1-rc4 - 2025-03-21

#### Added

- **_BREAKING CHANGE_**: Added the `teams.crs.taskme` field in the scantron.yaml. This **MUST** be set to `true` if you want the competition server to send tasks to your CRS.
- Added ability to optionally use SCANTRON_GITHUB_PAT environment variable rather than the `github.pat` field in scantron.yaml

#### Fixed

- Fixed lack of a check for the dynamic-stack-buffer-overflow caused by example-libpng's address fuzzer
- Fixed race condition when reproducing more than one POV submission

### v1.1-rc3 - 2025-03-18

#### Added

- Added now required `api_host_and_port` scantron.yaml field to split the role of `listen_address`. This reverses the change made in v1.1-rc2 where `listen_address` was used to generate source tarball URLs and also used
  as the server's bind address. Now, `api_host_and_port` is used by the server when sending source tarballs to the CRSs, and `listen_address` is the address the server binds to.

### v1.1-rc2 - 2025-03-17

#### Fixed

- Fixed issue where competition server hardcoded `localhost` into the URLs for the source tarballs sent by the server during tasking. Now the `listen_address` field in scantron.yaml is used.

### v1.1-rc1 - 2025-03-14

Initial release candidate.

## Overview

This folder allows users to run a full end-to-end competition server, as well as a signoz endpoint for which competitors may submit telemetry to for testing.
This server simulates how the actual server will act in the competition. This means:

- The example server supports the v1.2 competition server API, including endpoints for patches/POVs/sarif submissions, as well as endpoints for checking the patch/POV statuses.
- As a correlary, the server also supports the v1.2 CRS API, meaning it can send tasks to CRSs
- The `compose.yaml` given in this folder also brings up signoz for telemetry. Competitors may use this to send to telemetry to, much like how they would in a real competition round.

## Prerequisites

You must make changes to the following files in order for the server to run properly

### GitHub Container Registry

You must login to the GitHub Container Registry to access the example competition server container.

You will need to have a GitHub personal access token (PAT) scoped to at least `read:packages`.

To create the PAT, go to your account, `Settings` > `Developer settings` > `Personal access tokens`, and generate a Token (classic) with the scopes needed for your use case.

For this example, the `read:packages` scope is required. If you'd like, you may also enable the `repo` scope so you can use the same token for the container registry and the competition test server (see the [scantron.yaml](#scantronyaml)
section below).

Once you have your PAT, set it to an environment variable on your machine like this

```bash
export CR_PAT=YOUR_TOKEN_HERE
```

Finally, you must login to the registry, like so:

```bash
$ echo $CR_PAT | docker login ghcr.io -u USERNAME --password-stdin
> Login Succeeded
```

To check if it succeeded, try running the following:

```bash
docker pull --platform=linux/amd64 ghcr.io/aixcc-finals/example-crs-architecture/competition-test-api:v1.2-rc3
```

Docker will store your credentials in your OS's native keystore, so you should only have to run `docker login` on subsequent logins into the GitHub Container Repository

### `scantron.yaml`

The competition servers configuration is stored in the `scantron.yaml` file. Of note for competitors
would be the following:

- `api_keys.id`: You don't need to edit this, but this is the key the CRS must use to send submissions to the server
- `crs`: This stores information the competition server uses to access the CRS
- `github.pat`: The server must download fuzz tooling and challenge repositories from GitHub, so you must add a GitHub personal access token with repository read access here in order for the server to work. This token
  must have the `repo` scope. You may use the same access token that you used for container registry, just as long as it has both the `repo` scope and the `read:packages` scope enabled. You may also set this value
  through the environment variable `SCANTRON_GITHUB_PAT` within the scantron service.
- `api_host_and_port`: This should be set to whatever host and port your CRS is using to send submissions to.
- `protocol`: This tells the competition server what protocol source TARs (i.e. the challenge and fuzz-tooling repositories) are sent over. This field can either be `http` or `https` If unset, this defaults to `http`.
- `teams.crs.taskme`: New as of v1.1-rc4 is the `taskme` flag. You must set this to true if you want the competition server to send tasks to your CRS.
- `generate`: New as of v1.2-rc1 is the `generate` field. These are the parameters used by the competition API when using the `/v1/request/delta` endpoint. This is **_REQUIRED_** for starting the competitor test API. We
  recommend that teams use the integration-test challenge repository, as it is nearly the same challenge repository as the one offered by the official competition API. Below is the config we recommend.

  ```yaml
  generate:
    enabled: true
    delta:
      repo_url: "https://github.com/aixcc-finals/integration-test.git"
      base_ref: "5ac0917575e20464b5aa86434dff2a7626b558b4"
      head_ref: "challenges/integration-test-delta-01"
      fuzz_tooling_url: "https://github.com/aixcc-finals/oss-fuzz-aixcc.git"
      fuzz_tooling_ref: "v1.1.0"
      fuzz_tooling_project_name: "integration-test"
  ```

### `signoz/otel-collector-config.yaml`

In order to test data submission to signoz, you can edit the Basic Auth username and password here, under `basicauth/server.htpasswd.inline`

In order to use this signoz from your CRS, use the following environment vars:

```bash
OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <base64 encoded credentials in format username:password>"
OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4317" # This will be the Team-specific telemetry server configured by the Organizers.
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
```

## Running the server

You can run the server and signoz by doing `docker compose up` from within the example-competition-server directory.
If you wish to not run signoz, you can remove the `include` statement at the top of the compose.yaml in example-competition-server. NOTE: Signoz may take 2-5 minutes to fully start up.

Through the Docker compose option, the server is available by default through `http://localhost:1324`. It's also available through `http://scantron:1324` within the `endpoint-network` Docker network. This Docker network
is made available for teams who have their CRS within their own compose setup. An example of a webservice that uses this network is shown in the example-crs-webservice
[compose.yaml](https://github.com/aixcc-finals/example-crs-architecture/blob/main/example-crs-webservice/compose.yaml).

Alternatively, you may start the server directly with the command below.

```bash
docker run \
    -v /var/run/docker.sock:/var/run/docker.sock \ # required for Docker-out-of-docker stuff
    -v path/to/scantron.yaml:/etc/scantron/scantron.yaml \ # required for server configuration
    -v path/to/scantron.db:/app/scantron.db \ # optional, in case you may have a sqlite3 database from a previous run you want to use again
    -v /tmp:/tmp \ # required, since it removes a strange bug caused by us doing Docker-out-of-docker
    -p 1323:1323 \
    -it \
    --rm \
    --privileged \ # required, for Docker-out-of-docker
    --add-host=host.docker.internal:host-gateway \
    ghcr.io/aixcc-finals/example-crs-architecture/competition-test-api:v1.2-rc1 server
```

In the normal competition, the server would get a notification from GitHub via GitHub webhooks, and would fire off a task to
the CRS from there. The example server here responds to an HTTP request instead. Here is an example curl command to
trigger a full scan.

```bash
curl -X 'POST' 'http://localhost:1323/webhook/trigger_task' -H 'Content-Type: application/json' -d '{
    "challenge_repo_url": "git@github.com:aixcc-finals/example-libpng.git",
    "challenge_repo_head_ref": "fdacd5a1dcff42175117d674b0fda9f8a005ae88",
    "fuzz_tooling_url": "https://github.com/aixcc-finals/oss-fuzz-aixcc.git",
    "fuzz_tooling_ref": "d5fbd68fca66e6fa4f05899170d24e572b01853d",
    "fuzz_tooling_project_name": "libpng",
    "duration": 3600
}'
```

Here is an example for a delta scan:

```bash
curl -X 'POST' 'http://localhost:1323/webhook/trigger_task' -H 'Content-Type: application/json' -d '{
    "challenge_repo_url": "git@github.com:aixcc-finals/example-libpng.git",
    "challenge_repo_base_ref": "0cc367aaeaac3f888f255cee5d394968996f736e",
    "challenge_repo_head_ref": "fdacd5a1dcff42175117d674b0fda9f8a005ae88",
    "fuzz_tooling_url": "https://github.com/aixcc-finals/oss-fuzz-aixcc.git",
    "fuzz_tooling_ref": "d5fbd68fca66e6fa4f05899170d24e572b01853d",
    "fuzz_tooling_project_name": "libpng",
    "duration": 3600
}'
```

You may optionally specify whether the task is unharnessed using the `harnesses_include` flag, like below. If unset, the test server assumes `harnesses_include=true`

```bash
curl -X 'POST' 'http://localhost:1323/webhook/trigger_task' -H 'Content-Type: application/json' -d '{
  "challenge_repo_url": "git@github.com:aixcc-finals/integration-test.git",
  "challenge_repo_base_ref": "4a714359c60858e3821bd478dc846de1d04dc977",
  "challenge_repo_head_ref": "889cdb1b971b9a8a0338a89e50c51c051965bae5",
  "fuzz_tooling_url": "https://github.com/aixcc-finals/oss-fuzz-aixcc.git",
  "fuzz_tooling_ref": "challenge-state/integration-test-unharnessed-delta-01",
  "fuzz_tooling_project_name": "integration-test", 
  "harnesses_included": false,
  "duration": 3600
}'
```

You can also request to send a SARIF broadcast. It two fields. The `task_id` field is the UUID of a previous task that was triggered through `/webhook/trigger_task`. The `sarif` field is in the form of a JSON object
that follows [sarif-schema.json](../docs/api/sarif-schema.json). Below is an example request for example-libpng.

```bash
curl -X 'POST' 'http://localhost:1323/webhook/sarif' -H 'Content-Type: application/json' -d '{
  "task_id": "<INSERT_TASK_ID_OF_FULL_SCAN_HERE>",
  "sarif": {
    "runs": [
      {
        "artifacts": [
          {
            "location": {
              "index": 0,
              "uri": "pngrutil.c"
            }
          }
        ],
        "automationDetails": {
          "id": "/"
        },
        "conversion": {
          "tool": {
            "driver": {
              "name": "GitHub Code Scanning"
            }
          }
        },
        "results": [
          {
            "correlationGuid": "9d13d264-74f2-48cc-a3b9-d45a8221b3e1",
            "level": "error",
            "locations": [
              {
                "physicalLocation": {
                  "artifactLocation": {
                    "index": 0,
                    "uri": "pngrutil.c"
                  },
                  "region": {
                    "endLine": 1447,
                    "startColumn": 1,
                    "startLine": 1421
                  }
                }
              }
            ],
            "message": {
              "text": "Associated risk: CWE-121"
            },
            "partialFingerprints": {
              "primaryLocationLineHash": "22ac9f8e7c3a3bd8:8"
            },
            "properties": {
              "github/alertNumber": 2,
              "github/alertUrl": "https://api.github.com/repos/aixcc-finals/example-libpng/code-scanning/alerts/2"
            },
            "rule": {
              "id": "CWE-121",
              "index": 0
            },
            "ruleId": "CWE-121"
          }
        ],
        "tool": {
          "driver": {
            "name": "CodeScan++",
            "rules": [
              {
                "defaultConfiguration": {
                  "level": "warning"
                },
                "fullDescription": {
                  "text": "vulnerable to #CWE-121"
                },
                "helpUri": "https://example.com/help/png_handle_iCCP",
                "id": "CWE-121",
                "properties": {},
                "shortDescription": {
                  "text": "CWE #CWE-121"
                }
              }
            ],
            "version": "1.0.0"
          }
        },
        "versionControlProvenance": [
          {
            "branch": "refs/heads/challenges/full-scan",
            "repositoryUri": "https://github.com/aixcc-finals/example-libpng",
            "revisionId": "fdacd5a1dcff42175117d674b0fda9f8a005ae88"
          }
        ]
      }
    ],
    "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
    "version": "2.1.0"
  }
}'
```

Note: The Git repository specified in the curl command must have a shell script located at `.aixcc/test.sh`. This script is used to perform functionality tests on patches submitted to the competition API. This script
should have a 0 exit code on success, and a non-zero exit code on failure.

NEW as of v1.2-rc1 is the `/v1/request/delta` endpoint. Teams may use this endpoint to request a task hardcoded in the scantron YAML config from the server. An example curl is given below.

```bash
curl -X 'POST' -u "11111111-1111-1111-1111-111111111111:secret" 'http://localhost:1323/v1/request/delta'
```

## Viewing Signoz Dashboard

Once you kick off a task, you will be able to view the competition dashboard. Go to `localhost:3301`.
There you will see a login screen, or a screen to create your account. Once you login you'll be met
with this screen.

![Signoz Home Screen](./images/initial-login.png)

Click on the Dashboards menu entry on the left-hand side.

![Signoz Dashboards](./images/dashboards.png)

Click on one of the Round Status dashboards (doesn't matter which one). Then, set the `$Round`
and the $Environment`. You should see an image similar to below.

![Signoz Round Status](./images/round-status.png)
