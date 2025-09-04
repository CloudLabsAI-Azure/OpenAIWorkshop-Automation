targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = 'eastus'

param appServicePlanName string = ''
param webServiceName string = ''
// serviceName is used as value for the tag (azd-service-name) azd uses to identify
param serviceName string = 'web'

// Load the abbreviations.json file to use in resource names
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'B1'
    }
    kind: 'linux'
    reserved: true
  }
}

// The application frontend
module web './core/host/appservice.bicep' = {
  name: serviceName
  params: {
    name: !empty(webServiceName) ? webServiceName : '${abbrs.webSitesAppService}web-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.10'
    scmDoBuildDuringDeployment: true
    appCommandLine: 'python -m streamlit run app.py --server.port 8000 --server.address 0.0.0.0'
    appSettings: {
      AZURE_OPENAI_API_KEY: ''
      AZURE_OPENAI_ENDPOINT: 'https://.openai.azure.com/'
      AZURE_OPENAI_CHATGPT_DEPLOYMENT: 'gpt-35-turbo'
      AZURE_OPENAI_GPT4_DEPLOYMENT: ''
      SQLITE_DB_PATH: 'data/northwind.db'
    }  
  }
}

// App outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output REACT_APP_WEB_BASE_URL string = web.outputs.uri
