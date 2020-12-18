# Name: Vault kv migration tool
###### Partial Author: Mick Miller
###### Date: 2020-12-16

---
**Much thanks to these folks:**

vfauth     : https://github.com/hashicorp/vault/issues/5275
user2599522: https://stackoverflow.com/a/61000422

---

This bash script was built primary to migrate a ton of secrets from an old open-source version of Vault to Vault Enterprise.  Surprisingly there was no migration tool from Hashi at the time of this work.
˚
A couple of notes: 
- Backup your source secrets engine(s). 
- Understand what this script is doing before you run it and tweak as needed.
- You will need to configure the config.json file for your specific use case.

##### The config.json file:
This config file is used to reduce the amout of command line arguments and limit the command line arg to:
- The path to find the secrets
- Not storing the tokens in the cofigs or code

**config.json**
```sh
{ 
    "type_val": "general",
    "src_url": "https://old_vault.example.com",
    "dest_url": "https://new_vault.example.com",
    "tmp_file": "./tmp.json",
    "config_file":"./config.yaml"
}
```
**Explaination of keys and values**

| Key | Value |
| --- | ----- |
| type_value | type of secrets engine in the source vault instance |
| src_url | the source vault instance url |
| dest_url | the destination vault instance url |
| tmp_file | this is the name of the output temp json file. You should not need to change this value|
| config_file | the name of this file |


This code assumes that both the Hashi Vault client and jq are installed before you start.  There is a test for both of these in the script.

###### Simple install instructions that hopefully will work
macOS: If you are using brew package manager:
```
 $ brew install jq
 $ brew install vault
```
I only tested and ran this on macOS, but not on Windows or any Linux distributions. I will test Ubuntu at some point and refactor as needed.

---

####Here is a bunch of randomish stuff to get started.

Useful vault commands to get started

**login**
```
export VAULT_ADDR=https://vault.example.com
vault login -method=ldap mount=ad username=mick
```

**view login name**
```
TOKEN=$(vault print token) | vault token lookup $TOKEN
```

**vault logout, I know strange, but effective**
```
rm ~/.vault-token
```

**check the status**
```
vault status
```

**create a secretes engine**
```
vault secrets enable -path=kv kv-v2
vault kv enable-versioning kv
vault write kv/config max_versions=4
```

**create ad groups**
```
vault write auth/ad/groups/admin-group policies=admins,app1,app1
vault write auth/ad/groups/app-group policies=app1,app2
vault read auth/ad/groups/admin-group
vault read auth/ad/groups/app-group
vault list auth/ad/groups
```

**create a policy**
```
vault policy write admins ./admins-policy.hcl
vault policy list
vault policy read admins
```

**create 2 secrets**
```
vault kv put kv/anthos/test test=12345
vault kv put kv/gcp/test test=12345

vault kv list kv/anthos
vault kv list kv/gco
vault kv list -format=json kv/gcp
```

**Terraform Vault Provider Info**
*This is a good starting place to learn the provider:*
https://learn.hashicorp.com/tutorials/vault/codify-mgmt-enterprise
https://registry.terraform.io/providers/hashicorp/vault/latest/docs