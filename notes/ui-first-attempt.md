# Plain-English Spec: Initial Improve Svelte App Layout

## Goal

Build the first real authenticated layout for Improve.

This is not the final design. It should be a practical starting layout that lets us use the app, test the backend, and build product screens incrementally.

The layout should feel like a personal planning dashboard:

```text
Today first.
Fast logging always available.
Current plan visible.
Journal/history easy to reach.
Plan setup available, but not dominant.
```

Do not copy the old UI exactly. Use it as directional inspiration only.

## Overall layout

Use one main app shell:

```text
Left sidebar
Top title/action bar
Main content area
Global modal/dialog layer
```

Do not build two sidebars yet.

The old UI had a narrow icon sidebar plus a wider navigation sidebar. That worked visually, but it is more structure than we need for the first Svelte version.

For now, use one sidebar that contains:

```text
App logo
Current plan switcher
Primary navigation
Secondary/setup navigation
User/logout area
```

## Left sidebar

The sidebar should be fixed on desktop.

Suggested width:

```text
240px to 280px
```

The sidebar should contain, from top to bottom:

```text
Improve logo / app mark

Plan switcher
  Current plan name
  Small subtitle, e.g. "Day 8 of 52"
  Dropdown affordance

Main navigation
  Today
  Journal
  Calendar

Current plan
  Plan
  Progress
  Sessions
  Inventory

Setup
  Event Types
  Resource Types

Bottom area
  Settings
  User/avatar
  Logout
```

The exact grouping can change later.

The important thing is that Today, Journal, and Plan are easy to find.

## Plan switcher

The plan switcher is important because Improve may support concurrent active plans.

The plan switcher should live near the top of the sidebar.

Clicking it should eventually open a dropdown or dialog showing available plans.

For the first version, it can be simple:

```text
Current plan:
  Improve myself!
  Day 8 of 52
```

If multiple plans are available, show them in a dropdown.

If only one plan exists, it can still look like a switcher but does not need advanced behaviour yet.

Future behaviour:

```text
Switch current plan
Create new plan
View all plans
Show active/archived plans
```

## Top bar

The top bar should stay visible at the top of the main content area.

It should show:

```text
Current page title
Short page subtitle
Primary global actions
```

Example for Today:

```text
Today
Cross-plan view across active plans.

[+ Log] [Check-in]
```

The top bar should include two important global buttons:

```text
Log
Check-in
```

These worked well in the old UI and should stay.

## Global Log button

The `Log` button is for logging a specific event quickly.

Clicking it should open a global log dialog.

In the first version, this can be simple:

```text
Choose what to log
Choose plan/item/event if needed
Enter amount/details
Add note
Submit
```

Later, it can become smarter:

```text
recently logged items
today’s projected work
search events/items
scan inventory/resource-linked events
```

But for the initial layout, the button just needs to exist and open a dialog.

## Global Check-in button

The `Check-in` button is for a broader daily check-in flow.

It is different from logging one specific thing.

In the first version, it can open a placeholder dialog or route.

Eventually it may support:

```text
daily review
mood/energy
notes
missed targets
coach prompt
summary of today
```

For now, build the button and wire it to a placeholder.

## Main content area

The main content area should render the current page.

Suggested pages for the first layout:

```text
Today
Journal
Plan
Progress placeholder
Calendar placeholder
Sessions placeholder
Inventory placeholder
Event Types placeholder
Resource Types placeholder
```

Only Today, Journal, and Plan need useful first versions.

Other pages can be placeholders so navigation works.

## Today page

Today is the home screen.

It should answer:

```text
What should I do today?
What have I already done?
What is coming next?
```

Recommended first layout:

```text
Compact hero / summary card
Today's work list
Upcoming work card
Recent journal card
```

Do not overbuild the hero.

The old UI had a large greeting card and progress wheel. That looked good, but the first version should be simpler.

Suggested Today structure:

