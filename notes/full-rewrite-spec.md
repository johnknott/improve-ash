# Improve, Built From Scratch, in Plain English

This document describes Improve as if we were building it from scratch.

It combines the product ideas that already work with the cleaner model the app
is moving toward. It is not a migration plan, database schema, API contract, or
implementation checklist. It is the plain-English shape of the system: what the
product is, what it remembers, what it calculates, and how the main parts fit
together.

Draft date: 2026-06-22.

## The Product

Improve is a personal planning and progress app.

The basic promise is simple:

Improve helps a person turn an intention into a living plan. The plan can say
what should happen, help the user do it, remember what actually happened,
understand what changed because of it, and use that history to make better
suggestions next time.

It should work for different kinds of structured life systems, such as:

- Gym training.
- Reading.
- Study routines.
- Running or cycling.
- Medication, peptide, or supplement inventory.
- Household supplies.
- Project habits.
- Metrics such as bodyweight, sleep, mood, symptoms, or resting heart rate.

The app should not be hard-coded around one of those domains. A gym plan and a
vial inventory plan look very different to the user, but they can share the
same underlying shape:

1. The user has a plan.
2. The plan contains things the user may use, choose, track, or affect.
3. The plan describes sessions, goals, targets, schedules, and policies.
4. The user logs events that say what actually happened.
5. Some events change the state of things in the plan.
6. The app uses history and deterministic rules to suggest what should happen
   next.
7. An AI coach can help explain, review, and adjust the plan.

The product should feel conversational and practical, not like a database with a
nice coat of paint. The user should mostly experience it as:

- What am I trying to do?
- What should I do today?
- What happened?
- What changed?
- What should happen next?

## The Core Loop

Improve is built around a repeated planning loop.

A user starts a plan for a period of time. The plan has an intention, a start
date, an end date, and enough structure to guide the user through that period.

The app projects what is due. That might be today's gym session, a daily
reading target, a dose reminder, a metric check-in, a study review, or a weekly
goal.

The user does some of the work. They might follow the recommendation exactly,
swap something, skip something, only partially complete something, or log
something ad hoc that was not planned.

The app records those real events in the journal.

The app derives progress and state from the journal. A session can be marked
complete. A weekly total can update. A vial quantity can go down. An exercise
can become ready to progress. A missed target can create a catch-up proposal.

The user reviews the day or week. The AI coach can help summarize what happened,
ask good questions, and suggest changes, but it should be using structured facts
the app already understands.

That loop matters more than any one screen or table name.

## The App Shape

Improve should be one coherent web application.

A straightforward build would use:

- A Go backend.
- A React frontend.
- Postgres as the source of truth.
- One deployable app that serves the API and the web frontend.
- A pure internal planning package for deterministic calculations.
- Background jobs for work such as billing webhooks and asynchronous operations.
- Realtime plumbing where it improves the experience, especially for the
  assistant.

The exact technology is less important than the boundaries.

The backend owns authentication, validation, database writes, business rules,
billing, admin operations, assistant runs, and generated effects.

The frontend owns the user's workflows: planning, today, sessions, logging,
journal, calendar, progress, inventory/state, assistant, profile, billing, and
admin screens.

Postgres is the durable source of truth.

The planning package is not a second app. It does not own users, billing, HTTP,
database access, AI calls, files, randomness, or the wall clock. It takes
explicit inputs and returns explicit outputs. Its job is to answer questions
like:

- What is due in this date range?
- Which session occurrences should appear?
- Which direct goals are due?
- What is the status of projected work?
- What warnings, diagnostics, or proposals apply?
- Which items should be recommended for session slots?
- Which targets are ready to progress?

That calculation layer should be deterministic, boring, and easy to test. The
product around it can be friendly, flexible, and conversational.

## Accounts and Sign-In

The app should have native passwordless sign-in.

The sign-in screen asks for an email address. The app sends a six-digit code.
The user enters the code, and the app creates a session stored in an HttpOnly
cookie.

The sign-in flow should support:

- Email validation.
- Six-digit code entry.
- Automatic submit once the code is complete.
- Resending the code with a cooldown.
- Switching to a different email.
- Blocking new signups when signups are disabled.
- Blocking suspended users.

Sessions should be stored server-side, expire over time, and be safe to rotate.

The account area should let the user:

- See their email address.
- Edit their full name.
- Upload a profile photo.
- Crop, zoom, and rotate the photo before saving.
- Remove the profile photo.

Email changes can be handled later. The important baseline is a simple,
dependable sign-in and account identity.

New users who have not finished setup should see a short onboarding screen. It
does not need to be elaborate. A welcome card asking for their name is enough to
make the app feel personal and complete the basic profile.

## Main Navigation

The authenticated app should have a stable shell.

A primary rail gives access to the main domains:

- Plans.
- Plan Store.
- Settings.
- Admin, for admin users.

A secondary sidebar changes depending on the active domain.

For planning, the sidebar starts with a plan selector. The user can switch
between plans or create a new plan. Planning navigation should include:

