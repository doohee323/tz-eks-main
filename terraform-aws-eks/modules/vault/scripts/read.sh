vault kv get -format=json "${TARGET_SECRET_PATH}" | jq '.data.data'
