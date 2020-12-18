# Vault kv migration tool

**Author: Mick Miller**

**Date: 2020-12-16**

 

This bash script was built primarily to migrate a ton of secrets from an old, open-source version of Vault to Vault Enterprise. Surprisingly, there was no migration tool available from Hashicorp at the time of this work, so I created one.

## Contents

1. The config.json file
2. Installation instructions
3. Running the script
4. Useful commands and randomish stuff
5. References
6. Acknowledgements

A couple of notes before diving in: 

* Back up your source secrets engine(s). 
* Understand what this script is doing before you run it and tweak as needed.
* You will need to configure the config.json file for your specific use case.

> NOTE: You may notice the pattern `# echo "DEBUG ${LINENO}: "Some string"` in the script. This is used for debugging the script. I left them in for you in case you wanted to trace the code; sorry if it irritates you.

---

## 1. The config.json file

This configuration file is used to reduce the amout of command line arguments and limit the arguments to:

* The path to find the secrets; and
* Not storing the tokens in the configurations or code.

config.json

```
{ 
    "type_val": "general",
    "src_url": "https://old_vault.example.com",
    "dest_url": "https://new_vault.example.com",
    "tmp_file": "./tmp.json",
    "config_file":"./config.yaml"
}
```

### Explanation of keys and values

| Key           | Value                                                                           |
| ---           | -----                                                                           |
| `type_value`  | The type of secrets engine in the source vault instance                         |
| `src_url`     | The source vault instance URL                                                   |
| `dest_url`    | the destination vault instance URL                                              |
| `tmp_file`    | The name of the output temp JSON file; you should not need to change this value |
| `config_file` | The name of this file                                                           |

---

## 2. Installation instructions
=======

The code assumes that both the Hashi Vault client and jq are installed before you start and tests for the presence of both.

### Installing Vault and jq

If you are using the Homebrew package manager on mac OS, run the following:

```
 $ brew install jq
 $ brew install vault
```

This script has not been tested on Windows or Linux, only macOS. I will test Ubuntu at some point and refactor as needed.

### Installing the script

```
# Clone the repo and then change to the directory.
$ git clone <this repo url>
$ cd vault_kv_migration

# Run the script
$ vault_kv_migration.sh -s "${SRC_TOKEN}" -d "${DEST_TOKEN}" -p "${VAULT_PATH}"
Usage:
  Format : ./vault_kv_migrator.sh {source token} {destination token} {path}
  Example: ./vault_kv_migrator.sh -s xxxxxxx -d xxxxxxx -p /secret/cnn/
  Note   : A trailing slash in path is required."
```

---

## 3. Running the script

Command line arguments description

```
$ vault_kv_migration.sh -s "${SRC_TOKEN}" -d "${DEST_TOKEN}" -p "${VAULT_PATH}"

Usage:
  Format : ./vault_kv_migrator.sh {source token} {destination token} {path}
  Example: ./vault_kv_migrator.sh -s xxxxxxx -d xxxxxxx -p /secret/cnn/
  
  Note   : A trailing slash in path is required."
```  

---

## 4. Useful commands and randomish stuff

## Log in to Vault

```
export VAULT_ADDR=https://vault.example.com
vault login -method=ldap mount=ad username=mick
```

View login name**
```
TOKEN=$(vault print token) | vault token lookup $TOKEN
```

### Log out of Vault

I know; strange, but effective.

```
rm ~/.vault-token
```

### Check status

```
vault status
```

### Create a secretes engine

```
vault secrets enable -path=kv kv-v2
vault kv enable-versioning kv
vault write kv/config max_versions=4
```

### Create Active Directory groups

```
vault write auth/ad/groups/admin-group policies=admins,app1,app1
vault write auth/ad/groups/app-group policies=app1,app2
vault read auth/ad/groups/admin-group
vault read auth/ad/groups/app-group
vault list auth/ad/groups
```

### Create a policy

```
vault policy write admins ./admins-policy.hcl
vault policy list
vault policy read admins
```

### Create two secrets

```
vault kv put kv/anthos/test test=12345
vault kv put kv/gcp/test test=12345

vault kv list kv/anthos
vault kv list kv/gco
vault kv list -format=json kv/gcp
```

---

## 5. References

Below are a couple of good references for learning the Terraform Vault provder information:

* https://learn.hashicorp.com/tutorials/vault/codify-mgmt-enterprise
* https://registry.terraform.io/providers/hashicorp/vault/latest/docs

---

## 6. Acknowledgements

Many thanks to the following folks:

* agaudreault-jive (https://github.com/hashicorp/vault/issues/5275)
* user2599522 (https://stackoverflow.com/a/61000422)
* kir4h (https://github.com/kir4h/rvault)
