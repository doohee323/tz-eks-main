FROM doohee323/devops-utils2:latest

ARG eks_project=xxxxx
ENV eks_project=${eks_project}

ARG eks_domain=xxxxx
ENV eks_domain=${eks_domain}

ARG vault_token=xxxxx
ENV vault_token=${vault_token}

EXPOSE 22

COPY init.sh /init.sh
RUN chmod +x init.sh

CMD /bin/bash -c "/init.sh"
