#!/bin/bash
set -e

args=""
while [ "$#" -gt 0 ]
do
  case $1 in
    -d|--domain)
      DOMAIN="$2"
      shift
      ;;
    -p|--password)
      PASSWORD="$2"
      shift
      ;;
    --vault_key)
      VAULT_KEY="$2"
      shift
      ;;
    --vault_token)
      export VAULT_TOKEN="$2"
      shift
      ;;
    --vault_addr)
      export VAULT_ADDR="$2"
      shift
      ;;
    *)
      args+=" $1"
      ;;
  esac
  shift
done

if [ -z "$DOMAIN" ]
then
  echo "A domain name is required. Provide one using the -d"
  exit 2
fi

mkdir -p "/acme.sh/$DOMAIN"

if [ -n "$VAULT_KEY" ]
then
  if ( $("vault kv get -format json $VAULT_KEY  > /dev/null 2>&1") ) ; then
    KEYS=$("vault kv get -format json $VAULT_KEY | jq .data.data")
    echo "$KEYS"  | jq -r .ca > "/acme.sh/$DOMAIN/ca.cer"
    echo "$KEYS" | jq -r .cer > "/acme.sh/$DOMAIN/$DOMAIN.cer"
    echo "$KEYS" | jq -r .conf > "/acme.sh/$DOMAIN/$DOMAIN.conf"
    echo "$KEYS" | jq -r .csr > "/acme.sh/$DOMAIN/$DOMAIN.csr"
    echo "$KEYS" | jq -r .csrconf > "/acme.sh/$DOMAIN/$DOMAIN.csr.conf"
    echo "$KEYS" | jq -r .cert > "/acme.sh/$DOMAIN/fullchain.cer"

    if [ -n "$PASSWORD" ]
    then
      echo "$KEYS" | jq -r .encryptedkey > "/acme.sh/$DOMAIN/$DOMAIN.key.encrypted"
      openssl rsa -in "/acme.sh/$DOMAIN/$DOMAIN.key.encrypted" -passin "pass:$PASSWORD" -out "/acme.sh/$DOMAIN/$DOMAIN.key"
    else
      echo "$KEYS" | jq -r .key > "/acme.sh/$DOMAIN/$DOMAIN.key"
    fi
  fi
fi

if [ -f "/acme.sh/$DOMAIN/$DOMAIN.key" ]; then
  acme.sh --renew -d "$DOMAIN" $args --dnssleep 60 || echo "No renew required"
else
  acme.sh --issue -d "$DOMAIN" $args --dnssleep 60
fi

if [ -n "$PASSWORD" ]; then
  openssl rsa -aes256 -in "/acme.sh/$DOMAIN/$DOMAIN.key" -passout "pass:$PASSWORD" -out "/acme.sh/$DOMAIN/$DOMAIN.key.encrypted"
  rm "/acme.sh/$DOMAIN/$DOMAIN.key"
fi

if [ -n "$VAULT_KEY" ]
then
  if [ -n "$PASSWORD" ]; then
    vault kv put "$VAULT_KEY" cert=@/acme.sh/"$DOMAIN"/fullchain.cer encryptedkey=@/acme.sh/"$DOMAIN"/"$DOMAIN".key.encrypted ca=@/acme.sh/"$DOMAIN"/ca.cer cer=@/acme.sh/"$DOMAIN"/"$DOMAIN".cer conf=@/acme.sh/"$DOMAIN"/"$DOMAIN".conf csr=@/acme.sh/"$DOMAIN"/"$DOMAIN".csr csrconf=@/acme.sh/"$DOMAIN"/"$DOMAIN".csr.conf
  else
    vault kv put "$VAULT_KEY" cert=@/acme.sh/"$DOMAIN"/fullchain.cer key=@/acme.sh/"$DOMAIN"/"$DOMAIN".key ca=@/acme.sh/"$DOMAIN"/ca.cer cer=@/acme.sh/"$DOMAIN"/"$DOMAIN".cer conf=@/acme.sh/"$DOMAIN"/"$DOMAIN".conf csr=@/acme.sh/"$DOMAIN"/"$DOMAIN".csr csrconf=@/acme.sh/"$DOMAIN"/"$DOMAIN".csr.conf
  fi
fi

mkdir -p /output/
cp /acme.sh/"$DOMAIN"/* /output/
