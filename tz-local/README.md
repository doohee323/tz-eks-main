#  After provisioning

* https://www.youtube.com/watch?v=L61rrblwnXI
* https://www.youtube.com/watch?v=e6hsnn9iiN0

## Install Rancher and import a k8s cluster
``` 
    1. in aws master node

        ssh -i ~/.ssh/mykeypair ubuntu@xxxxxxx
        cd /home/ubuntu
        sudo bash rancher.sh

    2. Add cluster in rancher siate
        ex) https://13.52.140.204/g/clusters
        Register an existing Kubernetes cluster
        Other Cluster
            Cluster Name: tz-k8x
    
        curl --insecure -sfL https://13.52.140.204/v3/import/c7s225v4f9mkqnz7jtnqtvwb5m6s9pfr5mbs2lh699rd7hck26kqz2_c-gchfl.yaml | kubectl apply -f -

    3. run the script
        wget https://13.52.140.204/v3/import/c7s225v4f9mkqnz7jtnqtvwb5m6s9pfr5mbs2lh699rd7hck26kqz2_c-gchfl.yaml --no-check-certificate
        kubectl apply -f c7s225v4f9mkqnz7jtnqtvwb5m6s9pfr5mbs2lh699rd7hck26kqz2_c-gchfl.yaml
``` 

## Install a storage(longhorn)
``` 
    In rancher,
    tz-k8s > Default > Apps > Launch
    Search Longhorn and install by default

    Go to "Cluster Explorer"
    under "Apps & Marketplace", click Longhorn
```

## Install a storage(EBS)
``` 
    In rancher,
    tz-k8s > Storage > Storage classes
    Add Storage Class
        - Provisioner: Amazone EBS Disk
        - Name: tz-ebs
        - Customize
            Allow Volume Expansion: Enabled
    Set As Default
```

## Add AWS credential / node template
``` 
    In rancher,
    User profile > Cloud Credentials > Add Cloud Credential
        - name: mycred
        - Cloud Credential Type: Amazon
        - Region: us-west-1
        - Access Key: xxx
        - Secret Key: xxx
    Node Templates > Add Templates
        - Region: us-west-1
        - AMI: ami-0b382b76fadc95544
        - IAM Instance Profile Name: k8s-master-role
        - tz-tempalte
```

## Add a new cluster
``` 
    In rancher,
    Add Cluster - Amazon EKS
        - Name: tz-eks
        - Region: us-west-1
        


```

## Install Nexus
``` 
    In rancher,
    Tools > Catalogs > Add Catalog
        - Name: sonatype
        - Catalog URL: https://oteemo.github.io/charts
        - Helm Version: Helm v3

    In rancher,
    tz-k8s > Default > Apps > Launch
    Search sonatype-nexus and install by default



```





 
