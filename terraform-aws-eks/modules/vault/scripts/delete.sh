set -e
SECRETS=$(vault kv get -format=json "${TARGET_SECRET_PATH}" | jq '.data.data')
SECRETS=$(echo "${IMMUTABLE_SECRETS:-"{}"} ${SECRETS}" | jq -s '. as $i | $i[1] | delpaths($i[0]|keys_unsorted|map([.]))')
SECRETS=$(echo "${MUTABLE_SECRETS:-"{}"} ${SECRETS}" | jq -s '. as $i | $i[1] | delpaths($i[0]|keys_unsorted|map([.]))')
echo "${SECRETS}" | vault kv put ${TARGET_SECRET_PATH} - > /dev/null
vault kv get -format=json "${TARGET_SECRET_PATH}" | jq '.data.data'
