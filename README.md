# tz-eks-main
TZ's main eks cluster with terraform

* forked from https://github.com/terraform-aws-modules/terraform-aws-eks

## prep)
```
    1) copy aws configuration files
        resources/project   # change your project name, it'll be a eks cluster name.
        resources/config    # default profile required
        resources/credentials
    
        ex)
        vi resources/project
        project=eks-main

        vi resources/config
        [default]
        region = us-west-1
        output = json
        
        vi resources/credentials
        [default]
        aws_access_key_id = xxx
        aws_secret_access_key = xxx
```

## run)
```

    vagrant up
    vagrant ssh

    kubectl get nodes

    * see your cluster info.
    vi /vagrant/info

```

## remove)
``` 
    * before destroying, run eks_remove_all.sh first!
    vagrant ssh
    cd /vagrant/scripts
    sudo bash eks_remove_all.sh
    exit

    vagrant destroy -f
```

## jenkins)
``` 
    curl http://jenkins.eks-main.tzcorp.com
    if project name is eks-devops rather than eks-main,
        curl http://jenkins.eks-devops.tzcorp.com

    
```

## Ref.
``` 
    * After running it, these files are changed, but don't commit them.
    terraform-aws-eks/local.tf
    terraform-aws-eks/workspace/base/locals.tf
```

## https://weaveworks-gitops.awsworkshop.io/
## https://tf-eks-workshop.workshop.aws/000_workshop_introduction.html
## https://itnext.io/a-kubefed-tutorial-to-synchronise-k8s-clusters-86108194ed79
## https://betterprogramming.pub/build-a-federation-of-multiple-kubernetes-clusters-with-kubefed-v2-8d2f7d9e198a
## https://www.youtube.com/watch?v=PSwLdpH0vak


