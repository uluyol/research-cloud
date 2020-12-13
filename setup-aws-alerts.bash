#!/usr/bin/env bash

set -e

NOTIFICATION_EMAIL=____REDACTED____
ACTION_CREATE_ALARM=1

REGION_LIST=(
    us-east-1      # US East (N. Virginia)
    us-east-2      # US East (Ohio)
    us-west-1      # US West (N. California)
    us-west-2      # US West (Oregon)
    # SKIP af-south-1     # Africa (Cape Town)
    # SKIP ap-east-1      # Asia Pacific (Hong Kong)
    ap-south-1     # Asia Pacific (Mumbai)
    ap-northeast-2 # Asia Pacific (Seoul)
    ap-southeast-1 # Asia Pacific (Singapore)
    ap-southeast-2 # Asia Pacific (Sydney)
    ap-northeast-1 # Asia Pacific (Tokyo)
    ca-central-1   # Canada (Central)
    eu-central-1   # Europe (Frankfurt)
    eu-west-1      # Europe (Ireland)
    eu-west-2      # Europe (London)
    # SKIP eu-south-1     # Europe (Milan)
    eu-west-3      # Europe (Paris)
    eu-north-1     # Europe (Stockholm)
    # SKIP me-south-1     # Middle East (Bahrain)
    sa-east-1      # South America (São Paulo)
)

if [[ $(jq -r .name <<<'{"name": "hello"}') != hello ]]; then
    echo must install jq >&2
    exit 2
fi

if ! aws help >/dev/null; then
    echo must install aws cli tool >&2
    exit 2
fi

for reg in "${REGION_LIST[@]}"; do
    topic_name="high-cost"

    echo create topic $topic_name in $reg
    topic_arn=$(aws sns create-topic \
        --region "$reg" \
        --name "$topic_name" \
            | jq -r .TopicArn)

    echo subscribe to topic $topic_arn in $reg
    aws sns subscribe \
        --region "$reg" \
        --topic-arn "$topic_arn" \
        --protocol email \
        --notification-endpoint "$NOTIFICATION_EMAIL"

    alarm_name="vm-util-low"

    if (( ACTION_CREATE_ALARM != 0 )); then
        echo create alarm $alarm_name in $reg
        aws cloudwatch put-metric-alarm \
            --region $reg \
            --alarm-name $alarm_name \
            --actions-enabled \
            --alarm-actions "$topic_arn" \
            --metric-name "CPUUtilization" \
            --namespace "AWS/EC2" \
            --statistic "Average" \
            --period 300 \
            --unit Percent \
            --evaluation-periods 288 \
            --datapoints-to-alarm 216 \
            --threshold 5.0 \
            --comparison-operator LessThanOrEqualToThreshold \
            --treat-missing-data missing
    fi
done
