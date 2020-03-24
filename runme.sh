#!/bin/bash

set -e
set -o pipefail

cleanup() {
  exit_code=$?
  rm -rf /tmp/playbook.yml
  exit $exit_code
}


trap cleanup INT TERM

show_usage () {
  cat <<EOF
missing at least one argument.

syntax:
  $0 -r <aws region> -p <queue name prefix> -a <splunk aws account> -x <splunk index name> -i <interval in seconds> -b <sqs queue batch size> -h <splunk servers> -u <splunk_username> -w <splunk_password>

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

queues=$(aws sqs list-queues --region $aws_region --queue-name-prefix $queue_name_prefix | jq ".QueueUrls[]" -r | grep -v "deadletter" | sort)
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
    exit 1
  fi
  envsubst < input_template >>/tmp/input.config
done <<< "$queues"

envsubst < playbook_template >/tmp/playbook.yml

while IFS=, read -r line
do
  if [[ $line -eq "localhost" ]]; then
    ansible-playbook --connection=local --inventory $line, /tmp/playbook.yml
  else
    ansible-playbook --inventory $line, /tmp/playbook.yml
  fi
done <<< "$splunk_hosts"


