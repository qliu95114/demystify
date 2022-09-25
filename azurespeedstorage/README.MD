# This script creates different storage account in regions (defined in var.tf -> var.locations)

1. It creates storage container (private/upload/public) and upload public/latency-test.json and private/100MB.bin to the containers

Limitation
1. Cannot find a way to co-exist for-each and dependsOn in Terraform to create Graph depedence, I use powershell dynamic add new resource after main.tf is complete, then add storage.1.container.tf.txt, then add storage.2.fileupload.tf.txt, 
1. To use the workaround, please assign subscriptionid and start from .\deploy.ps1 , (do not use terraform.exe directly)





