#!/usr/bin/env bash
set -e

#executes a series of terraform, az cli, and kubernetes commands to deploy or destroy an example crs architecture

echo "Applying environment variables from ./env"
source ./env
echo "Current azure account status:"
az account show --query "{SubscriptionID:id, Tenant:tenantId}" --output table

#deploy the AKS cluster and kubernetes resources function
up() {

	echo "Applying environment variables to yaml from templates"
	CLIENT_BASE64=$(echo -n "$TF_VAR_ARM_CLIENT_SECRET" | base64)
	CRS_KEY_BASE64=$(echo -n "$CRS_KEY_TOKEN" | base64)
	COMPETITION_API_KEY_BASE64=$(echo -n "$COMPETITION_API_KEY_TOKEN" | base64)
	export CLIENT_BASE64
	export CRS_KEY_BASE64
	export COMPETITION_API_KEY_BASE64
	envsubst <k8s/base/crs-webservice/ingress.template >k8s/base/crs-webservice/ingress.yaml
	envsubst <k8s/base/crs-webservice/.dockerconfigjson.template >k8s/base/crs-webservice/.dockerconfigjson
	envsubst <k8s/base/crs-webservice/secrets.template >k8s/base/crs-webservice/secrets.yaml
	envsubst <k8s/base/crs-webservice/deployment.template >k8s/base/crs-webservice/deployment.yaml
	envsubst <k8s/base/cluster-issuer/secrets.template >k8s/base/cluster-issuer/secrets.yaml
	#check if $STAGING is set to false, otherwise applies staging template
	if [ "$STAGING" = false ]; then
		echo "STAGING is set to $STAGING, applying letsencrypt-prod.template"
		envsubst <k8s/base/cluster-issuer/letsencrypt-prod.template >k8s/base/cluster-issuer/letsencrypt.yaml
	else
		echo "STAGING is set to $STAGING, applying letsencrypt-staging.template"
		envsubst <k8s/base/cluster-issuer/letsencrypt-staging.template >k8s/base/cluster-issuer/letsencrypt.yaml
	fi

	#deploy AKS resources in Azure
	echo "Deploying AKS cluster Resources"
	terraform init
	terraform apply -auto-approve

	#set resource group name and kubernetes cluster name variables from terraform outputs

	KUBERNETES_CLUSTER_NAME=$(terraform output -raw kubernetes_cluster_name)
	RESOURCE_GROUP_NAME=$(terraform output -raw resource_group_name)

	echo "----------------------------------------------------"
	echo "KUBERNETES_CLUSTER_NAME is $KUBERNETES_CLUSTER_NAME"
	echo "RESOURCE_GROUP_NAME is $RESOURCE_GROUP_NAME"
	echo "----------------------------------------------------"
	echo "Retrieving credentials to access AKS cluster"
	#retrieve credentials to access AKS cluster

	az aks get-credentials --resource-group "$RESOURCE_GROUP_NAME" --name "$KUBERNETES_CLUSTER_NAME"

	#deploy kubernetes resources in AKS cluster
	kubectl apply -k k8s/base/cert-manager/
	kubectl wait --for condition=Established crd/certificates.cert-manager.io --timeout=60s
	kubectl wait --for condition=Established crd/clusterissuers.cert-manager.io --timeout=60s
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n cert-manager --timeout=300s
	kubectl apply -k k8s/base/crs-webservice/
	kubectl apply -k k8s/base/ingress-nginx/
	kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' -n crs-webservice ingress/crs-webapp --timeout=5m
	ingress_ip=$(kubectl get ingress -n crs-webservice crs-webapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
	echo "ingress IP is $ingress_ip"
	kubectl apply -k k8s/base/cluster-issuer/

	echo "Updating DNS records with ingress IP"
	az network dns record-set a delete --resource-group "$AZ_DNS_RESOURCE_GROUP" --zone-name "$AZ_DNS_ZONE_NAME" --name "$AZ_DNS_A_RECORD" -y
	az network dns record-set a create --resource-group "$AZ_DNS_RESOURCE_GROUP" --zone-name "$AZ_DNS_ZONE_NAME" --name "$AZ_DNS_A_RECORD"
	az network dns record-set a add-record --resource-group "$AZ_DNS_RESOURCE_GROUP" --zone-name "$AZ_DNS_ZONE_NAME" --record-set-name "$AZ_DNS_A_RECORD" --ipv4-address "$ingress_ip" --ttl 180

}

#destroy the AKS cluster and kubernetes resources function
down() {
	echo "Destroying AKS cluster"
	terraform apply -destroy -auto-approve
	echo "Removing the DNS record, $AZ_DNS_A_RECORD, from the DNS zone, $AZ_DNS_ZONE_NAME, in the resource group, $AZ_DNS_RESOURCE_GROUP"
	az network dns record-set a delete --resource-group "$AZ_DNS_RESOURCE_GROUP" --zone-name "$AZ_DNS_ZONE_NAME" --name "$AZ_DNS_A_RECORD" -y

}

case $1 in
up)
	up
	;;
down)
	down
	;;
*)
	echo "The only acceptable arguments are up and down"
	;;
esac
