# tz-eks-main

## Bootstrap)
```
    1. copy resources like this
        tz-ek-main/resources
            .auto.tfvars
            config              # aws config
            credentials         # aws credentials
            project             # change your project name, it'll be a eks cluster name.
    
    2. run.
        export docker_user="doohee323"

        sh bootstrap.sh
        
    3. output
        ssh-key)
            terraform-aws-eks/workspace/base/eks-main-s
            terraform-aws-eks/workspace/base/eks-main-s.pub
        k8s config)        
            terraform-aws-eks/workspace/base/kubeconfig_eks-main-t
```

## vault
``` 
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

```
