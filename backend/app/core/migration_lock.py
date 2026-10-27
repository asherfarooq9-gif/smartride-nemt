"""Shared key for the advisory lock that serialises Alembic runs."""

# Arbitrary but fixed: every instance must ask for the same number.
MIGRATION_LOCK_ID = 7402391

# How long one migration statement may wait for a table lock before it fails.
LOCK_TIMEOUT = "5s"
