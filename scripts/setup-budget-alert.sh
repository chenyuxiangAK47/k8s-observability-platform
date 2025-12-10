#!/bin/bash
# Setup AWS Budget Alert - Prevent Cost Overruns
# This script creates a budget alert to notify you when costs exceed thresholds

echo "💰 Setting up AWS Budget Alert..."
echo "========================================"

# Get current account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

# Create SNS topic for budget alerts (if not exists)
TOPIC_NAME="budget-alerts"
TOPIC_ARN=$(aws sns create-topic --name $TOPIC_NAME --region $REGION --query 'TopicArn' --output text 2>/dev/null || \
    aws sns list-topics --region $REGION --query "Topics[?contains(TopicArn, '$TOPIC_NAME')].TopicArn" --output text)

if [ -z "$TOPIC_ARN" ]; then
    echo "❌ Failed to create SNS topic"
    exit 1
fi

# Subscribe your email (you'll need to confirm via email)
echo ""
echo "📧 Enter your email address for budget alerts:"
read EMAIL

aws sns subscribe \
    --topic-arn "$TOPIC_ARN" \
    --protocol email \
    --notification-endpoint "$EMAIL" \
    --region $REGION

echo "✅ Email subscription created. Please check your email and confirm subscription."

# Create budget JSON
BUDGET_JSON=$(cat <<EOF
{
    "BudgetName": "eks-daily-budget",
    "BudgetLimit": {
        "Amount": "5",
        "Unit": "USD"
    },
    "TimeUnit": "DAILY",
    "BudgetType": "COST",
    "CostFilters": {
        "Service": ["Amazon Elastic Compute Cloud - Compute", "Amazon Elastic Container Service for Kubernetes", "Amazon VPC"]
    },
    "CalculatedSpend": {
        "ActualSpend": {
            "Amount": "0",
            "Unit": "USD"
        }
    },
    "TimePeriod": {
        "Start": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
}
EOF
)

# Create budget
aws budgets create-budget \
    --account-id "$ACCOUNT_ID" \
    --budget "$BUDGET_JSON" \
    --notifications-with-subscribers \
        "[{\"Notification\":{\"NotificationType\":\"ACTUAL\",\"ComparisonOperator\":\"GREATER_THAN\",\"Threshold\":80,\"ThresholdType\":\"PERCENTAGE\"},\"Subscribers\":[{\"SubscriptionType\":\"EMAIL\",\"Address\":\"$EMAIL\"}]},{\"Notification\":{\"NotificationType\":\"FORECASTED\",\"ComparisonOperator\":\"GREATER_THAN\",\"Threshold\":100,\"ThresholdType\":\"PERCENTAGE\"},\"Subscribers\":[{\"SubscriptionType\":\"EMAIL\",\"Address\":\"$EMAIL\"}]}]" \
    --region $REGION

echo ""
echo "✅ Budget alert created!"
echo "📊 Budget: \$5/day"
echo "🔔 Alerts: 80% threshold (\$4/day) and 100% forecasted"
echo ""
echo "📋 View budgets:"
echo "  aws budgets describe-budgets --account-id $ACCOUNT_ID --region $REGION"

