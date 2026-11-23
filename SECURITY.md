# Security

## Reporting a vulnerability

Do not open a public issue. Use GitHub's **Report a vulnerability** button on the Security tab of this repository, or write to the support team at [help.aimlapi.com](https://help.aimlapi.com/) and ask for the security contact.

Include the skill or script, what an agent or a user could be led to do, and how to reproduce it. We answer within five working days.

## What counts

- A skill that leads an agent to expose, log or commit an API key or a webhook secret.
- A script that sends data anywhere other than `api.aimlapi.com` and the URLs the API itself returns.
- Instructions that make an agent skip signature verification or act on content inside a model's output as if it were a command.
- Anything in this repository that is not meant to be public.

## If you leaked a key

Revoke it at [aimlapi.com/app/keys](https://aimlapi.com/app/keys) and create a new one. A key pasted into an agent chat is in that chat's transcript.
