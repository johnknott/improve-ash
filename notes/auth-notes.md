# Plain-English Spec: Integrate OTP Authentication into Improve

## Goal

Add authentication to Improve using AshAuthentication 5.0.0-rc.11 and its built-in OTP strategy.

The app should support a simple email-code signup and login flow:

1. User enters their email.
2. Improve sends a short code to that email.
3. User enters the code.
4. If the code is valid, the user is signed in.
5. If the user does not exist yet, Improve creates a free account.
6. The user lands in the app.

This should work first for the Svelte web app.

The design should also leave room for native mobile apps later.

## Main decision

Use AshAuthentication’s built-in OTP strategy.

Do not build a custom `ash_magic_code_auth` package.

Do not build a custom auth strategy unless the built-in OTP strategy cannot support the Improve flow.

The old magic-code package was useful research, but the new implementation should be much smaller:

```text
AshAuthentication owns:
  OTP generation
  OTP validation
  brute-force protection
  token/session integration
  auth resource integration

Improve owns:
  Svelte login UI
  email templates
  Resend/Cloudflare email delivery
  app-specific signup/onboarding flow
  account settings later
```

## Non-goals

Do not add password login.

Do not add Apple login.

Do not add Google login.

Do not add Microsoft login.

Do not add passkeys yet.

Do not add Stripe or billing.

Do not add account linking or merging yet.

Do not add onboarding yet unless it is required to finish auth.

Do not build a reusable Hex package.

Do not use the old LiveView magic-code UI.

## User-facing auth flow

The first version should have two screens or two states:

```text
Email step:
  "Enter your email"

Code step:
  "Enter the code we sent to you"
```

The user should not have to choose between signup and login.

The wording should be neutral:

```text
Continue with email
```

not:

```text
Sign up
```

or:

```text
Log in
```

The app should treat signup and login as one flow.

If the email is new, create a free account.

If the email already belongs to a user, sign in to that account.

## Backend resources

Add an Accounts domain if it does not already exist.

Core resources:

```text
Improve.Accounts.User
Improve.Accounts.Token
```

Optional later resources:

```text
Improve.Accounts.UserIdentity
Improve.Accounts.AccountEvent
Improve.Accounts.LoginAttempt
```

For the first version, do not add `UserIdentity` unless AshAuthentication needs it for the chosen setup.

A simple user is enough:

```text
User
  id
  email
  inserted_at
  updated_at
```

Possible later fields:

```text
display_name
primary_email
confirmed_at
deleted_at
onboarding_state
```

Do not add billing fields yet.

## User resource requirements

The user resource must have:

```text
primary key
email field
unique identity on email
AshAuthentication extension
tokens enabled
OTP strategy enabled
```

The email field should be a case-insensitive string if practical.

The email identity should be unique.

Conceptually:

```elixir
attributes do
  uuid_primary_key :id
  attribute :email, :ci_string, allow_nil?: false, public?: true
end

identities do
  identity :unique_email, [:email]
end
```

## Token resource

Create a token resource for AshAuthentication.

The token resource is where AshAuthentication stores token state when needed.

The OTP strategy requires tokens to be enabled.

Use the standard AshAuthentication token resource pattern.

The token resource should not be exposed as a normal product API.

## OTP strategy configuration

Configure the OTP strategy on the user resource.

Use email as the identity field.

Enable registration so a new email can create a free account.

Use a short lifetime.

Use a six-digit code.

Use digits only for the first product version because numeric codes are familiar and mobile-friendly.

Conceptually:

```elixir
authentication do
  tokens do
    enabled? true
    token_resource Improve.Accounts.Token
    signing_secret Improve.Accounts.Secrets
    store_all_tokens? true
  end

  strategies do
    otp do
      identity_field :email
      registration_enabled? true

      brute_force_strategy :rate_limit

      otp_lifetime {10, :minutes}
      otp_length 6
      otp_characters :digits_only
      otp_param_name :otp

      sender Improve.Accounts.OtpSender
    end
  end
end
```

The exact module names may change during implementation.

The intended generated action names are:

```text
request_otp
sign_in_with_otp
```

If the strategy name changes, action names will change with it.

## Brute-force protection

Brute-force protection is mandatory.

Do not ship OTP auth without it.

Use AshAuthentication’s OTP brute-force strategy.

For the first version, prefer the simplest secure setup that works with registration enabled.

