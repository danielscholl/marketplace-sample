# Stage 1: ARM TTK Testing
FROM mcr.microsoft.com/cbl-mariner/base/core:2.0 as tester

# Install Dependencies for TTK
RUN tdnf update -y && tdnf install -y ca-certificates powershell unzip && \
    tdnf clean all

# Download and unzip the latest version of ARM TTK
RUN pwsh -c " \
    Invoke-WebRequest -Uri https://github.com/Azure/arm-ttk/releases/download/20240328/arm-ttk.zip -OutFile /tmp/arm-ttk.zip; \
    Expand-Archive -Path /tmp/arm-ttk.zip -DestinationPath /opt/arm-ttk; \
    "

# Set up workspace
WORKDIR /workspace

# Create output directory
RUN mkdir -p /workspace/output

# Command to run tests (will be executed after volume mount)
CMD ["pwsh", "-File", "/workspace/tests/test.ps1"]

# Stage 2: Azure CLI Deployment
FROM mcr.microsoft.com/azure-cli:latest as deployer

# Define build arguments
ARG AZURE_LOCATION
ARG MANAGED_APP_NAME
ARG RESOURCE_GROUP_NAME
ARG AZURE_SUBSCRIPTION_ID

# Set environment variables from build args
ENV AZURE_LOCATION=${AZURE_LOCATION:-eastus}
ENV MANAGED_APP_NAME=${MANAGED_APP_NAME:-storage-account}
ENV RESOURCE_GROUP_NAME=${RESOURCE_GROUP_NAME:-marketplace-app}
ENV AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}

# Install additional dependencies needed for deployment
RUN tdnf update -y && tdnf install -y jq zip && \
    tdnf clean all

# Set up workspace
WORKDIR /workspace


ENTRYPOINT ["/workspace/deploy.sh"]

