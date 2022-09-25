# did not find way when use foreach and dependsOn in Terraform, use powershell to dynamic add new resource after storage account was created
# if you have better idea to handle this, please let me know

if (Test-Path 'storage.1.container.tf') {remove-item 'storage.1.container.tf'}
if (Test-Path 'storage.2.fileupload.tf'){ remove-item 'storage.2.fileupload.tf'}
terraform apply -auto-approve
if (Test-Path 'storage.1.container.tf.txt')
{
    copy-item storage.1.container.tf.txt storage.1.container.tf
    terraform apply -auto-approve
}
if (Test-Path 'storage.2.fileupload.tf.txt')
{
    copy-item storage.2.fileupload.tf.txt storage.2.fileupload.tf
    terraform apply -auto-approve
}