```text
Header card:
  Good afternoon, John.
  Today is Tue 23 Jun.
  You have 7 things projected today.
  2 completed, 5 remaining.

Today's work:
  List of projected goals/sessions/items.
  Each row has:
    icon
    title
    plan name
    target
    current status/progress
    Log or Update button

Upcoming:
  Tomorrow / next few days.
  Small list of upcoming projected work.

Recent journal:
  Latest 5 entries.
```

The `Log` button on a Today work item should open the log dialog prefilled for that target.

## Journal page

The Journal page is the review/history surface.

First version:

```text
Title card
Simple filters
Entry list
```

Entry rows should show:

```text
date/time
icon
event title
plan name
summary value
optional note/details
edit/correct button
```

For now, filters can be simple placeholders or basic date/plan filters.

Avoid making deletion too prominent. Prefer edit/correct language where possible.

## Plan page

The Plan page is for inspecting and managing the current plan.

First version:

```text
Plan summary card
Plan item list
```

Summary card should show:

```text
plan name
intention/description
status
date range
number of plan items/goals/sessions/resources
```

Plan item rows should show:

```text
icon
name
type/kind
group/category tags
description
schedule/target summary
edit button placeholder
```

Do not build the full plan editor yet unless needed.

## Log dialog

Use a dialog/modal for logging.

This is one of the most important interactions in the app.

When opened from a Today item, it should be prefilled with that projected work.

The dialog should show:

```text
Title:
  Log Cycling

Context:
  Improve myself!
  Target for Tue 23 Jun
  25 min
  Description/instructions

Action:
  Log amount
  Skip today

Fields:
  amount
  unit
  optional extra fields
  note

Footer:
  Cancel
  Submit
```

The dialog should support different event shapes later, but the first version can support the common cases:

```text
simple quantity + unit
optional note
optional extra payload fields
skip/missed action placeholder
```

After successful logging:

```text
close dialog
refresh Today data
refresh Journal data if visible
show a small success message
```

## Component library

Use Bits UI for accessible primitives.

Use Bits UI for:

```text
Dialog
Dropdown Menu
Select
Popover
Tooltip
Tabs if needed
```

Build Improve-specific product components ourselves:

```text
AppShell
Sidebar
TopBar
PlanSwitcher
TodayPage
TodayWorkList
ProjectedWorkRow
UpcomingCard
JournalPage
JournalEntryRow
PlanPage
PlanItemRow
LogDialog
CheckInDialog
```

Do not make the app feel like a generic component-library demo.

Bits UI should provide behaviour and accessibility. Improve should provide the product design.

## Styling direction

The visual style should be calm, warm, and readable.

Direction:

```text
off-white background
white cards
soft borders
rounded corners
subtle shadows
black primary buttons
soft colored icons
clear spacing
not too dense
```

Avoid over-polishing too early.

The first version should look pleasant but not final.

## Routing

Use simple client-side routing.

Suggested initial routes:

```text
/dashboard or /
/today
/journal
/plan
/progress
/calendar
/sessions
/inventory
/event-types
/resource-types
```

If a router is already installed, use it.

If not, a lightweight route store is acceptable for the first pass.

Do not let routing become a big architecture project.

## Auth gate

The app already has authentication.

On app load:

```text
call /api/auth/me
if signed in:
  show AppShell
if signed out:
  show login flow
```

The app shell should only render for signed-in users.

Logout should call the backend logout endpoint, clear frontend state, and return to the login screen.

## Backend data access

Prefer AshTypescript-generated client/actions for product data.

The frontend should not hand-build lots of ad-hoc fetch calls once AshTypescript is available.

The intended shape is:

```text
frontend calls typed app-shaped actions
actions delegate to Improve.App / Ash domains
backend returns product-shaped read models
```

Use typed API functions like:

```text
currentUser()
listPlans()
getCurrentPlan()
projectToday()
recentJournal()
summarizePlan()
logProjectedWork()
logEvent()
logout()
```

The exact generated names may differ.

The frontend should not know database tables or low-level resource internals.

Good frontend API shape:

```text
authClient.currentUser()
plansClient.listPlans()
plansClient.currentPlan()
todayClient.projectToday({ date })
journalClient.recentJournal({ limit })
loggingClient.logProjectedWork(input)
```