If `registration_enabled? true` makes the audit-log brute-force strategy awkward, use the rate-limit strategy.

The implementation should prove:

```text
too many requested codes are blocked
too many wrong code attempts are blocked
valid codes expire
valid codes are single-use
```

Do not rely only on the frontend to prevent abuse.

## Code policy

Default policy:

```text
6 digits
10 minute lifetime
single-use token
digits only
case-insensitive does not matter for digits
```

The email should say:

```text
Your Improve code is 123456.

This code expires in 10 minutes.

If you did not request this, you can ignore this email.
```

Do not include product details, account existence information, or sensitive data in the email.

A magic link fallback can be added later, but it is not required for the first version.

## Email sender

Create an app-owned OTP sender module.

The OTP strategy should call this sender.

The sender should pass the email/code to an app email module.

Conceptually:

```text
Improve.Accounts.OtpSender
  called by AshAuthentication

Improve.Emails
  builds email content

Improve.Emails.ResendClient
  sends via Resend

Improve.Emails.LocalMailbox
  used in dev/test
```

The auth strategy should not know about Resend directly.

Use an email behaviour or boundary so the provider can be changed later.

Possible providers:

```text
Resend first
Cloudflare Email later if it becomes attractive
Local/test sender for development and tests
```

## Public backend API for Svelte

Expose a tiny app-level auth API for Svelte.

The frontend should not call random low-level Ash actions directly.

Preferred API shape:

```text
POST /api/auth/request-code
POST /api/auth/verify-code
POST /api/auth/logout
GET  /api/auth/me
```

Or, if this fits better with AshTypescript RPC:

```text
requestLoginCode(email)
verifyLoginCode(email, otp)
logout()
currentUser()
```

The product-level names should be friendly:

```text
requestLoginCode
verifyLoginCode
currentUser
logout
```

They can delegate internally to AshAuthentication’s generated OTP actions.

## Session strategy for web

For the Svelte web app, prefer an HTTP-only secure cookie session.

The Svelte app should not store long-lived auth tokens in localStorage.

The browser should receive a secure session cookie after successful OTP verification.

The frontend then asks:

```text
GET /api/auth/me
```

to determine whether the user is signed in.

Frontend requests should include credentials.

The app should work like this:

```text
verify code succeeds
backend stores auth/session cookie
frontend calls currentUser
frontend navigates to app shell
```

## Future mobile strategy

Native mobile apps may use bearer tokens later.

Do not force the web app to use bearer tokens just because mobile will exist later.

Design the backend so both are possible:

```text
web:
  secure HTTP-only session cookie

mobile:
  bearer token or native secure token storage later
```

The same OTP strategy can remain the identity mechanism.

Mobile can use the same flow:

```text
enter email
receive code
enter code
receive authenticated session/token
```

Apple/Google sign-in is not required for the first mobile version if Improve only uses its own email-code account system.

## Svelte app flow

The Svelte app should have a simple auth client.

Suggested files:

```text
frontend/src/api/authClient.ts
frontend/src/features/auth/LoginPage.svelte
frontend/src/features/auth/EmailStep.svelte
frontend/src/features/auth/CodeStep.svelte
frontend/src/features/auth/authStore.ts
```

Keep it boring.

The UI flow:

```text
LoginPage starts on email step.
User enters email.
Frontend calls requestLoginCode(email).
If successful, move to code step.
User enters six-digit code.
Frontend calls verifyLoginCode(email, code).
If successful, call currentUser().
Store current user in frontend state.
Navigate to app shell.
```

Errors should be generic:

```text
We could not send a code right now.
That code was invalid or expired.
Please wait before trying again.
```

Do not show:

```text
No account exists for that email.
This account exists but has no token.
Code was correct but sign-in failed internally.
```

## Svelte dev setup

During development, the Svelte Vite app should proxy API requests to Phoenix.

Example intent:

```text
frontend dev server:
  http://localhost:5173

Phoenix backend:
  http://localhost:4000

Svelte calls:
  /api/auth/request-code
  /api/auth/verify-code
  /api/auth/me

Vite proxy forwards:
  /api -> http://localhost:4000
```

This keeps frontend code using relative API paths.

Production can serve the built frontend and API from the same origin.

Same-origin deployment keeps cookie-based auth much simpler.

## CORS and cookies

Prefer same-origin deployment.

If frontend and backend are on different origins, configure CORS and cookies deliberately.

Do not casually allow credentials from every origin.