- Today.
- Journal.
- Calendar.
- Plan.
- Progress.
- Sessions.
- Items.
- Item Types.
- Pools.
- Environments.
- Event Types.
- Inventory or State, when a plan has stateful items.

The top bar should contain quick actions:

- Capture or log something.
- Start a check-in.
- Open Ask Improve.
- Open the command palette.
- Open notifications.

The command palette does not need to be clever at first, but it should become a
fast way to search, create, navigate, and run common actions.

The assistant can open as a floating panel or a pinned right-side panel.

The user menu should show the user's avatar, name, and email. It should link to
profile settings, theme choices, sign out, and the admin area when relevant.

When an admin is impersonating a user, the app should show a clear banner. The
user should never have to guess whether they are in a normal session or a
support session.

## Plans

A plan is the user's working copy of an intention.

Examples:

- General fitness and gym progress.
- Read more consistently.
- Learn Spanish vocabulary.
- Peptide dosing and vial inventory.
- Marathon preparation.
- Household stock management.
- A project routine.

A plan has:

- Name.
- Intention.
- Start date.
- End date.
- Status.
- Items.
- Item types.
- Pools.
- Environments.
- Event types.
- Session templates.
- Direct goals.
- Schedules.
- Targets.
- Policies.
- Journal history.
- Derived progress and state.

A plan belongs to the user. If it came from a reusable bundle, the bundle is
copied in. Future bundle changes should not silently rewrite the user's live
plan.

The Plan page should show the plan at a useful level of detail:

- The plan name and intention.
- Status and date range.
- Current day or progress through the plan.
- A summary of active sessions and direct goals.
- Any warnings or diagnostics.
- Actions to edit the plan, archive it, export it, print a schedule, or ask the
  assistant for help.

Archiving a plan should stop it from appearing as active, but it should keep
history. Old plans are part of the user's record.

## Bundles and Plan Drafts

A bundle is a reusable starter package.

A bundle might describe:

- A beginner gym plan.
- A running progression.
- A peptide inventory and dosing setup.
- A study routine.
- A reading habit plan.
- A household inventory plan.

Bundles are recipes. Installing a bundle creates a user's own editable plan.

A bundle can include:

- Item types.
- Items.
- Pools.
- Environments.
- Event types.
- Session templates.
- Direct goals.
- Schedules.
- Targets.
- Progression policies.
- Missed-work policies.
- Setup questions.
- Coaching prompts.
- Display hints.

The Plan Store can begin as a draft preview and import surface. The user can
paste or upload a versioned plan draft or bundle JSON. The app validates it,
shows a readable preview, and imports it as a new plan if it is valid.

A preview should show:

- Whether the draft is valid.
- Diagnostics if it is not valid.
- Plan name and date range.
- Intention.
- Counts for major objects.
- A human-readable list of sessions, goals, items, and event types.

The app should also export a plan draft. Export should translate internal IDs
into stable keys so the plan can be shared, edited, or passed to an LLM without
leaking database details.

This import/export path is important. It makes the app portable, testable, and
friendly to AI-assisted authoring. But the schema should use the clean model:
items, sessions, goals, events, effects, and policies.

## Items

An item is any concrete thing inside a plan that can be selected, used, tracked,
linked to an event, or affected by an event.

Examples:

- Chest Press.
- Lat Pulldown.
- Treadmill.
- JD Gym.
- Retatrutide vial 1.
- Syringe box.
- A book.
- Running shoes.
- Spanish vocabulary drill.
- Notebook.
- Budget pot.

The word item is deliberately broad.

Some items have changing state. A vial has remaining quantity. A supply box has
count. A budget pot has balance.

Other items do not need changing state. A chest press machine, a book, or a
Spanish drill can still be linked to history without having an inventory balance.

This avoids forcing everything into the old idea of a resource. A vial is a
resource. A gym exercise is not really a resource. Both are items.

## Item Types

An item type describes what kind of thing an item is.

Examples:

- Exercise.
- Cardio machine.
- Gym environment.
- Peptide vial.
- Supply.
- Book.
- Study drill.
- Budget pot.

The item type explains what facts an item of that kind should have.

For an exercise, useful facts might include:

- Movement pattern.
- Muscles.
- Modality.
- Whether it is bodyweight, machine, cable, free weight, or cardio.
- Whether it should be avoided for a known injury.

For a vial, useful facts might include:

- Compound.
- Starting quantity.
- Unit.
- Prepared volume.
- Concentration.
- Batch.
- Prepared date.
- Expiry date.
- Notes.

For a book, useful facts might include:

- Author.
- Total pages.
- Current page.
- Topic.
- Priority.

The app should not need special platform columns for every domain. Domain facts
belong in item type definitions and schemas.

The user-facing screens should not make normal users write JSON unless they
choose an advanced mode. A good default editor should provide forms, examples,
and plain-language labels.

## Pools

A pool is a named group of items that can satisfy a role.

Examples:

- Push exercises.
- Pull exercises.
- Lower body exercises.
- Cardio machines.
- LISS cardio options.
- Study drills.
- Peptide supplies.

Pools let the plan say "choose two push exercises" instead of hard-coding
"Chest Press and Shoulder Press".

That flexibility is essential because real life changes. A machine may be busy.
A user may be travelling. A movement may irritate an injury. A user may prefer a
different option. The app can recommend a sensible default, but the user can
swap it.

Pools should be editable inside the plan. A bundle can provide the starter
groups, but the user's version should become theirs.

## Environments

An environment is the context where something happens.

Examples:

- JD Gym.
- Home.
- Travel.
- Office.
- Clinic.
- Outdoors.

Environments matter because they affect what is available.

If today's session is at JD Gym, the app can recommend machines and exercises
available there. If the user is at home, it should not recommend a machine that
only exists at the gym. If the weather is bad, an outdoor run might need a note,
a swap, or a different recommendation.

An environment may be implemented as a special item or as a separate record that
points to available items. The user-facing idea is simpler than the
implementation: where you are changes what makes sense.

## Sessions

A session is a planned block of activity.

Examples:

- Upper-biased gym visit.
- Lower-biased gym visit.
- Mobility check-in.
- Weekly study review.
- Peptide preparation session.
- Sunday planning review.

Sessions are for work that naturally happens as a grouped visit, practice,
routine, or review.

The model separates session templates from session occurrences.

That separation is important. A template is the recipe. An occurrence is the
actual planned or completed instance.

## Session Templates

A session template describes the kind of session the plan wants the user to do.

It can say:

- What the session is called.
- How often it should happen.
- Where it usually happens.
- What slots it contains.
- How recommendations should be chosen.
- What target counts as complete.
- What to do if it is missed.
- What to ask during review.

Example:

Upper-biased gym visit:

- Schedule: 2 to 3 times per week.
- Environment: JD Gym.
- Slots: 2 from push, 2 from pull, 1 from cardio.
- Completion target: complete enough slots to count as a gym visit.
- Missed policy: ask whether to skip, reschedule, or roll into the next visit.

This is not a log. It is the reusable shape for future sessions.

## Session Slots

A slot is one requirement inside a session template.

Examples:

- 2 from push.
- 2 from pull.
- 1 from cardio.
- Optional 1 from mobility.
- 1 from study drills.
- 1 inventory check.

Slots say what kind of thing is needed. They do not always have to name the
exact thing.

A slot can use rules such as:

- Choose from this pool.
- Require availability in this environment.
- Avoid recently used items.
- Prefer items due for progression.
- Avoid items marked as injured, unavailable, or disliked.
- Allow the user to swap.
- Allow a custom entry.

Slots are how a plan becomes adaptive without becoming vague.

## Session Occurrences

A session occurrence is one actual planned or completed instance of a session.

Examples:

- Monday's upper-biased gym visit.
- Friday's lower-biased gym visit.
- Today's study review.

An occurrence can store:

- Planned date and time.
- Status.
- The recommendation the app gave.
- What the user actually selected.
- Feedback.
- Notes.
- Links to events logged during the session.

Statuses should include:

- Planned.
- Started.
- Completed.
- Missed.
- Skipped.
- Partially completed.

The occurrence is the bridge between the future-looking schedule and the
real-world journal.

## Slot Results

A slot result records how a slot played out inside one occurrence.

For example, the slot says "1 from cardio". The app recommends the rower. The
user uses the bike because the rower is busy.

The slot result can remember:

- The original slot.
- The recommended item.
- The actual item.
- Whether the slot was completed, skipped, or partially completed.
- The event that logged what happened.
- Notes or feedback.

This lets the app learn from reality. If the user swaps rower for bike three
times, maybe bike should become the default. If shoulder press is often skipped,
the plan should ask why.

## Direct Goals

Not everything belongs inside a session.

Some things are better as direct goals:

- Read 20 minutes every day.
- Record bodyweight every morning.
- Walk 5000 steps.
- Take a scheduled dose.
- Practice vocabulary for 15 minutes.
- Complete a small checklist.
- Record mood or symptoms.
- Hit 100 pages this week.

A direct goal can still have a schedule, target, event type, and policy. It just
does not need a session occurrence wrapper.

This keeps the model honest. Gym visits can be sessions. A daily step count can
be a direct metric. A dose can be a direct scheduled event or part of a larger
routine, depending on the plan.

## Events

Events are the journal of what actually happened.

An event is a structured record, not just a note.

Examples:

- Chest Press, 3 sets of 10 at 45 kg, RPE 8.
- Bike, 20 minutes, moderate effort.
- Took 250 mcg from Retatrutide vial 1.
- Read 25 pages of a book.
- Practiced Spanish vocabulary for 15 minutes.
- Corrected inventory count.
- Marked today's planned walk as skipped because of illness.

Events may be linked to a session occurrence, but they do not have to be.

An event can store:

- Effective time.
- Recorded time.
- Plan.
- Event type.
- Optional session occurrence.
- Optional slot result.
- Optional direct goal.
- Summary.
- Quantity.
- Unit.
- Structured payload.
- Note.
- Status.
- Origin.

The effective time is when the thing happened. The recorded time is when the app
received the log. Both matter, especially for offline logging.

Events should be editable. If an event was wrong, the user should be able to
correct it. The app should preserve an auditable history of what changed,
especially when item effects are involved.

Deleting an event should usually archive or void it rather than erase the
concept entirely.

## Event Types

An event type describes what kind of thing can be logged.

Examples:

- Workout exercise performed.
- Cardio block performed.
- Peptide dose taken.
- Vial prepared.
- Inventory correction.
- Pages read.
- Study drill completed.
- Metric recorded.
- Checklist completed.

The event type defines what information should be collected.

For a workout event, that might include:

- Sets.
- Reps.
- Load.
- Unit.
- RPE.
- Pain or symptoms.
- Notes.

For a dose event, that might include:

- Amount.
- Unit.
- Route.
- Site.
- Source vial.
- Subjective feedback.
- Notes.

For reading, that might include:

- Book.
- Start page.
- End page.
- Pages read.
- Comments.

The platform stays generic because these fields are defined by event types, not
hard-coded into the app.

Normal event authoring should feel like forms and choices, not raw schema
editing. Advanced JSON editing can exist for power users and bundle authors, but
it should not be the default path.

## Event Item Links

Events can point to the items involved.

The link has a role.

Examples:

- exercise: Chest Press.
- machine: Bike.
- source vial: Retatrutide vial 1.
- book: The Hobbit.
- environment: JD Gym.
- supply: Syringe box.

These links let the app answer useful questions:

- Show me all history for this exercise.
- Show all events involving this vial.
- What items were used in this session?
- Which items are due for progression?
- Which item should be recommended next?
- Which supplies are running low?

Item links are one of the main reasons structured logging is worth the effort.

## Item Effects

Some events change item state.

Examples:

- Taking a dose subtracts quantity from a vial.
- Wasting medication subtracts quantity from a vial.
- Preparing a vial may add prepared volume.
- Correcting inventory may set a counted quantity.
- Spending money subtracts from a budget pot.
- Buying supplies adds to a supply count.

These changes are stored as item effects.

The key principle is:

current item state = starting facts + active item effects

The app should not treat a manually overwritten "remaining amount" as the main
source of truth. Derived state should come from history.

That makes the system auditable. If a dose event was wrong and gets edited, the
old effect can be voided and a replacement effect can be created. If an
inventory correction happens, the correction itself is part of the history.

The item details screen should show:

- Stored facts.
- Current calculated state.
- Events involving the item.
- Effects that contributed to the current state.
- Warnings, such as low quantity or future planned work that cannot be fulfilled.

## Scheduling

Scheduling answers "when should this happen?"

Scheduling is separate from logging. A schedule is the plan's expectation about
the future. An event is the record of what actually happened.

The same scheduling vocabulary should work for session templates and direct
goals.

Supported patterns should include:

- Every day.
- Selected weekdays.
- Every N days.
- N times per week.
- Every N weeks.
- Monthly.
- After completion.
- Custom.

Schedules may include constraints such as:

- Allowed weekdays.
- Minimum gap.
- Date range.
- Catch-up window.
- Maximum catch-up count.
- Whether missed work should be skipped, repeated, rescheduled, or asked about.

Some schedules are easy to project. "Every Monday, Wednesday, and Friday" can be
drawn across the plan date range.

Some schedules depend on history. "Two days after completion" cannot know the
next date until the previous event or occurrence has been completed.

Some schedules are quotas. "Three times per week" means the app should place or
suggest three occurrences within the week, respecting allowed days and spacing
rules.

The planning package should produce diagnostics when a schedule cannot be fully
projected. A confusing schedule should become a clear warning, not silent
weirdness.

## Targets

Scheduling says when something should happen.

A target says what counts as the intended work.

Examples:

- Walk 20 minutes.
- Read 25 pages.
- Take 250 mcg.
- Complete 1 gym visit.
- Do 2 push exercises, 2 pull exercises, and 1 cardio block.
- Record today's weight.
- Complete a small checklist.

Target styles should include:

- Fixed amount.
- Progression.
- Period total.
- Metric.
- Checklist.
- Item-specific progression.

Fixed amount means the same amount each time, such as 20 minutes or 250 mcg.

Progression means the requested amount changes over time, such as walking from
500 m to 5000 m over a plan.

Period total means the user is aiming for a total across a period, such as 100
pages per week or 3 gym visits per week.

Metric means the goal is to record a value, such as weight, mood, sleep, or
resting heart rate.

Checklist means the occurrence contains small items to tick off.

Item-specific progression means the next target for a particular item changes
because of that item's history. Chest Press should progress because of previous
Chest Press events, not because the calendar says it is week four.

## Missed and Partial Work

Real life is messy. Improve should not assume everything is completed perfectly
on time.

