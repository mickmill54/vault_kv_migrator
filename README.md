# login
export VAULT_ADDR=https://vault.keybank.com
vault login -method=ldap mount=ad username=millemv
TOKEN=$(vault print token) | vault token lookup $TOKEN

# logout
rm ~/.vault-token

# check the status
vault status

# create a secretes engine
vault secrets enable -path=kv kv-v2
vault kv enable-versioning kv
vault write kv/config max_versions=4

# create ad groups
vault write auth/ad/groups/app-gcp-cloudadmin policies=admins,cnn,gkeop
vault write auth/ad/groups/app-gke-admin policies=admins,cnn,gkeop
vault write auth/ad/groups/app-gcp-support policies=cnn,gkeop
vault read auth/ad/groups/app-gcp-cloudadmin
vault read auth/ad/groups/app-gke-admin
vault read auth/ad/groups/app-gke-support
vault list auth/ad/groups

# create a policy
vault policy write admins ./admins-policy.hcl
vault policy write cnn ./cnn-policy.hcl
vault policy write gkeop ./gkeop-policy.hcl
vault policy list
vault policy read admins

# create 2 secrets
vault kv put kv/gkeop/test test=12345
vault kv put kv/cnn/test test=12345

vault kv list kv/gkeop
vault kv list kv/cnn

vault kv list -format=json kv/gkeop

# Terraform Vault Provider Info
## This is a good starter: 
https://learn.hashicorp.com/tutorials/vault/codify-mgmt-enterprise
https://registry.terraform.io/providers/hashicorp/vault/latest/docs