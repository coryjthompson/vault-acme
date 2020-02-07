FROM neilpang/acme.sh

RUN apk add jq bash
RUN wget https://releases.hashicorp.com/vault/1.3.2/vault_1.3.2_linux_amd64.zip && unzip vault_1.3.2_linux_amd64.zip -d /usr/local/bin/ && rm vault_1.3.2_linux_amd64.zip

ADD entrypoint.sh /entrypoint.sh

VOLUME /output

ENTRYPOINT ["/entrypoint.sh"]
