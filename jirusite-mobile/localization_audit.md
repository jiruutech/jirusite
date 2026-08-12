# Localization Audit

## ✅ Screens Using AppLocalizations (6/20)
- ✅ auth/language_select_screen.dart
- ✅ auth/login_screen.dart
- ✅ auth/org_setup_screen.dart
- ✅ auth/otp_screen.dart
- ✅ auth/register_screen.dart
- ✅ settings/settings_screen.dart

## ❌ Screens NOT Using AppLocalizations (14/20)
These screens use hardcoded English strings and need localization:

### High Priority (Main Flow)
1. ❌ **dashboard/dashboard_screen.dart** - Main entry screen with hardcoded:
   - 'No organisation set up', 'Complete your organisation setup', 'Set Up'
   - 'Active Projects', 'Portfolio Health', 'This Month'
   - 'All', 'Active', 'Needs attention', 'Completed'
   - 'No projects yet', 'Create your first project', 'New Project'
   - 'Quick Add', 'New Expense', 'Labour Entry', 'Purchase Order'

2. ❌ **projects/project_list_screen.dart** - Project listing with hardcoded:
   - 'Projects', 'New Project', 'No projects yet', 'Create Project'
   - 'Project Name', 'Total Budget (ETB)', 'Cancel', 'Create'
   - 'spent', 'of'

3. ❌ **projects/project_detail_screen.dart** - Project details with hardcoded:
   - 'Project', 'Trending over budget', 'Approaching budget limit', 'On track'
   - 'Budget', 'Spent', 'Remaining'
   - 'Overview', 'Expenses', 'Labour', 'Materials', 'Schedule', 'Team'
   - 'Budget by Cost Code', 'Sorted by variance', 'Recent Activity'
   - 'See all activity', 'No recent activity'
   - 'Days left', 'Schedule', 'Pending sync', 'Loading…'

4. ❌ **expenses/expense_list_screen.dart** - Expense listing with hardcoded:
   - 'Expenses', 'Add Expense', 'No expenses yet'
   - 'Pending sync', 'Sync conflict', 'Synced'

5. ❌ **expenses/expense_entry_screen.dart** - Add expense with hardcoded:
   - 'New Expense', 'Save Expense', 'Expense Type'
   - 'Material', 'Labor', 'Equipment', 'Other'
   - 'Amount *', 'ETB', 'Description', 'Quantity', 'Unit', 'Select'
   - 'Transaction Date *', 'Enter a valid amount'
   - "You're offline — expense will sync automatically when connected."
   - 'Expense saved & syncing', 'Expense saved — will sync when online'
   - 'Failed to save: ...'

### Medium Priority
6. ❌ **labor/labor_list_screen.dart** - Labor listing
7. ❌ **labor/labor_entry_screen.dart** - Add labor
8. ❌ **materials_pricing/materials_screen.dart**
9. ❌ **notifications/notifications_screen.dart**
10. ❌ **billing/billing_screen.dart**
11. ❌ **suppliers/supplier_list_screen.dart**
12. ❌ **purchase_orders/purchase_order_list_screen.dart**
13. ❌ **purchase_orders/purchase_order_create_screen.dart**
14. ❌ **schedule/schedule_screen.dart**

## Required ARB Keys to Add

Based on the audit above, we need to add these keys to all ARB files:

```json
{
  "noOrganisation": "No organisation set up",
  "completeOrgSetup": "Complete your organisation setup to get started",
  "setUp": "Set Up",
  "activeProjects": "Active Projects",
  "portfolioHealth": "Portfolio Health",
  "thisMonth": "This Month",
  "all": "All",
  "active": "Active",
  "needsAttention": "Needs attention",
  "completed": "Completed",
  "quickAdd": "Quick Add",
  "newProject": "New Project",
  "projectName": "Project Name",
  "create": "Create",
  "spent": "spent",
  "of": "of",
  "trendingOverBudget": "Trending over budget",
  "approachingBudgetLimit": "Approaching budget limit",
  "onTrack": "On track",
  "budget": "Budget",
  "overview": "Overview",
  "budgetByCostCode": "Budget by Cost Code",
  "sortedByVariance": "Sorted by variance",
  "recentActivity": "Recent Activity",
  "seeAllActivity": "See all activity",
  "noRecentActivity": "No recent activity",
  "daysLeft": "Days left",
  "addExpense": "Add Expense",
  "saveExpense": "Save Expense",
  "enterValidAmount": "Enter a valid amount",
  "offlineWillSync": "You're offline — expense will sync automatically when connected",
  "expenseSavedSyncing": "Expense saved & syncing",
  "expenseSavedWillSync": "Expense saved — will sync when online",
  "failedToSave": "Failed to save",
  "workers": "workers",
  "ago": "ago"
}
```

## Recommendation

Given the scope (hundreds of hardcoded strings), I recommend:

**Option 1: Quick Fix for Demo** - Only localize the 3 most visible screens:
- Dashboard (main entry)
- Project list
- Expense list

**Option 2: Complete Fix** - Systematically localize all 14 screens over multiple commits

Which approach would you prefer?
