# Competitor Round Checklist

This checklist is to help competitors prepare their CRS for each round.

- [ ] Obtain Round Subscription ID from Organizers
- [ ] Obtain Round LLM Keys from Organizers
- [ ] Obtain Competition API keys from Organizers
- [ ] Provide CRS API keys to Organizers, if needed
- [ ] Obtain Tailscale tailnet credentials from Organizers, if needed
- [ ] If using custom models, ensure they have been approved
- [ ] Ensure CRS GitHub Release is accurate and matches what is reported by the CRS status endpoint
- [ ] Ensure CRS GitHub repository has requisite LICENSE file
- [ ] Create Service Principal Account for current subscription
- [ ] If using Azure VMs, ensure attached disks are not temporary or ephemeral storage types
- [ ] If using AKS, create Storage Account for current subscription
- [ ] If using AKS, create remote state backend for current subscription
- [ ] Update environment variables for infrastructure as needed for current subscription. (subscription ID, client ID, etc.)
- [ ] Validate Tailscale tailnet connectivity to competition resources. Test service: `curl -v https://echo.tail7e9b4c.ts.net`
- [ ] Perform a smoke-test by using the `/request/delta` endpoint, to ensure that the CRS is being properly tasked by the competition API
- [ ] Ensure telemetry data (OTel) is configured to be sent to SigNoz instance
