#!/bin/bash
# Setup AWS Budget Alert - Prevent Cost Overruns
# This script creates a budget alert to notify you when costs exceed thresholds

set -e

echo "💰 Setting up AWS Budget Alert..."
echo "========================================"

# Get current account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

# Subscribe your email (you'll need to confirm via email)
echo ""
echo "📧 Enter your email address for budget alerts:"
read EMAIL

# Validate email format
if [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "❌ Invalid email format"
    exit 1
fi

# Create SNS topic for budget alerts (if not exists)
TOPIC_NAME="budget-alerts"
TOPIC_ARN=$(aws sns create-topic --name "$TOPIC_NAME" --region "$REGION" --query 'TopicArn' --output text 2>/dev/null || \
    aws sns list-topics --region "$REGION" --query "Topics[?contains(TopicArn, 'budget-alerts')].TopicArn" --output text | head -n1)

if [ -z "$TOPIC_ARN" ]; then
    echo "❌ Failed to create SNS topic"
    exit 1
fi

echo "📧 Subscribing email to SNS topic..."
aws sns subscribe \
    --topic-arn "$TOPIC_ARN" \
    --protocol email \
    --notification-endpoint "$EMAIL" \
    --region "$REGION" 2>/dev/null || echo "⚠️  Subscription may already exist"

echo "✅ Email subscription created. Please check your email ($EMAIL) and confirm subscription."

# Create budget JSON file
BUDGET_FILE=$(mktemp)
cat > "$BUDGET_FILE" <<EOF
{
    "BudgetName": "eks-daily-budget",
    "BudgetLimit": {
        "Amount": "5",
        "Unit": "USD"
    },
    "TimeUnit": "DAILY",
    "BudgetType": "COST",
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

# Create notifications JSON file
NOTIFICATIONS_FILE=$(mktemp)
cat > "$NOTIFICATIONS_FILE" <<EOF
[
    {
        "Notification": {
            "NotificationType": "ACTUAL",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 80,
            "ThresholdType": "PERCENTAGE"
        },
        "Subscribers": [
            {
                "SubscriptionType": "EMAIL",
                "Address": "$EMAIL"
            }
        ]
    },
    {
        "Notification": {
            "NotificationType": "FORECASTED",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 100,
            "ThresholdType": "PERCENTAGE"
        },
        "Subscribers": [
            {
                "SubscriptionType": "EMAIL",
                "Address": "$EMAIL"
            }
        ]
    }
]
EOF

# Create budget
echo ""
echo "📊 Creating budget..."
aws budgets create-budget \
    --account-id "$ACCOUNT_ID" \
    --budget file://"$BUDGET_FILE" \
    --notifications-with-subscribers file://"$NOTIFICATIONS_FILE" \
    --region "$REGION" 2>/dev/null || echo "⚠️  Budget may already exist"

# Cleanup temp files
rm -f "$BUDGET_FILE" "$NOTIFICATIONS_FILE"

echo ""
echo "✅ Budget alert setup complete!"
echo "========================================"
echo "📊 Budget: \$5/day"
echo "🔔 Alerts: 80% threshold (\$4/day) and 100% forecasted"
echo "📧 Email: $EMAIL"
echo ""
echo "⚠️  IMPORTANT: Check your email and confirm the SNS subscription!"
echo ""
echo "📋 View budgets:"
echo "  aws budgets describe-budgets --account-id $ACCOUNT_ID --region $REGION"

