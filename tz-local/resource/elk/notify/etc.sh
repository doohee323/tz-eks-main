#!/usr/bin/env bash

###[apm]#######################

curl -L -O https://artifacts.elastic.co/downloads/apm-server/apm-server-7.5.0-amd64.deb
sudo dpkg -i apm-server-7.5.0-amd64.deb

sudo sed -i 's|host: "localhost:8200"|host: "0.0.0.0:8200"|g' /etc/apm-server/apm-server.yml
sudo sed -i 's|localhost:9200|elk.sodatransfer.com:9200|g' /etc/apm-server/apm-server.yml
sudo sed -i 's|#setup.kibana:|setup.kibana:|g' /etc/apm-server/apm-server.yml
sudo sed -i 's|#username: "elastic"|username: "elastic"|g' /etc/apm-server/apm-server.yml
sudo sed -i 's|#password: "changeme"|password: "sodatransfer!323"|g' /etc/apm-server/apm-server.yml

service apm-server restart

###[email]#######################
vi /etc/elasticsearch/elasticsearch.yml

/usr/share/elasticsearch/bin/elasticsearch-keystore add xpack.notification.email.account.ses_account.smtp.secure_password

xpack.notification.email.account:
  ses_account:
    smtp:
      auth: true
      starttls.enable: true
      starttls.required: true
      host: email-smtp.us-east-1.amazonaws.com 
      port: 587
      user: AKIAT22NDA53KYJTHVWA

/usr/share/elasticsearch/bin/elasticsearch-keystore add xpack.notification.email.account.gmail_account.smtp.secure_password
/usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.notification.email.account.gmail_account.smtp.secure_password

xpack.notification.email.account:
  gmail_account:
    profile: gmail
      smtp:
        auth: true
        starttls.enable: true
        host: smtp.gmail.com
        port: 587
        user: doohee323@gmail.com

/usr/share/elasticsearch/bin/elasticsearch-keystore list 

POST _watcher/watch/_execute
{
  "watch": {
    "trigger": {
      "schedule": {
        "interval": "1m"
      }
    },
    "input": {
      "simple": {
      }
    },
    "actions": {
      "send_email": {
        "email": {
          "to": "doohee323@gmail.com",
          "subject": "subject11",
          "body": {
            "html": "HTML22222"
          }
        }
      }
    }
  }
}

POST _watcher/watch/_execute
{
  "watch": {
    "trigger": {
      "schedule": {
        "interval": "1m"
      }
    },
    "input": {
      "simple": {}
    },
    "actions": {
      "notify-slack": {
        "throttle_period": "5m",
        "slack": {
          "account": "elastic",
          "message": {
            "from": "watcher",
            "to": [
              "#eks-alert"
            ],
            "text": "System X Monitoring"
          }
        }
      }
    }
  }
}

#"input" : {
#    "search" : {
#      "request" : {
#        "indices" : [ "testindexv4" ],
#        "body" : {
#          "query" : {
#            "match" : { "log_level": "ERROR" }
#          }
#        }
#      }
#    }
#  }

###[security]#######################

https://m.blog.naver.com/PostView.nhn?blogId=wideeyed&logNo=221305354512&proxyReferer=https%3A%2F%2Fwww.google.com%2F

vi /etc/elasticsearch/elasticsearch.yml

xpack.security.enabled: true

service elasticsearch restart

/usr/share/kibana/bin/kibana-keystore create --allow-root
/usr/share/kibana/bin/kibana-keystore add elasticsearch.username --allow-root
/usr/share/kibana/bin/kibana-keystore add elasticsearch.password --allow-root

http://kangmyounghun.blogspot.com/2019/10/keystore.html

exit 0

GET _cluster/settings?flat_settings&include_defaults

PUT /_cluster/settings
{
    "persistent": {
        "xpack.notification.email": {
            "default_account": "elastic",
            "account": {
                "elastic": {
                    "profile": "gmail",
                    "email_defaults.from": "devops@tz.com",
                    "smtp": {
                        "auth": true,
                        "starttls": {
                          "enable": "true",
                          "required": "true"
                        },
                        "host": "smtp.gmail.com",
                        "port": "587",
                        "user": "devops@tz.com"
                    }
                }
            }
        }
    }
}


PUT _cluster/settings
{
  "persistent": {
    "xpack.notification.slack": {
      "account": {
        "elastic": {
          "message_defaults": {
            "from": "Kibana Watch",
            "to": "DESTINATION",
            "icon": "http://example.com/images/watcher-icon.jpg",
            "attachment": {
              "fallback": "X-Pack Notification",
              "color": "#36a64f",
              "title": "X-Pack Notification",
              "title_link": "https://www.elastic.co/guide/en/xpack/current/index.html",
              "text": "One of your watches generated this notification.",
              "mrkdwn_in": "pretext, text"
            }
          }
        }
      }
    }
  }
}


 "trigger": {
 "schedule": {
 "interval": "30s"
 }
 },
 "input": {
 "chain": {
 "inputs": [
 {
 "first": {
 "search": {
 "request": {
   "search_type": "query_then_fetch",
 "indices": [
 "cmsalarmstates-*"
 ],
 "types": [],
 "body": {
 "query": {
 "bool": {
 "must": {
 "match": {
 "cmsalarm.type": "cdrConnectionFailure"
 }
 },
 "filter": {
 "bool": {
 "must": {
 "range": {
 "timestamp": {
 "gte": "now-1m",
 "lte": "now-30s"
 }

 }
 }
 }
 }
 }
 }
 }
 }
 }
 },
 {
 "second": {
 "search": {
 "request": {
 "search_type": "query_then_fetch",
 "indices": [
 "cmsalarmstates-*"
 ],
 "types": [],
 "body": {
 "query": {
 "bool": {
 "must": {
 "match": {
 "cmsalarm.type": "cdrConnectionFailure"
 }
 },
 "filter": {
 "bool": {
 "must": {
 "range": {
 "timestamp": {
 "gte": "now-90s",
 "lte": "now-60s"
 }
 }
 }
 }
 }
 }
 }
 }
 }
 }
 }
 }
 ]
 }
 },
 "condition": {
 "always": {}
 },
 "actions": {
 "send_email": {
 "condition": {
 "script": {
 "source": "return ctx.payload.first.hits.total > 0 &&
ctx.payload.first.hits.total < 30 && ctx.payload.second.hits.total != 30",
 "lang": "painless"
 }
 },
 "email": {
 "profile": "standard",
 "from": "watchtest@test.com",
 "to": [
 "test@vqcomms.com"
 ],
 "subject": "Watcher Notification",
 "body": {
 "text": "CDR Connection Failure : ({{ctx.execution_time}})"
 }
 }
 }
 }
 }
