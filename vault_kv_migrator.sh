#!/bin/bash
#====================================================================================================================
# Name:         vault_kv_migrator.sh
# Created by:   Mick Miller
# Created on:   2020-12-15
# Updated on:   check github commits
# References: 
#   https://github.com/hashicorp/vault/issues/5275
#   https://stackoverflow.com/questions/60932147/hashicorp-vault-export-key-from-one-vault-import-into-another-vault
# ===================================================================================================================

# TODO:
# summary page at the end with stats
# - For example: time to run, number of directories and keys, etc.


set -e
clear

# Get command line args and put them in an array
ARGS=( "$@" )
NUM_ARGS=( "$#" )

# Get tokens and path from args
SRC_TOKEN="${ARGS[1]}"
DST_TOKEN="${ARGS[3]}"
VAULT_PATH="${ARGS[5]}"

# Run time parameters
CONFIG_FILE="./config.yaml"

# Command line arg missing
function cmd_line_error {
  arg1="${1}"
  echo
  echo ===============================================================================
  echo "Command line arguments descirption."
  echo "You typed:" "${0}" -s "${SRC_TOKEN}" -d "${DEST_TOKEN}" -p "${VAULT_PATH}"
  echo
  echo "Usage: "
  echo "format : " "${0} " {source token} {destination token} {path}
  echo "example: " "${0} " "-s xxxxxxx -d xxxxxxx -p /secret/cnn/"
  echo "Note: trailing slash in path is important"
  echo "$arg1"
  echo ===============================================================================
}

# Start of job logging
function start_job {
  arg1="${1}"
  echo
  echo ===============================================
  echo Start "${arg1}....."
  echo
}

# End of job logging
function end_job {
  arg1="${1}"
  echo
  echo Done "${arg1}"
  echo ===============================================
  echo
}

# Test for vault installed
function test_for_vault {
  ver_vault=$(vault version)
  if [[ ${?} -ne 0 ]]; then
    cmd_line_erros "Error - Can't find a version of vault in the current path"
    exit
  fi
}

# Test for jq installed
function test_for_jq {
  ver_jq=$(jq --version)
  if [[ $? -ne 0 ]]; then
    cmd_line_erros "Error - Can't find a version of jq in the current path"
    exit
  fi
}

# Read command line variables
function test_cmd_line_args {
  if [[ "${NUM_ARGS}" -ne 6 ]]; then
    cmd_line_error "Error - Incorrect command line arguments"
    exit
  fi
}

# Check for trailing slash in path
function test_for_trailing_slash {
  if [[ "${VAULT_PATH}" != */ ]]; then 
    cmd_line_error "Error - Missing trailing slash in path" 
    exit
  fi
}

# Load configuration yaml file
function load_config {
  if [[ -f "${CONFIG_FILE}" ]]; then 
    cmd_line_error "Error - Missing ${CONFIG_FILE} in current path" 
    exit
  else
    # load the file variables
    TMP_FILE=$(cat ./config.json | jq .tmp_file)
    TYPE_VAL=$(cat ./config.json | jq .type_val)
    SRC_URL=$(cat ./config.json | jq .dv_url)
    SRC_URL=$(sed -e 's/^"//' -e 's/"$//' <<<$SRC_URL) # remove double quotes
    DEST_URL=$(cat ./config.json | jq .dv_url)   
    DEST_URL=$(sed -e 's/^"//' -e 's/"$//' <<<$DEST_URL) # remove double quotes
    # Run time parameters
  fi
}

# Get all list of all key paths then recuse path for all keys values.
function get_keys_from_dev {

  if [[ "$VAULT_PATH" ]]; then
    # Make sure the path always end with '/'
    VAULTS=("${VAULT_PATH%"/"}/")
    # echo "DEBUG ${LINENO}: Using this path: $VAULT_PATH"
  else
    # Get a list of all secrets engines of a specific type if no path provided.  TODO - Not sure I need this test
    VAULTS=$(vault secrets list -format=json | jq -r 'to_entries[] | select(.value.type == "$TYPE_VAL") | .key')
    # echo "DEBUG ${LINENO}: Found these vaults $VAULTS"
  fi
  
  # Might not need a for loop here because I am passing in the path
  for VAULT in "${VAULTS}"; do
    # echo "DEBUG ${LINENO}: Main for loop control given path: " $VAULT "in" $VAULTS
    recurse "${VAULT}"
  done
}

