# Azure Marketplace Application Sample with ARM Testing

This project demonstrates a sample Azure Marketplace Managed Application with integrated ARM template testing capabilities. It includes both the application structure and testing framework using the `arm-ttk` PowerShell module.

## Features

- Complete Marketplace Managed Application structure
- Local ARM template testing via Docker
- Automated testing through GitHub Actions
- Sample UI definitions for Marketplace deployment
- Deployment scripts for local testing

## Getting Started

These instructions will help you set up the project for development, testing, and marketplace deployment.

### Prerequisites

- Docker installed on your machine (for local testing)
- GitHub repository with Actions enabled (for CI/CD)
- Azure CLI installed (for deployment)
- Azure subscription with appropriate permissions

### Setup

1. **Create a `.env` file** in the root directory with the following variables:

    ```env
    AZURE_LOCATION=eastus
    MANAGED_APP_NAME=storage-account
    RESOURCE_GROUP_NAME=marketplace-app
    AZURE_SUBSCRIPTION_ID=your-subscription-id
    ```

> Note: This solution mounts the azure cli context into the container.  Mac to Linux.  CLI version mismatch can occur.


### Execution

1. Navigate to the project root directory.
2. Run the following command to build and test:

    ```bash
    docker compose up --build
    ```

    This will:
    - Build a Docker image with the ARM TTK tools
    - Mount your `src` directory containing ARM templates
    - Run tests against all JSON files in the mounted directory
    - Use the provided access token to authenticate with Azure
    - Create necessary Azure resources
    - Package the application
    - Deploy it as a managed application definition

## Marketplace Publishing

### Prerequisites

- Access to [Partner Center](https://partner.microsoft.com)
- Completed company verification
- Azure Marketplace publisher account

### Publishing Process

1. Package the Application
   - Ensure all templates are in the `src` directory
   - UI definitions are in the `ui` directory
   - Run tests to verify template validity

2. Create/Update Partner Center Offer

#### Creating a New Offer
1. Navigate to [Partner Center](https://partner.microsoft.com)
2. Create a new Azure Application offer
3. Complete the offer setup:
   - Offer ID and setup
   - Properties and categories
   - Marketplace listings
   - Preview audience configuration
   - Technical configuration
   - Plan setup

#### Updating an Existing Offer
1. Navigate to your existing offer in Partner Center
2. Create a new plan or update an existing one
3. Upload the new application package
4. Update the version number
5. Publish the changes

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.