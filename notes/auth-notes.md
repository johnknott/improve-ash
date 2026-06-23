Here’s a short spec capturing the auth direction. The key external constraints are: AshAuthentication supports magic-link-style auth, including registration by email when enabled; Apple’s Sign in with Apple requirement is mainly triggered when offering third-party/social login; and Google Play requires account deletion support if an app allows account creation. ([Hexdocs][1])

# Plain-English Auth Spec

## Goal

Improve should have a simple, low-friction signup and login flow.

The default account should be free. Users should not have to choose a plan, enter payment details, create a password, or pick a social login provider before they can use the app.

The first auth method should be email-code login.

This gives us one clean identity flow across web and mobile:

1. User enters email.
2. Improve sends a short login code.
3. User enters the code.
4. If the user does not exist, create a free account.
5. If the user already exists, sign them in.
6. Issue a session/token.
7. Send them into the app.

The email may also include a magic sign-in link for convenience, but the code should be the core flow because it works well on web and mobile.

## Initial auth methods

For v1, Improve should support:

```text
Email code signup
Email code login
Logout
Session/token refresh if needed
Account deletion
```

For v1, Improve should not support:

```text
Password login
Google login
Apple login
Microsoft login
Passkeys
Stripe billing
Full account merging UI
```

Those can come later.

## Why email code first

Email code auth is simple and elegant.

It avoids most of the complexity caused by social login providers:

```text
Different provider emails
Apple private relay emails
Duplicate accounts
Provider-specific subject IDs
Identity linking
Social login policy rules
OAuth setup and callback edge cases
```

It also works consistently across:

```text
desktop web
mobile web
native iOS
native Android
```

The canonical Improve account identity is therefore:

```text
Your Improve account is your email.
```

Other sign-in methods may be added later, but they are not needed for the first version.

## Account model

Even though v1 only ships email-code auth, the data model should allow future sign-in methods.

Conceptually:

```text
User
  The actual Improve account.

Identity
  A way to sign in to that account.
```

A user may eventually have many identities:

```text
email_code
apple
google
passkey
```

But in v1, every user will normally have just one identity:

```text
provider: email_code
provider_subject: normalized email address
```

The important rule is:

```text
User is the account.
Identity is a sign-in method.
Email is contact information and, for email-code auth, also the provider subject.
```

This keeps the system ready for future Apple, Google, or passkey login without forcing that complexity into the first release.

## Suggested data shape

```text
User
  id
  primary_email
  name / display_name optional
  confirmed_at
  onboarding_state
  inserted_at
  updated_at
  deleted_at optional

Identity
  id
  user_id
  provider
  provider_subject
  email_claim
  email_verified_at
  metadata
  inserted_at
  updated_at

LoginChallenge
  id
  email
  code_hash
  expires_at
  consumed_at
  attempts
  purpose
  ip_address optional
  user_agent optional
  inserted_at
```

`provider_subject` should be unique per provider.

For email-code auth:

```text
provider: email_code
provider_subject: normalized email
```

For future OAuth:

```text
provider: apple/google
provider_subject: stable provider subject id
email_claim: email returned by provider, if any
```

Do not rely on social-provider email addresses as permanent identity.

## Signup flow

```text
User enters email.
Normalize email.
Create login challenge.
Email code to user.
User enters code.
Verify code.
If no user exists for this email, create user.
Create email_code identity if needed.
Mark email as verified.
Create session/token.
Return current user/session to frontend.
```

This should feel like signup and login are the same action.

The user should not need to know whether they are signing up or signing in.

## Login code rules

Login codes should be:

```text
short-lived
single-use
rate-limited
attempt-limited
stored hashed, not plain text
```

Example policy:

```text
6 digit code
expires after 10-15 minutes
maximum 5 attempts
consumed after successful verification
newer challenge invalidates or supersedes older challenges for the same email/purpose
```

The exact numbers can change later.

## Email delivery

Email sending should be behind a small app-level behaviour.

```text
Improve.Accounts.EmailSender
```

Implementations can include:

```text
Resend
Cloudflare Email
Local/dev logger
Test adapter
```

The auth system should not depend directly on Resend or Cloudflare.

The email content should include:

```text
The login code
A short expiry message
A magic link if we choose to support one
A note to ignore the email if the user did not request it
```

## Mobile strategy

Email code should remain the default mobile sign-in method.

This avoids needing Apple/Google sign-in on day one.

If Improve later adds Google login to iOS, then Apple login should also be offered. But if Improve only uses its own email-code login system, social sign-in is not required just because the app is on mobile.

For native apps, code entry is preferable to relying only on magic links because it avoids deep-link and email-client awkwardness.

## Future sign-in methods

Later, Improve may add:

```text
Passkeys
Apple Sign in
Google Sign-In
Microsoft login
```

When that happens, they should be added as extra identities on the same user account.

They should not replace the user model.

A future Account Settings page can show:

```text
Primary email
Sign-in methods
  Email code
  Apple
  Google
  Passkey
Add sign-in method
Remove sign-in method
```

## Account linking rule

Do not auto-merge accounts just because emails match.

Do not assume accounts are separate just because emails differ.

To link or merge accounts, the user must prove control of both.

Safe linking examples:

```text
User is signed in with email code.
User clicks "Add Apple sign-in".
User completes Apple sign-in.
Attach Apple identity to the current user.
```

Or:

```text
User is signed in with Apple.
User clicks "Link existing email account".
User enters email.
User verifies email code.
Attach email identity or offer account merge.
```

Full account merging can be deferred.

For v1, it is enough to avoid painting ourselves into a corner.

## Account deletion

Because Improve creates user accounts, account deletion should be planned from the beginning.

At minimum, the system should have a clear account deletion action.

The product can decide later whether deletion means:

```text
hard delete
soft delete
scheduled deletion after grace period
anonymise user data
```

But the first implementation should not make deletion impossible.

## Stripe and plans

Billing is not part of initial auth.

Every new user gets a free account by default.

Later, Improve can add:

```text
Plans page
Stripe checkout
Subscription status
Feature limits
Billing portal
```

This should be separate from signup.

Signup should stay frictionless.

## Implementation direction

Use AshAuthentication as the auth foundation where it fits well.

Use its user/token/session patterns and magic-link support where useful.

If the exact code-entry UX is not provided directly, build a small email-code layer around the same account/session model.

The important product behaviour is:

```text
Enter email.
Receive code.
Verify code.
Get a free account.
Use Improve.
```

## First auth story/spec

Create a story/spec for:

```text
request code for new email
email sender receives a code
verify code
free user is created
email_code identity is created
session/token is issued

request code for same email
verify code
same user is reused

wrong code fails
expired code fails
used code cannot be reused
too many attempts fails
```

This story should prove the whole signup/login loop without adding social login, billing, or passkeys.

## Main decision

Ship email-code auth first.

Design the account model so Apple, Google, Microsoft, and passkeys can be added later.

Do not ship OAuth providers until there is a real product reason.

Keep signup simple.

[1]: https://hexdocs.pm/ash_authentication/magic-links.html?utm_source=chatgpt.com "Magic Links Tutorial — ash_authentication v4.13.7"

