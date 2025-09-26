targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

var abbrs = loadJsonContent('./abbreviations.json')

var logAnalyticsName = '${abbrs.operationalInsightsWorkspaces}${environmentName}'
var applicationInsightsName = '${abbrs.insightsComponents}${environmentName}'
var keyVaultName = take(toLower(replace('${abbrs.keyVaultVaults}${environmentName}', '-', '')),24)
var containerRegistryName = toLower(replace('${abbrs.containerRegistryRegistries}${environmentName}', '-', ''))
var storageAccountName = take(toLower(replace('${abbrs.storageStorageAccounts}${environmentName}', '-', '')), 24)
var virtualNetworkName = '${abbrs.networkVirtualNetworks}${environmentName}'

//the combined workspacename and instance name need to be until 24 characters
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var shortWorkspaceName = take('${abbrs.machineLearningServicesWorkspaces}${resourceToken}', 18)
var instanceName = take('ci${resourceToken}', 6) // but keep it 'unique' for multiple deployments

var subnets = [
  {
    // Default subnet (generally not used)
    name: 'Default'
    addressPrefix: '10.0.0.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
  {
    // AiServices Subnet (AI Foundry Hub, AI Search, AI Services private endpoints)
    name: 'AiServices'
    addressPrefix: '10.0.1.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
  {
    // Data Subnet (Storage, Key Vault, Container Registry)
    name: 'Data'
    addressPrefix: '10.0.2.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
  {
    // Management Subnet (Log Analytics, Application Insights) - Not used yet
    name: 'Management'
    addressPrefix: '10.0.3.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
  {
    // Bastion Gateway Subnet
    name: 'AzureBastionSubnet'
    addressPrefix: '10.0.255.0/27'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
]

// ---------- RESOURCE GROUP ----------

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'virtualNetwork'
  scope: rg
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    subnets: subnets
    tags: tags
    ddosProtectionPlanResourceId: null // Corrected parameter name
  }
}

// ---------- PRIVATE DNS ZONES (REQUIRED FOR NETWORK ISOLATION) ----------

module storageFilePrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: 'storage-file-private-dns-zone'
  scope: rg
  params: {
    name: 'privatelink.file.${environment().suffixes.storage}'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

module storageBlobPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: 'storage-blob-private-dns-zone'
  scope: rg
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

module aiHubApiMlPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: 'ai-hub-apiml-private-dns-zone'
  scope: rg
  params: {
    name: 'privatelink.api.azureml.ms'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

module aiHubNotebooksPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' =  {
  name: 'ai-hub-notebooks-private-dns-zone'
  scope: rg
  params: {
    name: 'privatelink.notebooks.azure.net'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

module keyVaultPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: 'keyvault-private-dns-zone'
  scope: rg
  params: {
    name: 'privatelink.vaultcore.azure.net'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

module containerRegistryPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: 'container-registry-private-dns-zone'
  scope: rg
  params: {
    name: 'privatelink.azurecr.io'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

// ---------- STORAGE ACCOUNT ----------

module storageAccount 'br/public:avm/res/storage/storage-account:0.14.3' = {
  name: 'aml-storage-account-deployment'
  scope: rg

  params: {
    name: storageAccountName
    tags: tags
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    kind: 'StorageV2'
    location: location
    skuName: 'Standard_LRS'
    blobServices: {
      containers: [
        {
          name: 'default'
          publicAccess: 'None'
        }
      ]
      deleteRetentionPolicy: {
        enabled: true
        days: 7
      }
      containerDeleteRetentionPolicy: {
        enabled: true
        days: 7
      }
    }
    supportsHttpsTrafficOnly: true // Corrected parameter name
    enableHierarchicalNamespace: false // Corrected parameter name (was isHnsEnabled)
    largeFileSharesState: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Disabled'
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: storageBlobPrivateDnsZone.outputs.resourceId
            }
          ]
        }
        service: 'blob'
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[2] // Data subnet
        tags: tags
      }
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: storageFilePrivateDnsZone.outputs.resourceId
            }
          ]
        }
        service: 'file'
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[2] // Data subnet
        tags: tags
      }
    ]
  }
}

