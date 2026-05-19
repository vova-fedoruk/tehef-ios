# tehef iOS

Native SwiftUI client for [tehef.io](https://tehef.io). The app targets iOS 26 and uses Apple's Liquid Glass materials for navigation chrome, cards, and controls while talking to the existing Next.js API.

## Requirements

- Xcode 26 or newer
- iOS 26 simulator or device
- A running tehef backend (production or local)

## Configure API host

1. Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig`.
2. Set `API_BASE_URL` to your backend origin, for example `https://tehef.io` or `http://127.0.0.1:3000`.
3. Set `TURNSTILE_SITE_KEY` to the same Cloudflare **site key** as `NEXT_PUBLIC_TURNSTILE_SITE_KEY` on the server (not the secret). Leave empty to skip the widget locally.

`Config/Secrets.xcconfig` is gitignored so local hosts and staging URLs stay off GitHub.

Turnstile loads in a WebView with your API origin as the page base URL, so the hostname in the Cloudflare dashboard should include your API host (e.g. `tehef.io`). Google sign-in does not use Turnstile.

## Open and run

1. Open `Tehef.xcodeproj` in Xcode.
2. Select the `Tehef` scheme and an iOS 26 simulator.
3. Build and run.

## What ships in this first cut

- Liquid Glass shell with tab navigation for Home, Tasks, Chat, and Profile
- Public home feed plus authenticated home when signed in
- Task browse and task detail
- Email/password sign-in and sign-up with Keychain token storage
- Chat conversation list for signed-in users

## Next backend-facing milestones

- Task apply/create flows
- Message thread UI and SSE or push notifications
- Google Sign in with `ASWebAuthenticationSession`
- Universal Links for task and chat deep links
- APNs device token registration

## Repository layout

- `Tehef/App` — app entry, root routing, tabs
- `Tehef/Core` — API client, models, session storage
- `Tehef/Design/Glass` — Liquid Glass design primitives
- `Tehef/Features` — feature screens
- `Config` — local API configuration

The web backend lives in the separate `taskrabbit-israel` repository.
