# Security Policy

`chatgpt-pro-consult` is designed to avoid credential handling.

## Never supported

- Asking users for ChatGPT cookies/session tokens.
- Reading browser profile databases.
- Reading OS keychains/password managers.
- Storing API keys, cookies, passwords, or private keys in receipts.
- Uploading `.env`, SSH keys, private certificates, or raw customer data.

## Report issues

Open a GitHub issue if you find a path where the skill or scripts leak secrets, bypass the scanner, mishandle receipts, or invoke a backend without explicit local configuration.