The model should support explicit missed and partial policies.

Examples:

- If missed, skip and continue.
- If missed, offer a catch-up within a few days.
- If missed, ask the user.
- If partially complete, accept it as complete enough.
- If partially complete, keep the remainder for later.
- If a slot is skipped, still allow the session to be completed.
- If a dose is missed, record it and ask rather than blindly moving it.

Different domains need different behavior.

For a gym plan, duplicating a missed workout may be a bad idea because fatigue
and recovery matter.

For medication or peptide routines, automatically rescheduling a missed dose may
be unsafe. The app should record what happened and let the plan policy decide
what options are appropriate.

The platform's job is to record the truth and propose clear choices. The
bundle's or plan's job is to define what "sensible" means.

## Recommendations

Recommendations answer "what should I do today?"

For sessions, recommendations choose items for slots.

Example recommendation for an upper-biased gym visit:

- Push: Chest Press and Shoulder Press.
- Pull: Lat Pulldown and Seated Row.
- Cardio: Rower.

The recommendation can consider:

- The session template.
- Slot rules.
- Pools.
- Environment.
- Recent history.
- Progression readiness.
- User preferences.
- Prior swaps.
- Feedback.
- Unavailable items.
- Items to avoid.

The user can still swap items or log something custom.

The system should remember the difference between:

- What the app planned.
- What the app recommended.
- What the user actually did.
- What the user felt about it.

That difference is the raw material for useful coaching.

## Projection

Projection is the app's way of asking, "what should appear for this date range?"

The projection input should include:

- The user's active plans.
- Session templates.
- Direct goals.
- Schedules.
- Targets.
- Policies.
- Items.
- Pools.
- Environments.
- Event history.
- Item state.
- Date window.

The projection output should include:

- Session occurrences.
- Direct goal targets.
- Target statuses.
- Recommended items.
- Projected period goals.
- Diagnostics.
- Explanations.
- Policy proposals.
- State warnings.

Target statuses should include:

- Planned.
- Completed.
- Missed.
- Skipped.
- Partially completed.

Projection should not mutate history. It should calculate and explain. If a
proposal needs to become real, the app should record a user decision or write a
new event.

This distinction keeps the system predictable.

## Today

Today is the main daily dashboard.

It should be cross-plan. A user may have a fitness plan, a reading plan, and an
inventory routine active at the same time. Today should show what matters now
across all active plans.

The Today page should include:

- A date selector.
- A friendly summary.
- Counts for planned, completed, skipped, missed, partial, and remaining work.
- Today's session occurrences.
- Today's direct goals.
- Quick logging actions.
- Upcoming work.
- Recent journal entries.
- Recent review context.
- Any warnings, such as low inventory or blocked future targets.

The user should be able to log directly from Today.

If something is scheduled, the log should connect to the relevant occurrence,
slot, or direct goal. If something is ad hoc, the log should still be allowed
and stored as an event.

Today should also build useful context for the assistant. It should be easy for
the assistant to know what was planned yesterday, what happened, what is planned
today, what is still open, and what notes the user left.

## Capture and Check-In

The app should make logging fast.

Global capture lets the user log something without navigating through the plan
structure first. The app can offer likely options based on active plans,
near-term projections, recent items, and today's unfinished work.

The check-in flow is the end-of-day counterpart.

It should let the user move quickly through today's planned work:

- Confirm completed items.
- Fill in missing details.
- Mark something skipped.
- Mark something missed.
- Record partial progress.
- Add notes.
- Link ad-hoc events that already happened earlier in the day.

If the user already logged an event during the day, the check-in should not make
them repeat themselves. It should pre-populate the relevant section where it can
match the event to planned work.

This is one of the most important product loops: planned work and ad-hoc logging
should meet in a quick review.

## Journal

The Journal is the cross-plan history view.

It should show events with enough context to make them meaningful:

- Plan.
- Session occurrence or direct goal, when relevant.
- Event type.
- Items involved.
- Effective time.
- Recorded time.
- Outcome.
- Quantity and unit.
- Notes.
- Structured payload.

The Journal should filter by:

- Plan.
- Event type.
- Item.
- Session.
- Direct goal.
- Outcome.
- Date range.

Users should be able to edit or archive events.

The Journal is not just a diary. It is the source material for progress,
recommendations, state, and coaching.

## Calendar

The Calendar is the time-based view of projected and historical work.

It should support:

- Month view.
- Week view.
- List view.

It should display:

- Session occurrences.
- Direct goal targets.
- Completed historical events.
- Missed or skipped work.
- Period goals where useful.

Calendar entries can compress related work. For example, in month view, a gym
session can appear as one item rather than five separate exercise entries.

The Calendar can start read-only, but the natural long-term direction is
editing: reschedule, drag, move, skip, and open the relevant session or goal.

## Progress

The Progress area should explain how things are going.

It should cover more than simple metrics, but metrics are a good starting point.

Progress views should include:

