# tz-jenkins

## jenkins setting
``` 
http://dooheehong323:31000/configure
Global properties > Environment variables > Add
ORGANIZATION_NAME: doohee323
YOUR_DOCKERHUB_USERNAME: doohee323
```

## git clone a test project
```
mkdir -p tz-k8s-vagrant/projects
git clone https://github.com/doohee323/tz-py-crawlery.git

## Add a Credentials for Github
 http://98.234.161.130:31000/credentials/store/system/domain/_/newCredentials
 ex) Jenkins	(global)	dockerhub	doohee323/****** (GitHub)
    Username: doohee323 # github id
    Password: xxxx   // d465eaa43af65cececde0a63e310c2bd24af375b
    ID: GitHub
    Owener: tz
    registryCredential = 'GitHub'
 cf) https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/creating-a-personal-access-token
```

## Add a Credentials for dockerhub
```
 http://98.234.161.130:31000/credentials/store/system/domain/_/newCredentials
 ex) Jenkins	(global)	dockerhub	doohee323/****** (dockerhub)
    registryCredential = 'dockerhub'
```

## make a project in Jenkins
```
new item
name: tz-py-crawler
type: multibranch Pipeline
Display Name: tz-py-crawler
Branch Sources: GitHub
    Credential: Jenkins
        Username: doohee323 # github id
    
Repository HTTPS URL: https://github.com/doohee323/tz-py-crawler.git

Run the project
```

## checking the result 
```
k get all | grep crawlery
service/tz-py-crawlery   NodePort    10.97.78.220    <none>        8080:30020/TCP                   19m

curl http://10.97.78.220:8080
```

## test with nginx-ingress 
```

k apply -f jenkins-ingress.yaml
curl http://crawler.eks-devops.tzcorp.com

curl -d "watch_ids=ioNng23DkIM" -X POST http://crawler.eks-devops.tzcorp.com/crawl
curl -d "watch_ids=ioNng23DkIM" -X POST http://ab7dde4e472214d688fd8a9c844f0bd1-1145051925.us-west-1.elb.amazonaws.com:8000/crawl
curl -X GET http://ab7dde4e472214d688fd8a9c844f0bd1-1145051925.us-west-1.elb.amazonaws.com:8000/crawl?watch_ids=ioNng23DkIM

```