module registry 'br/public:avm/res/container-registry/registry:0.9.3' = {
  name: 'container-registry-deployment'
  scope: rg
  params: {
    name: containerRegistryName
    acrSku: 'Premium'
    location: location
    acrAdminUserEnabled: false
    networkRuleBypassOptions: 'AzureServices'
    exportPolicyStatus: 'disabled'
    publicNetworkAccess: 'Disabled'
    tags: tags
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: containerRegistryPrivateDnsZone.outputs.resourceId
            }
          ]
        }
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[2] // Data Subnet
        tags: tags
      }
    ]
  }
}

module vault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  name: 'key-vault-deployment'
  scope: rg
  params: {
    name: keyVaultName
    tags: tags
    enablePurgeProtection: false
    enableRbacAuthorization: true
    enableVaultForDeployment: true
    enableVaultForDiskEncryption: true
    enableVaultForTemplateDeployment: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: keyVaultPrivateDnsZone.outputs.resourceId
            }
          ]
        }
        service: 'vault'
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[2] // Data subnet
      }
    ]
    location: location
  }
}

//App Insights Workspace
module operationalworkspace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
  name: 'logAnalytics-workspace-deployment'
  scope: rg
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
  }
}

//Application Insights
module applicationInsights 'br/public:avm/res/insights/component:0.6.0' = {
  name: 'application-insights-deployment'
  scope: rg
  params: {
    name: applicationInsightsName
    workspaceResourceId: operationalworkspace.outputs.resourceId
    location: location
    tags: tags
  }
}

module workspace 'br/public:avm/res/machine-learning-services/workspace:0.13.0' = {
  name: 'workspaceDeployment'
  scope: rg
  params: {
    name: shortWorkspaceName
    sku: 'Standard'
    associatedApplicationInsightsResourceId: applicationInsights.outputs.resourceId
    associatedKeyVaultResourceId: vault.outputs.resourceId
    associatedStorageAccountResourceId: storageAccount.outputs.resourceId
    associatedContainerRegistryResourceId: registry.outputs.resourceId
    // computes: [
    //   {
    //     name: instanceName
    //     computeType: 'ComputeInstance'
    //     computeLocation: location
    //     location: location
    //     description: 'Default Instance'
    //     disableLocalAuth: false
    //     properties: {
    //       vmSize: 'STANDARD_DS11_V2'
    //     }
    //   }
    // ]
    location: location
    tags: tags
    publicNetworkAccess: 'Disabled'
    managedIdentities: {
      systemAssigned: true
    }
    hbiWorkspace: false
    managedNetworkSettings: {
      firewallSku: 'Standard'
      isolationMode: 'AllowOnlyApprovedOutbound'
      outboundRules: {
        rule2: {
          category: 'UserDefined'
          destination: 'pypi.org'
          type: 'FQDN'
        }
        rule3: {
          category: 'UserDefined'
          destination: {
            portRanges: '80,443'
            protocol: 'TCP'
            serviceTag: 'AppService'
          }
          type: 'ServiceTag'
        }
      }
    }
     privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: aiHubApiMlPrivateDnsZone.outputs.resourceId
            }
            {
              privateDnsZoneResourceId: aiHubNotebooksPrivateDnsZone.outputs.resourceId
            }
          ]
        }
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[1] // AiServices Subnet
        tags: tags
      }
    ]
    provisionNetworkNow: true
    systemDatastoresAuthMode: 'Identity'
    workspaceHubConfig: {
      defaultWorkspaceResourceGroup: rg.id
    }
  }
}

output RG_NAME string = rg.name
output WORKSPACE_ID string = workspace.outputs.resourceId
output WORKSPACE_NAME string = workspace.outputs.name
output WORKSPACE_INSTANCE_NAME string = instanceName
output STORAGE_ACCOUNT_ID string = storageAccount.outputs.resourceId
