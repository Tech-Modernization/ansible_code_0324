# Configure Splunk to get ELB and Cloudfront log through AWS SQS queues

# Background
* AWS ELB and Cloudfront both can send their log to an S3 buckets
* An S3 bucket can be configured to post change events to an SQS queue
* Splunk provides AWS add-on and parsers to ingest ELB and cloudfront logs via SQS queues

# Summary
* Define a naming convention for SQS queues uses for ELB and CloudFront log transport, 
* Run 'aws sqs list-queues' command to fetch all the relevant queues.
* Create Splunk AWS add-on configuration file based on discovered SQS queues.
* Use anisble to deliver the AWS add-on configuration file to the Splunk server and trigger Splunk server to reload its AWS monitor configuration.

# SQS queue naming convention
Please follow this convention for related SQS queues: <queue-prefix>-xxxx-<log-type>.
Where queue-prefix is a fixed prefix for all queue transporting ELB and CloudFront log to Splunk, and log-type is either 'lb', or 'cloudfront'.
For example: "access-log-mysite0034-cloudfront", "access-log-mysite0056-lb".

# How to
* Run this command and follow prompt
./runme.sh


