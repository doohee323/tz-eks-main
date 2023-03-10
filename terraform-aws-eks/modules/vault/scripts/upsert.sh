set -e
PREV_SECRETS=$(vault kv get -format=json "${TARGET_SECRET_PATH}" 2> /dev/null | jq '.data.data')
if [ -z "${PREV_SECRETS}" ]; then
  echo "${IMMUTABLE_SECRETS:-"{}"} ${MUTABLE_SECRETS:-"{}"}" | jq -s '.[0] * .[1]' | vault kv put ${TARGET_SECRET_PATH} - > /dev/null
else
  NEW_IMMUTABLE_SECRETS=$(echo "${IMMUTABLE_SECRETS:-"{}"} ${PREV_SECRETS:-"{}"}" | jq -s '. as $i | $i[0] | delpaths($i[1]|keys_unsorted|map([.]))')
  echo "${NEW_IMMUTABLE_SECRETS:-"{}"} ${MUTABLE_SECRETS:-"{}"}" | jq -s '.[0] * .[1]' | vault kv patch ${TARGET_SECRET_PATH} - > /dev/null
fi
vault kv get -format=json "${TARGET_SECRET_PATH}" | jq '.data.data'
