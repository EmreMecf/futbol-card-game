# V21 release security and integration gate

## Security incident — local credential files
The V21 feature branch previously tracked `database/.yerel_postgres_sifresi` and `database/.yerel_test_hesabi`. This fix removes those files from the latest tree and adds ignore rules. **Deleting files in a new commit does not erase their Git history or any copies that were downloaded.**

Before merge/deployment:
1. Identify any credential stored in those files privately; never paste it into an issue, PR, CI log or chat.
2. Rotate/revoke any matching real PostgreSQL password and test-account password; invalidate sessions/tokens where appropriate.
3. Check access logs for unauthorized activity. Treat publicly exposed secrets as compromised.
4. Plan history rewriting using git-filter-repo or an equivalent vetted process **only with repository owner approval**, a backup, collaborators informed and an agreed freeze. Force pushing can affect all open PRs and clones; it does not guarantee removal from all external caches.
5. Verify the repository and any build artifacts no longer contain reusable secrets. Keep local test files outside Git.
6. Ensure GitHub Actions secret scanning / push protection is configured where supported.

## Integration gate
- [ ] PR #7 V21 security cleanup merged into its feature branch or equivalent safe process
- [ ] #3 OAuth sign-in is tested with V21 auth navigation
- [ ] #4 iOS build works with updated portrait-only orientation
- [ ] #5 adaptive matchmaking warnings are wired into V21 matching screen
- [ ] #6 friends/private matches use proper no-reward UI, new-match route, and separate matchmaking
- [ ] New and legacy V21 feature-flag modes both pass Flutter tests
- [ ] Database migrations and independent end-to-end CI pass
- [ ] Two real Android devices: live match, reconnection, AFK, match result, reward integrity
- [ ] HTTPS/WSS staging backend, distinct test DB, JWT_SECRET, backup and restore checks
- [ ] Android release signing and iOS release/TestFlight smoke tests pass
- [ ] Feature flags are explicitly reviewed before production rollout

## Verification note
This file is a checklist, **not evidence that any test ran**. Do not merge solely because Git reports "mergeable". Track verified GitHub Actions run URLs and test artifacts on the pull request.
