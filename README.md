# tz-eks-main

## Run)
```
    1. copy resources like this
        tz-ek-main/resources
            .auto.tfvars
            config              # aws config
            credentials         # aws credentials
            project             # change your project name, it'll be a eks cluster name.
    
    2. run.
        export docker_user="doohee323"
        export docker_passwd="hdh971097"
        
        sh bootstrap.sh
        
    3. output
        ssh-key)
            terraform-aws-eks/workspace/base/eks-main-s
            terraform-aws-eks/workspace/base/eks-main-s.pub
        k8s config)        
            terraform-aws-eks/workspace/base/kubeconfig_eks-main-t
```