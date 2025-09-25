# Azure Developer CLI (azd) Deployment

This project uses the [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/overview) for deployment.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- [Git](https://git-scm.com/)

## Getting Started

1. **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd <repository-directory>
    ```

2. **Login to Azure:**
    ```bash
    az login
    ```
3. **Provision and deploy resources using azd:**
    ```bash
    azd up
    ```

## Useful Commands

- `azd up` - Provisions resources and deploys the app in one step.
- `azd down` - Destroys all resources created by the deployment.

## Resources

- [Azure Developer CLI Documentation](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [Troubleshooting azd](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/troubleshoot)
