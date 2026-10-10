# Security

Report a vulnerability in this repository through GitHub private vulnerability reporting on the repository.

https://github.com/SenjuWoo/reverse-this/security

Do not open a public issue for a security report.

The installer only downloads HTTPS URLs from the GitHub release it just queried, or a RenderDoc stable zip whose version comes from the current RenderDoc release tag. It checks a published SHA-256 when the release provides exactly one. A pattern that matches zero or several assets fails that tool instead of picking one.
