#!/bin/bash

# steps:
#    set up cleanup routine
#    accept and validate all CLI arguments
#    list all SQS queue for cloudfront/elb log transport
#    create splunk AWS add-on input config file
#    create ansible playbook
#    run ansible to copy the add-on input config file onto the target splunk servers and reload splunk config

set -e
set -o pipefail
#    set up cleanup routine
cleanup() {
  exit_code=$?
  rm -rf /tmp/playbook.yml
  exit $exit_code
}

trap cleanup INT TERM HUP KILL QUIT EXIT

#    accept and validate all CLI arguments
show_usage () {
  cat <<EOF
missing at least one argument.

syntax:
  $0 -r <aws region> -p <queue name prefix> -a <aws account, as configured in Splunk AWS add-on> \\
     -x <splunk index name> -i <interval in seconds> -b <sqs queue batch size> \\
     -h <splunk servers, ',' delimited> -u <splunk_username, to reload splunk config with> -w <splunk_password>

example:
  $0 -r us-east-1 -p access-access-log -a splunk -x main -i 300 -b 10 -h localhost -u sp_admin -w sp_pass1234
EOF
  exit 1
}

while getopts "r:p:a:x:i:b:h:u:w:" OPTION; do
    case $OPTION in
    r)
        export aws_region=$OPTARG
        ;;
    p)
        queue_name_prefix=$OPTARG
        ;;
    a)
        export aws_account=$OPTARG
        ;;
    x)
        export index=$OPTARG
        ;;
    i)
        export interval=$OPTARG
        ;;
    b)
        export batch_size=$OPTARG
        ;;
    h)
        splunk_hosts=$OPTARG
        ;;
    u)
        export splunk_username=$OPTARG
        ;;
    w)
        export splunk_password=$OPTARG
        ;;
    *)
        echo "Incorrect options provided"
        show_usage
        ;;
    esac
done

if [[ -z $aws_region ]] || [[ -z $queue_name_prefix ]] || [[ -z $aws_account ]] \
   || [[ -z $index ]] || [[ -z $interval ]] || [[ -z $batch_size ]] \
   || [[ -z $splunk_hosts ]]; then
  show_usage
fi

rm -rf /tmp/input.config
rm -rf /tmp/playbook.yml
#    list all SQS queue for cloudfront/elb log transport
queues=$(aws sqs list-queues --region $aws_region --queue-name-prefix $queue_name_prefix | jq ".QueueUrls[]" -r | grep -v "deadletter" | sort)
#    create splunk AWS add-on input config file
while IFS= read -r line
do
  export queue_url=$line
  export input_name=$(echo "$line" | awk -F/ '{print $4"-"$5}' | sed "s/^[[:alnum:]_-]//g")
  if [[ $line =~ cloudfront$ ]]; then
    export decoder=CloudFrontAccessLogs
    export sourcetype=aws:cloudfront:accesslogs
  elif [[ $line =~ lb$ ]]; then
    export decoder=ELBAccessLogs
    export sourcetype=aws:elb:accesslogs
  else
    echo "unhandled log sourcetype for queue: $line"
    exit 1
  fi
  envsubst < input_template >>/tmp/input.config
done <<< "$queues"

#    create ansible playbook
envsubst < playbook_template >/tmp/playbook.yml

#    run ansible to copy the add-on input config file onto the target splunk server(s) and reload splunk config
while IFS=, read -r line
do
  if [[ $line -eq "localhost" ]]; then
    ansible-playbook --connection=local --inventory $line, /tmp/playbook.yml
  else
    ansible-playbook --inventory $line, /tmp/playbook.yml
  fi
done <<< "$splunk_hosts"