- Latest metric values.
- Trend charts.
- Period totals.
- Session completion.
- Item history.
- Item progression.
- Missed and skipped patterns.
- Partial completion patterns.
- State changes, such as remaining inventory.
- Review summaries.

For a metric track like bodyweight, the app can show latest value, number of
recordings, delta, and a trend chart.

For an exercise, the app can show recent sets, reps, loads, RPE, and progression
suggestions.

For a vial, the app can show starting quantity, doses taken, corrections, and
remaining quantity.

For a reading plan, the app can show pages read, consistency, and estimated
completion.

Progress should be grounded in event history, not vibes.

## Inventory and Stateful Items

Inventory is not a separate product bolted onto planning. It is one use of
stateful items.

The app should support items whose current state is derived from facts and
effects.

Examples:

- A vial's remaining quantity.
- A supply box's remaining count.
- A budget pot's balance.
- A book's current page.
- A project checklist's remaining items.

The Inventory or State view should let the user:

- See active stateful items.
- Add an item.
- Edit item facts.
- Archive an item.
- Open item details.
- Log a structured event against an item.
- See derived state.
- See the effects behind that state.

This gives Improve a powerful foundation: it can understand not only that the
user did something, but also what that action changed.

## AI Coaching

Ask Improve should be a durable assistant inside the product.

It should support:

- Starting a new conversation.
- Loading recent conversations.
- Streaming responses.
- Showing tool calls.
- Showing approval requests.
- Approving or rejecting write actions.
- Cancelling a run.
- Following internal app links.
- Opening as a floating or pinned panel.

The assistant should have access to structured app context, such as:

- Current page context.
- Active plans.
- Today's projection.
- Yesterday's plan and results.
- Recent journal entries.
- Item state.
- Progress summaries.
- Diagnostics and policy proposals.

The assistant should be able to help with:

- Creating a plan.
- Explaining today's work.
- Morning reviews.
- Evening check-ins.
- Weekly reviews.
- Summarizing progress.
- Suggesting plan adjustments.
- Explaining why a recommendation was made.
- Drafting or editing plan bundles.
- Finding relevant app screens.

Write actions should require approval when they change important user data. The
assistant can suggest, but the user should stay in control.

The important principle is that AI coaching sits on top of structured facts. The
AI should not be the only place where the app understands the plan.

The deterministic system should calculate things like:

- This session was missed.
- This slot was skipped.
- This item was swapped.
- This vial is nearly empty.
- This exercise may be ready to progress.
- This schedule cannot place all requested work.

Then the AI can explain those facts in a useful way.

## Morning Review

The morning review should be short and helpful.

It can cover:

- What was planned yesterday.
- What actually happened.
- Missed or partial work.
- Notes, RPE, symptoms, mood, or context.
- Relevant item state.
- Today's planned work.
- Any warnings.
- Any recommended adjustments.

The user should not have to read a wall of text. The assistant should help them
start the day with clarity.

For example:

- "You completed two of three planned items yesterday."
- "You skipped cardio after reporting high effort."
- "Today's upper session is due. I recommend Chest Press, Shoulder Press, Lat
  Pulldown, Seated Row, and Bike."
- "Your vial looks low after the next planned dose."

This should feel like a coach with good notes, not a motivational poster.

## Weekly Review

The weekly review can be deeper.

It can look across:

- Sessions.
- Direct goals.
- Metrics.
- Notes.
- RPE.
- Misses.
- Swaps.
- Item history.
- Item state.
- Progression readiness.
- Repeated friction.

The weekly review is where the app can ask bigger questions:

- What is working?
- What keeps getting skipped?
- What felt too easy?
- What felt too hard?
- Which items should progress?
- Which schedules are unrealistic?
- Which supplies are running low?
- What should change next week?

The output can be conversational, but any proposed change should map back to
real plan data and require approval when appropriate.

## Offline Event Logging

The first offline goal should be modest: allow event logging offline and sync it
later.

Offline logging should support:

- Client-generated IDs.
- Idempotency keys.
- Original effective timestamps.
- Original recorded timestamps.
- Optional links to sessions, slots, goals, and items.
- A local pending-event outbox.
- Clear server acceptance or rejection after reconnecting.

The server remains the authority for validation and generated effects.

The client can store a pending log, but the server decides whether it is valid
for the current plan and what item effects it creates.

This gives the mobile experience enough resilience without committing too early
to a full local-first sync platform.

## Billing and Entitlements

Billing should be part of the app from the start, not a later scramble.

The Billing page should show:

- Current plan.
- Billing status.
- Billing interval.
- Renewal or end date.
- Whether a downgrade is scheduled.
- Available plans.
- Feature limits or entitlements where useful.

The user should be able to:

- Start checkout.
- Open the billing portal.
- Change plan.
- Schedule a downgrade to Free.

The backend should store subscription snapshots and feature entitlements. It
should also support manual billing overrides for support and operations.

Stripe webhooks should be verified, logged, and processed through background
jobs. The app should be able to handle checkout completion and subscription
create, update, and delete events.

