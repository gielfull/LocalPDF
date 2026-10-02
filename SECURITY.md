# Security Policy

LocalPDF handles documents people often consider sensitive, so security reports are very
welcome.

## Reporting a vulnerability

Please **don't open a public issue**. Report it privately through GitHub:
**Security → Report a vulnerability** on this repository
(https://github.com/gielfull/LocalPDF/security/advisories/new).

Include what you found, how to reproduce it, and the impact you see. If a PDF triggers it,
attach a minimal sample that contains no real personal data. You'll get an answer within a
few days.

## What's in scope

- Crashes, hangs or memory blow-ups from malformed or malicious PDFs.
- Anything that lets the app reach the network, or escape the sandbox.
- Encryption mistakes: Protect producing weaker protection than it claims, passwords or
  restrictions dropped silently, Unlock bypassing a password it shouldn't.
- Data left behind: temporary files, unencrypted copies, or (once Redact ships) text that
  survives redaction.
- Problems in the vendored qpdf or libjpeg code as LocalPDF uses it. Issues that are in
  upstream code itself should also go to [qpdf](https://github.com/qpdf/qpdf/security).

## Supported versions

LocalPDF is pre-1.0; fixes land on `main`.
