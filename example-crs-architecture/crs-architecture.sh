#!/usr/bin/env bash
set -e

#executes a series of terrafor, az cli, and kubernetes commands to deploy or destroy an example crs architecture

echo "----------------------------------------------------"
echo "Applying environment variables from ./env"
echo "----------------------------------------------------"
echo ""

source ./env

#deply the aks cluster and kubernetes resources function
deploy () {
     #deploy AKS resources in Azure
     echo "----------------------------------------------------"
     echo "Deploying AKS CLuster"
     echo "----------------------------------------------------"
     echo ""
     terraform apply -auto-approve

     #set resource group name and kubernetes cluster name variables from terraform outputs

     KUBERNETES_CLUSTER_NAME=$(terraform output -raw kubernetes_cluster_name)
     RESOURCE_GROUP_NAME=$(terraform output -raw resource_group_name)

     echo "----------------------------------------------------"
     echo "KUBERNETES_CLUSTER_NAME is $KUBERNETES_CLUSTER_NAME"
     echo "RESOURCE_GROUP_NAME is $RESOURCE_GROUP_NAME"
     echo "----------------------------------------------------"
     echo ""
     echo "----------------------------------------------------"
     echo "Retrieving credentials to acces AKS cluster"
     echo "----------------------------------------------------"
     echo ""
     #retrieve credentials to accesc AKS cluster

     az aks get-credentials --resource-group "$RESOURCE_GROUP_NAME" --name "$KUBERNETES_CLUSTER_NAME"

     #deploy kubernetes resources in AKS cluster
     kubectl apply -k k8s/base/
     kubectl apply -k k8s/ingress-controller/
     kubectl apply -k k8s/installcrds/
     kubectl wait --for=condition=established crd/clusterissuers.cert-manager.io --timeout=60s
     kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n cert-manager --timeout=300s
     set +e
     echo "The cert-manager webhook needs time to generate and propagate its self-signed certificates. Timeout=180s"
     sleep 180
     kubectl apply -k k8s/cert-manager/
     status=$?
     if [ $status -ne 0 ]; then
	  #This is a common issue with cert-manager's webhook validation.
	  echo "Restarting the cert-manager pods"
	  kubectl delete validatingwebhookconfigurations cert-manager-webhook
	  kubectl rollout restart deployment -n cert-manager cert-manager-webhook
          kubectl apply -k k8s/cert-manager/
     elif [ $status -eq 0 ]; then
         return
     fi
     
     set -e
}

#destroy the AKS cluster and kubernetes resources function
destroy () {     
     echo "----------------------------------------------------"
     echo "Destroying AKS CLuster"
     echo "----------------------------------------------------"
     echo ""
     terraform apply -destroy -auto-approve

}

case $1 in 
     deploy)
          deploy;;
     destroy)
          destroy;;
     *)
          echo "Acceptable argumentes are deploy and destroy"
esac	  

