# Makefile

# Variables
SCRIPT := crs-architecture.sh
GENERATED_FILES := k8s/base/crs-webservice/ingress.yaml \
                   k8s/base/crs-webservice/.dockerconfigjson \
                   k8s/base/crs-webservice/secrets.yaml \
                   k8s/base/crs-webservice/deployment.yaml \
		   k8s/base/tailscale-coredns/coredns-custom.yaml \
		   k8s/base/tailscale-operator/operator.yaml 

# Default target when just running `make`
.PHONY: help
help:
	@echo "Usage:"
	@echo "  make up     # Deploys the AKS cluster and resources"
	@echo "  make down   # Destroys the AKS cluster and resources"
	@echo "  make clean  # Removes generated files from templates (optional)"

#check script exists and is executable
.PHONY: check
check:
	@test -f $(SCRIPT) || (echo "Error: $(SCRIPT) not found" && exit 1)
	@test -x $(SCRIPT) || (echo "Error: $(SCRIPT) not executable" && exit 1)

# up target
.PHONY: up
up: check clean
	@bash $(SCRIPT) up

# down target
.PHONY: down
down: check
	@bash $(SCRIPT) down

# Clean up generated files (optional)
.PHONY: clean
clean:
	@rm -f $(GENERATED_FILES)
