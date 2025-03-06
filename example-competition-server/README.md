# Example Competition Server

## Overview
This folder allows users to run a full end-to-end competition server, as well as a signoz endpoint for which competitors may submit telemetry to for testing. 

## Prerequisites
You must make changes to the following files in order for the server to run properly

### `scantron.yaml`
The competition servers configuration is stored in the `scantron.yaml` file. Of note for competitors
would be the following:
- `api_keys.id`: You don't need to edit this, but this is the key the CRS must use to send submissions to the server
- `crs`: This stores information the competition server uses to access the CRS
- `github.pat`: The server must download fuzz tooling and challenge repositories from github, so you must add a github personal access token with repository read access here in order for the server to work.

### `signoz/otel-collector-config.yaml`
If you choose to submit data to signoz, you can edit the Basic Auth username and password here, under `basicauth/server.htpasswd.inline`

## Running the server
You can run the server and signoz simply by doing `docker compose up` from within the example-competition-server directory.
If you wish to not run signoz, you can simply remove the `include` statement at the top of the compose.yaml in example-competition-server.

In the normal competition, the server would get a notification from github via github webhooks, and would fire off a task to 
the CRS from there. The example server here responds to a simple HTTP request instead. Here is an example curl command to
trigger a full scan.

```
curl -X 'POST' 'http://localhost:1323/webhook/trigger_task' -H 'Content-Type: application/json' -d '{
    "challenge_repo_url": "git@github.com:aixcc-finals/example-libpng.git",
    "challenge_repo_head_ref": "2c894c66108f0724331a9e5b4826e351bf2d094b",
    "fuzz_tooling_url": "https://github.com/google/oss-fuzz.git",
    "fuzz_tooling_ref": "26f36ff7ce9cd61856621ba197f8e8db24b15ad9",
    "fuzz_tooling_project_name": "example-libpng",
    "duration": 3600
}'
```

Here is an example for a delta scan:

curl -X 'POST' 'http://localhost:1323/webhook/trigger_task' -H 'Content-Type: application/json' -d '{
    "challenge_repo_url": "git@github.com:aixcc-finals/example-libpng.git",
    "challenge_repo_base_ref": "0cc367aaeaac3f888f255cee5d394968996f736e",
    "challenge_repo_head_ref": "2c894c66108f0724331a9e5b4826e351bf2d094b",
    "fuzz_tooling_url": "https://github.com/google/oss-fuzz.git",
    "fuzz_tooling_ref": "26f36ff7ce9cd61856621ba197f8e8db24b15ad9",
    "fuzz_tooling_project_name": "example-libpng",
    "duration": 3600
}'
```