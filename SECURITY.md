# Security policy

Portlight surfaces security-adjacent information, so privacy regressions are treated as security issues.

Please report vulnerabilities privately through GitHub's **Report a vulnerability** feature rather than a public issue. Include the affected version, reproduction steps, and expected impact.

Portlight is intentionally read-only. It reads process, port, public SSH-key, launch-job, startup-item, storage, and developer-tool metadata available to the current macOS user. It must never read or display private SSH-key contents, tokens, passwords, or secret environment values.
