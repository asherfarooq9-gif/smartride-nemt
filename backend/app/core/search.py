"""LIKE patterns for user-typed search boxes."""


def contains(term: str) -> str:
    """Pattern matching `term` literally: %, _ and backslash lose their wildcard meaning.

    Use with `column.ilike(contains(term), escape="\\")`.
    """
    escaped = term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"
