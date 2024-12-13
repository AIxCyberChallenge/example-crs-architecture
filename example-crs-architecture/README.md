# Example Terraform AKS Cluster

## Overview

The following is an example on how to deploy an Azure Kubernetes Service cluster within an Azure subscription.

This configuration deploys an AKS cluster (`primary`) with two node pools:

- The default node pool (`sys`) - contains 2 system mode nodes
- A User node pool (`usr`) - contains 3 user mode nodes

The resource group name is generated with the `"random_pet"` resource from the `hashicorp/random` provider; and are prefixed with `example`

The VM Size is for both pools are using `Standard_D5_v2` in this example. You can change this to suite your needs by editing the `vm_size` values in `main.tf`.

The standard `azure` networking profile is used.

## Pre-requisites

- Azure CLI installed: [az cli install instructions](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- Terraform installed: [terraform install instructions](https://developer.hashicorp.com/terraform/tutorials/azure-get-started/install-cli)
- Kubernetes CLI installed: [kubectl install instructions](https://kubernetes.io/docs/tasks/tools/#kubectl)
- An active Azure subscription.
- An account in Azure Entra ID.

### Azure

#### Login to Azure

`az login --tenant aixcc.tech` - will open authentication in a browser

Show current tenant and subscription name:

`az account show --query "{SubscriptionID:id, Tenant:tenantId}" --output table`

Example output:

```bash
SubscriptionID                        Tenant
------------------------------------  ------------------------------------
<YOUR-SUBSCRIPTION-ID>                c67d49bd-f3ec-4c7f-b9ec-653480365699
```

### Service Principal Account

A service principal account (SPA) is required to automate the creation of resources and objects within your subscription.

You can create a SPA several ways, the following describes using azure cli.

```bash
az ad sp create-for-rbac --name "ExampleSPA" --role Contributor --scopes /subscriptions/<YOUR-SUBSCRIPTION-ID>
```

> Replace "ExampleSPA" with the name of the SPA you wish to create. Replace `<YOUR-SUBSCRIPTION-ID>` with your azure subscription ID.
> If using resource group locks, additional configuration may be neccessary which is out of scope of this example; e.g. adding the role `Microsoft.Authorization/locks/` for write, read and delete to the SPA.

On successful SPA creation, you will receive output similar to the following:

```bash
{
  "appId": "34df5g78-dsda1-7754-b9a3-ee699876d876",
  "displayName": "ExampleSPA",
  "password": "jfhn6~lrQQSH124jfuy96ksv_ILa2q128fhn8s",
  "tenant": "n475hfjk-g7hj-77jk-juh7-1234567890ab"
}
```

Make note of these values, they will be used in the AKS deployment as the following environment variables:

```bash
ARM_TENANT_ID="<tenant-value>"
ARM_CLIENT_ID="<appID-value>"
ARM_CLIENT_SECRET="<password-value>"
ARM_SUBSCRIPTION_ID="<YOUR-SUBSCRIPTION-ID>"
```

You can export these as environment variables from the host you're deploying from.

```bash
export ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000"
export ARM_CLIENT_SECRET="12345678-0000-0000-0000-000000000000"
export ARM_TENANT_ID="10000000-0000-0000-0000-000000000000"
export ARM_SUBSCRIPTION_ID="20000000-0000-0000-0000-000000000000"
```

Alternatively, you can add them to your `main.tf`, **this is discouraged for security reasons.**

```bash
provider "azurerm" {
  features {}
  #Can setup your service principal here, currently commented out to use az cli apply terraform
  #subscription_id   = "<azure_subscription_id>"
  #tenant_id         = "<azure_subscription_tenant_id>"
  #client_id         = "<service_principal_appid>"
  #client_secret     = "<service_principal_password>"
}
```

## Remote Terraform State Storage

By default, terraform stores its state locally. It is best practice to store terraform state in a remote location.
This can help with collaboration, security, recovery and scalability. To do this within Azure, you need to create resources to do so.

### Azure CLI

The following is an example of how to create the resources needed for remote state configuration.
These resources will be used in the `backend.tf` configuration file.

- Create remote state resource group.

```bash
az group create --name example-tfstate-rg --location eastus
```

- Create storage account for remote state.

```bash
az storage account create --resource-group example-tfstate-rg --name exampleserviceaccountname --sku Standard_LRS --encryption-services blob
```

- Create storage container for remote state

```bash
az storage container create --name tfstate --account-name exampleserviceaccountname --auth-mode login
```

### backend.tf

Replace the values for `resource_group_name`, `storage_account_name`, `container_name` with the ones you created above.

```bash
terraform {
  backend "azurerm" {
    resource_group_name  = "example-tfstate-rg"
    storage_account_name = "exampleserviceaccountname"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
```

## Deploy

- Log into your Azure tenant with `az login --tenant aixcc.tech`
- Clone this repository if needed: `git clone git@github.com:aixcc-finals/example-crs-architecture.git /<local_dir>`
- Make any required changes to `backend.tf`, `main.tf`, and `variables.tf`
- Export the environment variables for your [SPA Configuration](#service-principal-account) if needed.
- Initialize terraform: `terraform init`
- Run plan: `terraform plan` - review output
- Deploy: `terraform apply`
  - type `yes` when prompted to apply

A handful of outputs will be provided based on `outputs.tf` when the apply completes.

## State

- `terraform state list` - lists all resources in the deployment.
- `terraform state show '<resource>'` - replace `<resource>` with the resource you want to view from the `list` command

## Destroy

To teardown your AKS cluster run the following:

- `terraform destroy`
- Review the output on what is to be destroyed
- Type `yes` at the prompt