The product should work well on a free plan while giving paid plans clear room
for richer usage, AI features, collaboration, or higher limits.

## Admin and Operations

The Admin area is a separate operations surface for trusted admin users.

It should include:

- Overview.
- Users.
- Search.
- Settings.
- Tools.
- System.
- Audit Log.

The overview can show:

- Total users.
- New users this week.
- Realtime pulse or heartbeat status.
- Basic operational health.

The Users page should allow admins to:

- Search users.
- Create a user.
- Open user details.
- Grant or revoke admin access.
- Suspend or unsuspend users.
- Impersonate a user for support.
- Delete a user account when appropriate.

The user details page should show account basics and recent administrative
activity.

Admin Settings should control:

- Whether new signups are allowed.
- Maintenance-mode flags.
- Operator or admin API tokens.

Operator tokens can be read-only or read/write. The plaintext token should be
shown once and then never again. Tokens should be revocable.

The System page should show runtime and build metadata, such as app name,
environment, version, git SHA, build time, release, and build target.

The Audit Log should record administrative events, such as:

- User creation.
- Role grants and revocations.
- Suspension changes.
- User deletion.
- Impersonation start and stop.
- Settings updates.
- Token creation and revocation.

Admin operations should be boring, explicit, and auditable. That is the point.

## Background Jobs, Email, and Realtime

The app should have a background job system.

Early uses include:

- Billing webhook processing.
- Email delivery.
- Assistant run cleanup.
- Long-running imports.
- Scheduled maintenance tasks.
- Future notification delivery.

Email is needed for magic codes and welcome emails. Email templates should have
plain text and HTML bodies.

Realtime support is useful for:

- Assistant streaming.
- Tool-call updates.
- Approval prompts.
- Heartbeat checks.
- Possibly live notifications.

Realtime should be a progressive enhancement. If a realtime connection fails,
the app should have a polling fallback where that makes sense.

Error tracking should include structured metadata, environment, release, request
context, authentication state, and safe error codes.

## Data Ownership and Database Shape

Postgres is the source of truth.

A clean first version would store:

- Users.
- User avatars.
- Login sessions.
- Magic auth codes.
- User roles.
- Global settings.
- Admin API tokens.
- Audit events.
- Billing subscriptions.
- Billing overrides.
- Stripe webhook logs.
- Plans.
- Plan item types.
- Plan items.
- Plan pools.
- Plan pool memberships.
- Plan environments.
- Plan event types.
- Plan session templates.
- Plan session slots.
- Plan direct goals.
- Plan schedules.
- Session occurrences.
- Slot results.
- Event instances.
- Event item links.
- Item effects.
- Assistant conversations.
- Assistant runs.
- Assistant messages.
- Assistant approvals.
- Assistant tool calls.

The exact table design can change, but the ownership should stay clear.

The user owns their plans. Plans own their definitions. Events record what
happened. Effects record what changed. Derived state is calculated from the
stored facts and effects.

Flexible domain-specific data can live in structured JSON where that is useful,
but the core relationships should be clear enough to query and reason about.

## The Planning Package

The planning package is the deterministic brain of the app.

It should receive explicit input and return explicit output.

It should understand:

- Plans.
- Session templates.
- Direct goals.
- Schedules.
- Targets.
- Metrics.
- Quantities.
- Event history.
- Item state.
- Constraints.
- Projection windows.
- Policies.
- Diagnostics.
- Explanations.
- Proposals.

It should produce:

- Projected session occurrences.
- Projected direct goal targets.
- Aggregate goals.
- Target statuses.
- Recommendations.
- Warnings.
- Missed-work proposals.
- Partial-work proposals.
- Progression proposals.

It should not:

- Read from the database.
- Call LLMs.
- Send emails.
- Read the wall clock.
- Talk to the network.
- Mutate the journal.
- Randomly choose outcomes without an explicit seed or deterministic rule.

The planning package can be used by the API, tests, imports, previews, and
assistant context builders. It should be small enough to trust and strict enough
to catch bad plans early.

## Validation and Diagnostics

Improve should validate authored content before it becomes live plan data.

Validation should catch:

- Invalid JSON.
- Schema mismatch.
- Bad date ranges.
- Duplicate keys.
- Missing references.
- Pools pointing at missing items.
- Session slots pointing at missing pools.
- Event links pointing at missing item types.
- Effects pointing at missing event roles.
- Direct goals using missing event types.
- Incompatible bundle versions.
- Duplicate setup question keys.
- Duplicate prompt template keys.
- Schedules that cannot be projected.
- Targets that do not match their units or event types.

Diagnostics should be plain English.

A user or bundle author should see "This session slot points at a pool that does
not exist" rather than a cryptic internal error.

The app should aim to make invalid states hard to create in the normal UI and
easy to understand in the advanced authoring path.

## Security and Approval

Improve stores personal planning data, health-adjacent logs, routines, and
possibly inventory details. It should be careful by default.

Important principles:

