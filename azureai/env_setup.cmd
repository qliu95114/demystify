:: Microsoft Azure OpenAI Account Application and GPT-3.5 Deployment
:: This README file provides instructions on how to apply for a Microsoft Azure OpenAI endpoint and create a deployment with the GPT-3.5-16k model. It also explains how to obtain the endpoint, key, and deployment name required for accessing the deployment.

:: ## Prerequisites
:: - Microsoft Azure subscription

:: ## Applying for Microsoft Azure OpenAI Account
:: 1. Go to the [Microsoft Azure Portal](https://portal.azure.com) and sign in with your Azure account credentials.
:: 2. Select the **OpenAI** listing and click on **Create**.
:: 3. Fill in the necessary details, such as subscription, resource group, and other required information.
:: 4. Review and accept the terms and conditions, then click on **Create** to begin the deployment process.

:: ## Creating a Deployment with GPT-3.5-16k Model
:: 1. Once your Azure OpenAI account is set up, navigate to the **Azure Portal** and sign in.
:: 2. Locate the OpenAI resource you created during the application process.
:: 3. Select the resource and navigate to the **Manage Deployments** tab, it will open https://oai.azure.com in a new browser tab
:: 4. Click on **New Deployment** to create a new deployment, give it a name and description.

:: In light of the recent API token limitations (1106 token), it is advisable to adhere to the standard naming convention for new deployments. 
:: Additionally, it is recommended to transition from using the "Environment" method to the "$env:USERPROFILE\.azureai\azureai_config.json" method.

:: DeploymentName
:: gpt-35-turbo-16k_0613
:: gpt-35-turbo_0613
:: gpt-35-turbo-16k_0613
:: gpt-35-turbo_0613
:: gpt-35-turbo_1106
:: gpt-4-32k_0613
:: gpt-4_0613
:: gpt-4_1106-preview

:: 5. Choose the **GPT-3.5-16k** model from the available options.
:: 6. Configure the deployment settings according to your requirements. 
:: 7. Review the configuration and click on **Create Deployment** to start the deployment process.
:: 8. Deployment might take 15 minutes to completed

:: ## Obtaining the Endpoint, Key, and Deployment Name
:: 1. After the deployment is successfully created, go to the **Azure Portal**.
:: 2. Navigate to the OpenAI resource you created and select the **Kyes and Endpoint** 
:: 3. Use Either Key1 or Key2, click copy and paste to **OPENAI_API_KEY_AZURE** below
:: 4. Find Endpoint, click copy and paste to **OPENAI_ENDPOINT_AZURE** below
:: 2. Select the **Model deployments**, Click **Manage Deployments**, it will open https://oai.azure.com in a new browser tab. 
:: 3. Locate the name of deployment you created and copy and paste to **OPENAI_ENGINE_AZURE** below 

:: After setup the Azure Open AI, please use the powershell .\build_azureai-config.ps1 to create the config file (v2 configuration)
:: The config file will be created in the following location: $env:USERPROFILE\.azureai\azureai_config.json

:: command sample. please include your subid where you create the Azure Open AI account
.\build_azureai-config.ps1 %subid%

:: the following is the (v1 configuration), please do not use it

:: With the endpoint, key, and deployment name, you can now execute the batch file below to set the environment variables required for accessing the deployment.
:: Reminder: Do not, Do not, Do not git commit your personal key, endpoint, and deployment name to the repository.

:: Please refrain from using both OPENAI_TOKENS_AZURE and OPENAI_MAXTOKENSOUTPUT_AZURE or OPENAI_MAXTOKENSINPUT_AZURE. 
:: If using one of the token configuration settings, ensure that the other is set to empty.

:: For example, you can either:
:: 1. SETX OPENAI_TOKENS_AZURE ""
::    SETX OPENAI_MAXTOKENSOUTPUT_AZURE "4096"
::    SETX OPENAI_MAXTOKENSINPUT_AZURE "128000"

:: 2. SETX OPENAI_TOKENS_AZURE "32678"
::    SETX OPENAI_MAXTOKENSOUTPUT_AZURE ""
::    SETX OPENAI_MAXTOKENSINPUT_AZURE ""

rem SETX OPENAI_API_KEY_AZURE "<Input your API key here>"
rem SETX OPENAI_ENGINE_AZURE "<Input Deployment Name>"
rem SETX OPENAI_ENDPOINT_AZURE "https://<Azure AI Endpoint>.openai.azure.com/"
:: SETX OPENAI_TOKENS_AZURE "32768"  
rem SETX OPENAI_TOKENS_AZURE ""  
rem SETX OPENAI_MAXTOKENSOUTPUT_AZURE "4096"  
rem SETX OPENAI_MAXTOKENSINPUT_AZURE "128000"  

:: OPENAI_TOKENS_AZURE is the maxtokens please refer the link https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models#model-summary-table-and-region-availability
:: for summary https://github.com/qliu95114/demystify/blob/main/azureai/model_readme.md 

:: NEW AI connection string plan
:: "endpoint=https://<Azure AI Endpoint>.openai.azure.com/;key=<Input your API key here>;deployment=<Input Deployment Name>;model=GPT-3.5-16k;maxtokens=16384" 

