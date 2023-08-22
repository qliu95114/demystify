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

:: With the endpoint, key, and deployment name, you can now execute the batch file below to set the environment variables required for accessing the deployment.
:: Reminder: Do not, Do not, Do not git commit your personal key, endpoint, and deployment name to the repository.

SETX OPENAI_API_KEY_AZURE "<Input your API key here>"
SETX OPENAI_ENGINE_AZURE "<Input Deployment Name>"
SETX OPENAI_ENDPOINT_AZURE "https://<Azure AI Endpoint>.openai.azure.com/"