- Sessions should use secure HttpOnly cookies.
- Admin access should be role-based.
- Impersonation should be explicit and auditable.
- Sensitive admin actions should be logged.
- Assistant write actions should require approval.
- Background webhooks should be verified.
- API tokens should be scoped and revocable.
- User data should be owned by the user account.
- Export should avoid leaking internal IDs.

The assistant should never silently rewrite a plan, archive history, or change
billing. The user should see and approve meaningful changes.

## What the First Build Should Prioritize

A from-scratch build should not try to ship every future idea at once.

The strongest first version would preserve the core loop:

1. Sign in.
2. Create or import a plan.
3. Define items, sessions, direct goals, schedules, and event types.
4. Project today's work.
5. Log planned and ad-hoc events.
6. Derive progress and item state.
7. Review history in Journal.
8. Show time-based work in Calendar.
9. Support assistant conversations with approval-gated writes.
10. Keep admin, billing, and operations solid.

The most important product surfaces are:

- Today.
- Plan detail.
- Session start/completion.
- Global capture.
- Check-in.
- Journal.
- Calendar.
- Progress.
- Items and item state.
- Plan import/export.
- Ask Improve.
- Profile.
- Billing.
- Admin.

The most important model foundations are:

- Items instead of resources.
- Session templates and occurrences instead of schedule-only sessions.
- Direct goals for things that do not need sessions.
- Events as the journal of truth.
- Event item links for context.
- Item effects for derived state.
- Shared scheduling vocabulary.
- Explicit missed and partial policies.
- Deterministic projection and recommendations.
- AI on top of structured facts.

## A Full Example: Gym Plan

A gym bundle defines item types:

- Exercise.
- Cardio machine.
- Gym environment.

It defines items:

- Chest Press.
- Shoulder Press.
- Lat Pulldown.
- Seated Row.
- Bike.
- Rower.
- JD Gym.

It defines pools:

- Push.
- Pull.
- Cardio.

It defines a session template:

- Upper-biased gym visit.
- 2 to 3 times per week.
- Environment: JD Gym.
- Slots: 2 from push, 2 from pull, 1 from cardio.

The plan projects a session occurrence for today.

The app recommends:

- Chest Press.
- Shoulder Press.
- Lat Pulldown.
- Seated Row.
- Rower.

The user does Chest Press, swaps Shoulder Press for Cable Fly, does Lat Pulldown
and Seated Row, then uses Bike instead of Rower.

Each actual activity is logged as an event.

The session occurrence remembers:

- What was planned.
- What was recommended.
- What was swapped.
- What was completed.
- What the user reported.

Next time, the app has better context. It can know that Chest Press may be ready
to progress, that Bike is often preferred over Rower, and that Shoulder Press
may need attention.

## A Full Example: Vial Inventory Plan

A peptide bundle defines item types:

- Peptide vial.
- Supply.
- Injection site.

It defines an item:

- Retatrutide vial 1.

The vial has starting facts, such as compound, starting amount, unit, prepared
volume, concentration, batch, prepared date, and expiry date.

The bundle defines an event type called Take Dose.

The Take Dose event asks for:

- Amount.
- Unit.
- Route.
- Site.
- Source vial.
- Notes.
- Subjective feedback.

The event type also says that a dose subtracts the amount from the source vial.

The user logs:

- Took 250 mcg from Retatrutide vial 1.
- Effective time: today at 08:00.
- Site: abdomen.
- Note: mild sting.

The event links to Retatrutide vial 1 as the source vial.

The server creates an item effect subtracting 250 mcg from that vial.

The current vial quantity is calculated from the starting vial quantity plus all
active effects.

If the event is edited later, the old effect is voided and a replacement effect
is created.

This gives the user a simple experience while keeping the history auditable.

## A Full Example: Reading Plan

A reading bundle defines item types:

- Book.
- Reading session.
- Reading note.

It defines a book item:

- The Hobbit.

The plan has a direct goal:

- Read 20 minutes every day.

It may also have a period total:

- Read 100 pages per week.

The user logs a reading event:

- Book: The Hobbit.
- Start page: 40.
- End page: 65.
- Duration: 25 minutes.
- Note: easy reading today.

The app can update progress, show reading consistency, estimate the current
page, and bring the note into the weekly review.

This does not need a session unless the user wants a dedicated reading routine.
A direct goal is enough.

## What This System Is Trying to Protect

The system should protect a few product truths.

The plan should be generic enough for many domains.

Domain details should live in authored content, not hard-coded platform columns.

The app should store structured facts, not only notes.

The user should be allowed to follow the plan, swap choices, skip work, partially
complete work, or log something custom.

Derived state should be derived from history.

Scheduling should be deterministic and explainable.

AI should receive good context rather than inventing the app's state.

Offline event capture should be possible without building a huge sync platform
too early.

Admin, billing, profile, auth, and operations should be treated as real product
parts, not prototype leftovers.

The goal is not to make the model clever. The goal is to make the model simple
enough that complicated real life can fit inside it.
