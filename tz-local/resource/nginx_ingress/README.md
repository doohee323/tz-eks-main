# nginx-igress for each namespaces

## Install nginx-ingress all
``` 
    1. make a nginx-ingress-controller

    bash install.sh ${namespaces} ${eks_project} ${domain}
    ex) bash install.sh default eks-main tzcorp.com
            => curl http://test.default.eks-main.tzcorp.com
        bash install.sh ib-dev eks-main tzcorp.com
            => curl http://test.ib-dev.eks-main.tzcorp.com
        bash install.sh devops
            => curl http://test.devops.eks-main.tzcorp.com
        bash install.sh devops-dev eks-main tzcorp.com
            => curl http://test.devops-dev.eks-main.tzcorp.com
        bash install.sh devops-dev eks-main devops.kr
            => curl http://test.devops-dev.eks-main.tzcorp.com
        bash install.sh devops eks-main devops.kr
            => curl http://test.devops.eks-main.tzcorp.com

    2. make a ingress for the app
        cp nginx-ingress.yaml jenkins-ingress.yaml
        modify port in jenkins-ingress.yaml
        k create -f jenkins-ingress.yaml
        => curl http://jenkins.default.eks-main.tzcorp.com
           or curl http://jenkins.eks-main.tzcorp.com
```

## Reuse the ingress to other domain and namespace
``` 
    bash /vagrant/tz-local/resource/nginx_ingress/install_ext.sh devops mydevops.net
    ex) http://test.mydevops.net
```
