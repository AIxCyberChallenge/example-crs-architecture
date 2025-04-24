# Restrict Access

The script within will restrict public inbound access to a set of subscriptions via Network Security Groups (NSGs), AKS API network authorization, and Public IP manipulation.

This can be used by competitors to test the access restrictions that will be applied by the Organizers for each round.

## Script

`network_access_control.sh`

## Setup

The script relies on `subscriptions.txt` to be populated with the subscriptions IDs that you want to manage.

Add the subscriptions IDs, one per line, to have the script iterate through its resources and apply/revert the NSG rules and AKS API access controls.

## Usage

### help

`./network_access_control.sh --help` prints the help menu.

### block accesses

`./network_access_control.sh --mode block` uses Azure CLI to:

- Create a backup of all existing NSGs, AKS authorized networks, and Public IPs per subscription and stores them in the script directory at `../backups/<subscription ID>/`
- Iterate through each subscription in `subscriptions.txt`.
- Identify subscription resources.
- Create NSGs with a deny-all inbound rule.
- Create Tailscale allow all NSGs
- Ensure outbound connectivity is unaffected.
- Iterate through AKS clusters, if they exist.
- Uses `az aks update` to set `--api-server-authorized-ip-ranges` `0.0.0.0/32`
- Finds Public IP address for running resources and forces a change to a temporary IP to force disconnect existing inbound connections.

### rotate AKS certs (optional)

`./network_access_control.sh --mode block --rotate-certs` in addition to the above:

- Uses `az aks rotate-certs` to rotate existing AKS certifications, dropping all existing API connections. This is a disruptive action and significantly increases runtime of the script.

### revert accesses

`./network_access_control.sh --mode revert` uses Azure CLI to:

- Iterate through each subscription in `subscriptions.txt`.
- Identify subscription resources.
- Reverts NSGs, AKS authorized networks, and Public IPs from the subscription's respective backup directory created in `block mode`. `../backups/<subscription ID>/`
- Updates `kubeconfig` contexts with new certificates.

## Backups

Resource configuration backups are stored in the script directory at `../backups/<subscription ID>`

## Logging

Logs are created per execution for both `--mode block` and `--mode revert` per subscription. The logs are stored in the script directory at `../logs/<subscription ID>/`

The following logs are created for each subscription:

- NSG → nsg-block.log, nsg-revert.log
- AKS → ask-block.log, aks-revert.log
- PubIP → pubip-block.log, pubip-revert.log

The logs provide a timestamp and START/SUCCESS/FAILURE status per command action taken.

### Validation

- Tailscale connectivity remained after block mode invoked (curl test to web service)
- New SSH connections were prevented (via NSGs)
- Existing SSH connections were severed (via Public IP change)
- New AKS API (`kubectl`) access was prevented (via Authorized Network config)

## Caveats

Since the revert mode relies on restoring previous configuration from block mode. You need to ensure you don't run the script in block mode more than once without running in revert mode.

Doing so will overwrite the previous backups with the original state of the resources access. Always run a single block followed by a revert, even if an error occurs.

Wherever (the machine) the block mode is run, the revert must also be run from as it relies upon the backups created from the block execution.

Further, you want to have the same subscription IDs in `subscriptions.txt` between block and revert runs.

Best practice, if you wish to add more subscriptions after you've already executed a block run; you should perform a revert first, update `subscriptions.txt`, then execute a block to avoid any issues.
