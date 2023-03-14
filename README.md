# tz-eks-main

## Bootstrap)
```
    -. copy resources like this
        tz-ek-main/resources
            .auto.tfvars
            config              # aws config
            credentials         # aws credentials
            project             # change your project name, it'll be a eks cluster name.
    
    -. run.
        export docker_user="doohee323"
        sh bootstrap.sh
        
    -. output
        ssh-key)
            terraform-aws-eks/workspace/base/eks-main-t
            terraform-aws-eks/workspace/base/eks-main-t.pub
        k8s config)        
            terraform-aws-eks/workspace/base/kubeconfig_eks-main-t
    
    -. into docker env.
        docker exec -it `docker ps | grep devops-utils-1 | awk '{print $1}'` bash
        root@8971909b818a:/# base
        root@8971909b818a:/vagrant/terraform-aws-eks/workspace/base# tplan
        
    -. remove all
        export docker_user="doohee323"
        sh bootstrap.sh remove
        
        After it's done, check VPC and S3 again!
```

## Manual settings
``` 
    1) vault unseal

    # vault operator unseal
    #echo k -n vault exec -ti vault-0 -- vault operator unseal
    #k -n vault exec -ti vault-0 -- vault operator unseal # ... Unseal Key 1
    #k -n vault exec -ti vault-0 -- vault operator unseal # ... Unseal Key 2,3,4,5
    #
    #echo k -n vault exec -ti vault-1 -- vault operator unseal
    #k -n vault exec -ti vault-1 -- vault operator unseal # ... Unseal Key 1
    #k -n vault exec -ti vault-1 -- vault operator unseal # ... Unseal Key 2,3,4,5
    #
    #echo k -n vault exec -ti vault-2 -- vault operator unseal
    #k -n vault exec -ti vault-2 -- vault operator unseal # ... Unseal Key 1
    #k -n vault exec -ti vault-2 -- vault operator unseal # ... Unseal Key 2,3,4,5
    
    bash /vagrant/tz-local/resource/vault/helm/install.sh
    bash /vagrant/tz-local/resource/vault/data/vault_user.sh
    bash /vagrant/tz-local/resource/vault/vault-injection/install.sh
    bash /vagrant/tz-local/resource/vault/vault-injection/update.sh
    
    2) Jenkins settings
    
        #kubectl -n jenkins cp jenkins-0:/var/jenkins_home/jobs/devops-crawler/config.xml /vagrant/tz-local/resource/jenkins/jobs/config.xml
        
        # k8s settings
        https://jenkins.default.${eks_project}.${eks_domain}/manage/configureClouds/
          Kubernetes
            Jenkins URL: http://jenkins.jenkins.svc.cluster.local
          WebSocket: check
          Pod Labels
            Key: jenkins
            Value: slave
        
        ## google oauth2
        client auth info > OAuth 2.0 client ID
          web application
          authorized redirection URI: https://jenkins.default.${eks_project}.${eks_domain}/securityRealm/finishLogin
        
        https://jenkins.default.${eks_project}.${eks_domain}/manage/configureSecurity/
          Disable remember me: check
          Security Realm: Login with Google
          Client Id: 613669517643-xxx
          client_secret: GOCSPX-xxx
```
