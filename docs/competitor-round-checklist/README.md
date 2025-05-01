# Competitor Round Checklist

This checklist is to help competitors prepare their CRS for each round.

- [ ] Obtain Round Subscription ID from Organizers
- [ ] Obtain Round LLM Keys from Organizers
- [ ] If using custom models, ensure they have been approved
- [ ] Ensure CRS GitHub Release is accurate and matches what is reported by the CRS status endpoint
- [ ] Ensure CRS GitHub repository has requisite LICENSE file
- [ ] Create Service Principal Account for current subscription
- [ ] Ensure any attached disks are not temporary or ephemeral storage types
- [ ] Ensure any necessary Storage Accounts are created for current subscription
- [ ] Update environment variables for infrastructure as needed for current subscription. (subscription ID, client ID, etc.)
- [ ] Ensure CRS is pointing to the Competition API URL: `https://api.tail7e9b4c.ts.net`
- [ ] Validate Tailscale tailnet connectivity to competition resources. Test service: `curl -v https://echo.tail7e9b4c.ts.net`
- [ ] Perform a simple integration test by using the `/v1/request/delta` endpoint to ensure that the CRS is being properly tasked by the competition API.
      This can be done inside the tailnet or can be requested from `https://api.aixcc.tech/v1/request/delta` with the team's Competition API credentials
- [ ] Ensure telemetry data (OTel) is configured to be sent to SigNoz instance, this includes the following fields:

- `crs.action.category` attribute confirms CRS telemetry spans were sent
- `round.id` is an example of an attribute from the Task metadata field. (confirms correct task metadata field pass-through)
- `gen_ai.request.model` attribute existing confirms LLM telemetry
- More detailed telemetry information can be referenced [here](https://github.com/aixcc-finals/example-crs-architecture/blob/main/docs/telemetry/README.md#crs-telemetry-specification-v10)
