data "aws_organizations_organization" "current" {}

resource "aws_budgets_budget" "account_monthly" {
    name         = "My monthly budget"
  budget_type  = "COST"
  limit_amount = "1"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [data.aws_organizations_organization.current.master_account_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [data.aws_organizations_organization.current.master_account_email]
  }
}

check "check_budget_exceeded" {
  data "aws_budgets_budget" "check" {
    name = aws_budgets_budget.account_monthly.name
  }

  assert {
    condition = !data.aws_budgets_budget.check.budget_exceeded
    error_message = format("AWS budget has been exceeded! Calculated spend: '%s' and budget limit: '%s'",
      data.aws_budgets_budget.check.calculated_spend[0].actual_spend[0].amount,
      data.aws_budgets_budget.check.budget_limit[0].amount
    )
  }
}