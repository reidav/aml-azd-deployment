# Prerequisites for Running `azd` with PowerShell 7

To use the Azure Developer CLI (`azd`) with PowerShell 7, ensure the following prerequisites are met:

## 1. PowerShell 7

- Install [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).

## 2. Azure Developer CLI (`azd`)

- Install the Azure Developer CLI:  
    ```powershell
    Invoke-WebRequest -Uri https://aka.ms/install-azd.ps1 -OutFile ./install-azd.ps1
    .\install-azd.ps1
    ```

## 3. Azure CLI (Optional but Recommended)

- Install the [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) for additional Azure management capabilities.

## 4. Git

- Install [Git](https://git-scm.com/downloads) for source control and repository management.

---

**Verify Installation:**
```powershell
pwsh --version
azd version
az --version
git --version
```