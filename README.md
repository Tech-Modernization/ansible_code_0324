# Configure Splunk to get ELB and CloudFront log from AWS SQS queues

# Background
* AWS ELB and CloudFront both can send their log to S3 buckets
* An S3 bucket can be configured to post change events to an SQS queue
* Splunk provides an AWS add-on and parsers to ingest ELB and CloudFront logs via SQS queues

# Summary
* Define a naming convention for SQS queues uses for ELB and CloudFront log transport, 
* Run 'aws sqs list-queues' command to list all the relevant SQS queues.
* Create Splunk AWS add-on configuration file based on discovered SQS queues.
* Use anisble to deliver the AWS add-on configuration file to the Splunk server and trigger Splunk server to reload its AWS monitor configuration.

# SQS queue naming convention
Please follow this convention when naming related SQS queues: <queue-prefix>-xxxx-<log-type>.
Where queue-prefix is a fixed prefix for all queues transporting ELB and CloudFront logs to Splunk, and log-type is either 'lb', or 'cloudfront'.
For example: "access-log-mysite0034-cloudfront", "access-log-mysite0056-lb".

# How to
* Run this command and follow the prompt: ./runme.sh
```
Yimins-MacBook-Pro-2:ansible_code_0324 yiminzheng$ ./runme.sh 
missing at least one argument.

syntax:
  ./runme.sh -r <aws region> -p <queue name prefix> -a <aws account, as configured in Splunk AWS add-on> \
     -x <splunk index name> -i <interval in seconds> -b <sqs queue batch size> \
     -h <splunk servers, ',' delimited> -u <splunk_username, to reload splunk config with> -w <splunk_password>

example:
  ./runme.sh -r us-east-1 -p access-access-log -a splunk -x main -i 300 -b 10 -h localhost -u sp_admin -w sp_pass1234
```

# Pre-reqs
* The Splunk server already has AWS add-on installed , and an AWS account configured.
* Dependencies such as ansible, jq, aws-cli installed in Jenkins, either through a pre-reqs script, or through Jenkins credentials.

# TBD
* How does Ansible authenticate for splunk server access?
* What if there are other parties updating the same AWS add-on configuration file on the splunk serve?
* Can improve on how to trigger splunk monitor configuration reload.

