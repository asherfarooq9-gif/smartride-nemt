"""Shared key for the advisory lock that serialises Alembic runs."""

# Arbitrary but fixed: every instance must ask for the same number.
MIGRATION_LOCK_ID = 7402391