# Recursive function that will
# - List all the secrets in the given $PATH
# - Call itself for all path values in the given $PATH
function recurse {
    arg1="$1"
    # echo "DEBUG ${LINENO}: Recuse with agrument: " $arg1
    
    # Set to source vault
    export VAULT_TOKEN="$SRC_TOKEN"
    export VAULT_ADDR=$SRC_URL
    local readonly KEY_PATH="${arg1}"

    # List all folders for a given path 
    LIST_DIRS_KEYS=$(vault kv list -format=json "${KEY_PATH}" 2>&1)
    # echo "DEBUG ${LINENO}: Keys under: $arg1" "$LIST_DIRS_KEYS"
    status="${?}"
    if [ ! "${status}" -eq 0 ];
    then
        if [[ "${LIST_DIRS_KEYS}" =~ "permission denied" ]]; then
            return
        fi
        >&2 echo "DEBUG ${LINENO}: ${LIST_DIRS_KEYS}"
    fi

    # Read the keys in json format 
    for SECRET in $(echo "${LIST_DIRS_KEYS}" | jq -r '.[]'); do
        # echo "DEBUG ${LINENO}: For loop secret:  $SECRET in $LIST_DIRS_KEYS"
        if [[ "${SECRET}" == */ ]]; then # found a parent folder, recurse the folder for keys
            # echo "DEBUG ${LINENO}: Found parent folder at $KEY_PATH$SECRET"
            recurse "${KEY_PATH}${SECRET}"
        else # no trailing slash means this is a key and not a folder or subfolder
            echo =====================================================================================================
            # echo "DEBUG ${LINENO}: Found key at $KEY_PATH$SECRET"
            JSON_KEY=$(vault kv get -format=json -field data ${KEY_PATH}${SECRET})
            # echo "DEBUG ${LINENO}: Found key values $JSON_KEY" " - call write_key_to_prod"
            write_key_to_prod "${JSON_KEY}" "${KEY_PATH}${SECRET}"
        fi
    done
}

function write_key_to_prod {
  JSON_KEY2="${1}"
  KEY_PATH2="${2}"

  # production vault
  export VAULT_TOKEN="${DST_TOKEN}"
  export VAULT_ADDR="${DST_URL}"
  
  # echo "DEBUG ${LINENO}: Destination token: "
  # TOKEN=$(vault print token) | vault token lookup -format=json $TOKEN | jq .data.id
  
  echo "Get key from DV path: " "${KEY_PATH2}${SECRET2}"
  DST_PATH="${KEY_PATH2/secret/kv}"
  echo "Write key to destination path: " "${DST_PATH}"   
  # echo "DEBUG ${LINENO}: Put key values      : " $JSON_KEY2
  echo "${JSON_KEY2}" > "${TMP_FILE}" 2>&1

  echo -----------------------------------------------------------------------------------------------------
  echo "Creating new key in vault PR ${DST_PATH}"

  PUT_RESULT=$(vault kv put "${DST_PATH}" @"${TMP_FILE}" 2>&1)
  # echo $PUT_RESULT
  
  # GET_RESULT=$(vault kv get $DST_PATH)
  # echo "DEBUG ${LINENO}: Current KV = " $GET_RESULT 
  echo =====================================================================================================
  echo
  
  # set back to dev vault
  export VAULT_TOKEN="${SRC_TOKEN}"
  export VAULT_ADDR="${SRC_URL}"
  
  # echo ""DEBUG ${LINENO}:Source token: " 
  # TOKEN=$(vault print token) | vault token lookup -format=json $TOKEN | jq .data.id
  echo "Start reading new key..."
}

function list_new_keys {
  arg1=$1
  echo =====================================================================================================
  echo "List vault keys for input path: ${arg1}"
  echo
  vault kv list "${arg1}"
  echo =====================================================================================================
}

function clean_up_tmp_file {
  result=$(rm -fv ./tmp.json)
  echo "Cleaning up tmp file: " $result
}

# ========================
# main
# ========================
# Pre-flight tests
test_for_vault
test_for_jq
test_cmd_line_args
test_for_trailing_slash

# Load the configs files and initialize variables
load_config

# Iterate on all kv engines or start from the path provided by the user
start_job " Hashi Vault migration..."

get_keys_from_dev
list_new_keys "${VAULT_PATH}"
clean_up_tmp_file

end_job " Hashi Vault migration."