For production, cookies should be:

```text
HttpOnly
Secure
SameSite=Lax or stricter if possible
proper domain
reasonable expiry
```

For local development, use the least weird setup that still resembles production.

## Authenticated API access

Protected API routes should load the current user from the session or bearer token.

If there is no current user, return `401`.

Do not let product actions run without an actor.

Every protected product action should receive the current user as the actor.

The product API rule is:

```text
No actor, no private data.
```

## Frontend auth state

The frontend should treat the backend as the source of truth.

On app load:

```text
call currentUser()
if user exists:
  show app
else:
  show login
```

Do not rely only on a frontend boolean like `isLoggedIn`.

The frontend can cache the current user in a Svelte store, but it should be refreshed from `/api/auth/me` after reloads.

## Logout

Logout should:

```text
revoke/clear server-side auth where appropriate
clear the session cookie
clear frontend current user state
navigate back to login
```

Frontend should call:

```text
POST /api/auth/logout
```

and then clear local auth state regardless of response details.

## Account creation

New users get a free account by default.

Signup should not require:

```text
password
plan selection
payment method
profile setup
social login
```

After first successful sign-in, the user can land on:

```text
Today placeholder
plan creation
or a simple welcome screen
```

Do not build a heavy onboarding flow yet.

## Account deletion

Because Improve creates accounts, include a basic account deletion path in the backend plan.

This does not have to be the first screen in the first auth commit, but the model should not make deletion impossible.

Later, account deletion should be available from account settings.

## Security requirements

The implementation must:

```text
use AshAuthentication 5.0.0-rc.11 or newer compatible release
enable tokens
use a unique email identity
enable brute-force protection
keep OTP lifetime short
make OTP tokens single-use
avoid account enumeration
avoid logging OTP codes
avoid logging auth tokens
use secure cookies for web sessions
use HTTPS in production
return generic auth errors
rate-limit request and verify paths
test wrong, expired, reused, and rate-limited codes
```

The frontend should never store auth tokens in localStorage for web.

## Testing requirements

Backend tests should cover:

```text
request code for new email succeeds
request code sends email through test sender
verify valid code creates a user when registration is enabled
verify valid code signs in existing user
same email reuses same user
wrong code fails
expired code fails
used code cannot be reused
too many wrong attempts are blocked
too many request attempts are blocked
generic response does not reveal whether account exists
currentUser works after sign-in
logout clears authentication
protected API returns 401 when signed out
protected API works when signed in
```

Frontend tests can be light at first:

```text
email form submits request
code form submits verification
invalid code shows generic error
successful verification loads current user
logout clears current user
```

Do not overbuild frontend auth tests before the backend API shape settles.

## Implementation order

Step 1:

```text
Add AshAuthentication 5.0.0-rc.11.
Add or update Accounts.User.
Add Accounts.Token.
Enable OTP strategy.
Enable registration.
Configure sender.
Run migrations.
```

Step 2:

```text
Create test email sender.
Write backend auth story/spec.
Prove request code and verify code work.
```

Step 3:

```text
Create Phoenix JSON auth endpoints or AshTypescript RPC actions.
Implement requestLoginCode.
Implement verifyLoginCode.
Implement currentUser.
Implement logout.
```

Step 4:

```text
Build simple Svelte login page.
Email step.
Code step.
Basic loading and error states.
Current user store.
```

Step 5:

```text
Protect the first real app route.
Redirect signed-out users to login.
Redirect signed-in users into the app.
```

Step 6:

```text
Swap dev/test email sender for Resend in production.
Keep email provider behind an app boundary.
```

## First auth story

Create a story/spec called something like:

```text
08_email_otp_signup_and_login
```

It should prove:

```text
A new user can request a code.
The code is sent.
The code can be verified.
A free user is created.
The user is authenticated.
The current user endpoint returns that user.
The user can log out.
The same email can log in again.
The same user is reused.
Invalid/reused/expired codes fail.
```

This is the auth equivalent of the product stories.

It should describe the user journey, but assert the important security behaviour.

## Main decision

Use the built-in OTP strategy.

Keep auth simple.

Keep Svelte in charge of the UI.

Keep AshAuthentication in charge of authentication mechanics.

Do not ship OAuth yet.

Do not ship passkeys yet.

[1]: https://hex.pm/packages/ash_authentication/5.0.0-rc.11 "ash_authentication | Hex"

