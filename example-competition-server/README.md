# Example Competition Server

## Overview
This folder allows users to run a full end-to-end competition server, as well as a signoz endpoint for which competitors may submit telemetry to for testing. This server simulates how the actual server will act in the competition. This means:
- The example server supports the v0.4 competition server API, including endpoints for patches/POVs/sarif submissions, as well as endpoints for checking the patch/POV statuses.
- As a correlary, the server also supports the v0.4 CRS API, meaning it can send tasks to CRSs
- The `compose.yaml` given in this folder also brings up signoz for telemetry. Competitors may use this to send to telemetry to, much like how they would in a real competition round.

## Prerequisites
You must make changes to the following files in order for the server to run properly

### Github Container Registry
You must login to the Github Container Registry to access the example competition server container.

You will need to have a GitHub personal access token (PAT) scoped to at least `read:packages`.

To create the PAT, go to your account, `Settings` > `Developer settings` > `Personal access tokens`, and generate a Token (classic) with the scopes needed for your use case.

For this example, the `read:packages` scope is required.

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
docker pull ghcr.io/aixcc-finals/competitor-test-server/competition-api:v0.4
```

__Note__: If you are on a non-x86_64 machine (e.g. Apple M1 Macintosh), the above docker pull
command will not work. Instead use the following
```bash
docker pull --platform=linux/amd64 ghcr.io/aixcc-finals/competitor-test-server/competition-api:v0.4
```

Docker will store your credentials in your OS's native keystore, so you should only have to run `docker login` on subsequent logins into the Github Container Repository

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
```
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