If AshTypescript generation is not ready for a specific action, create a small temporary wrapper around the existing JSON endpoint. Keep those wrappers isolated in `src/api/`.

## Suggested frontend folders

Use a feature-oriented structure:

```text
frontend/src/
  api/
    authClient.ts
    improveClient.ts
    types.ts

  app/
    AppShell.svelte
    Sidebar.svelte
    TopBar.svelte
    PlanSwitcher.svelte
    routes.ts
    appState.ts

  features/
    auth/
      LoginPage.svelte
      EmailStep.svelte
      CodeStep.svelte

    today/
      TodayPage.svelte
      TodaySummaryCard.svelte
      TodayWorkList.svelte
      ProjectedWorkRow.svelte
      UpcomingCard.svelte

    journal/
      JournalPage.svelte
      JournalEntryRow.svelte

    plan/
      PlanPage.svelte
      PlanSummaryCard.svelte
      PlanItemRow.svelte

    logging/
      LogDialog.svelte
      CheckInDialog.svelte

  components/
    ui/
      Button.svelte
      Card.svelte
      Badge.svelte
      IconBadge.svelte
      EmptyState.svelte
      LoadingState.svelte

  lib/
    dates.ts
    formatting.ts
```

Keep the first pass simple.

## Frontend state

Use small Svelte stores.

Suggested stores:

```text
currentUser
currentPlan
availablePlans
todayProjection
recentJournal
activeRoute
logDialogState
```

Do not introduce a heavy data library yet unless it is already in use.

The backend should remain the source of truth.

After mutations, refresh the relevant read data.

Example:

```text
log event
  -> refresh today projection
  -> refresh recent journal
  -> maybe refresh current plan summary
```

## Initial data loading flow

When the authenticated app loads:

```text
1. Load current user.
2. Load available/current plans.
3. Load today projection.
4. Load recent journal.
```

Show loading states rather than blocking the entire app forever.

If there is no plan yet, show an empty state:

```text
No active plan yet.
Create or import a plan to get started.
```

## Backend actions needed

The frontend needs product-shaped backend actions.

Minimum useful set:

```text
current_user
list_plans
get_current_plan
project_today
recent_journal
summarize_plan
log_event / log_projected_work
logout
```

Soon after:

```text
list_plan_items
list_sessions
list_inventory
item_state
correct_event
delete_or_void_event
```

Use actor-aware actions. All protected calls must run as the signed-in user.

Rule:

```text
No actor, no private data.
```

## Loading and error states

Every page should handle:

```text
loading
empty
error
ready
```

Errors should be friendly.

Example:

```text
We couldn’t load today’s plan.
Try again.
```

Do not expose raw backend exception messages in the UI.

## Responsive behaviour

Desktop first is fine for this pass.

But do not make mobile impossible.

On smaller screens:

```text
sidebar can collapse behind a menu button
top bar actions remain visible
Today list becomes single column
dialogs fit within viewport
```

Do not fully optimise mobile yet.

## What not to build yet

Do not build:

```text
full plan editor
complex calendar
coach chat
search command palette
advanced filters
advanced plan switching
multi-plan dashboards
billing
OAuth/passkeys
mobile-specific layout
```

The first layout should make the core loop usable:

```text
sign in
see today
log something
review journal
inspect plan
switch plan later
```

## First implementation milestone

Milestone is complete when:

```text
Signed-in user sees app shell.
Sidebar navigation works.
Top bar shows page title and Log / Check-in buttons.
Plan switcher shows current plan.
Today page loads real backend projection data.
Journal page loads real backend recent entries.
Plan page loads real backend plan summary/items.
Clicking Log on a Today item opens LogDialog.
Submitting LogDialog records an event.
Today and Journal refresh after logging.
Logout works.
```

## Main product principle

The layout should make Improve feel like a daily operating system for a plan.

The user should always know:

```text
What plan am I in?
What should I do today?
How do I log something quickly?
What have I already done?
Where do I inspect or adjust the plan?
```

Keep that loop clear.

Everything else can evolve later.

