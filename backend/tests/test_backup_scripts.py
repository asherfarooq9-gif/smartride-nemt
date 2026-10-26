"""The backup and restore scripts must not put the database password on a command
line (every user on the host can read it with `ps`) or print it."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
URL = "postgresql+asyncpg://bob:s3cret@db.example:6543/smartride?sslmode=require"

pytestmark = pytest.mark.skipif(
    shutil.which("sh") is None or not (SCRIPTS / "db_backup.sh").exists(),
    reason="needs a POSIX sh and the repo's scripts/ directory",
)

FAKE = """#!/bin/sh
{
  echo "ARGS=$*"
  echo "PGPASSWORD=${PGPASSWORD:-}"
  echo "PGUSER=${PGUSER:-}"
  echo "PGHOST=${PGHOST:-}"
  echo "PGPORT=${PGPORT:-}"
} > "$CAPTURE"
for arg in "$@"; do
  case "$arg" in
    --file=*) printf '%0300d' 0 > "${arg#--file=}" ;;
  esac
done
"""


def _run(tmp_path, script, *args, **extra_env):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    for tool in ("pg_dump", "pg_restore"):
        path = bin_dir / tool
        path.write_text(FAKE, newline="\n")
        path.chmod(0o755)
    capture = tmp_path / "capture.txt"
    env = {
        **os.environ,
        "PATH": f"{bin_dir.as_posix()}{os.pathsep}{os.environ['PATH']}",
        "CAPTURE": capture.as_posix(),
        "DATABASE_URL": URL,
        "BACKUP_DIR": (tmp_path / "backups").as_posix(),
        **extra_env,
    }
    env.pop("PGPASSWORD", None) if "PGPASSWORD" not in extra_env else None
    result = subprocess.run(
        ["sh", (SCRIPTS / script).as_posix(), *args],
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )
    captured = (
        dict(
            line.split("=", 1)
            for line in capture.read_text().splitlines()
            if "=" in line
        )
        if capture.exists()
        else {}
    )
    return result, captured


def test_backup_sends_the_password_in_the_environment_not_the_arguments(tmp_path):
    result, seen = _run(tmp_path, "db_backup.sh")

    assert result.returncode == 0, result.stderr
    assert "s3cret" not in seen["ARGS"]
    assert seen["PGPASSWORD"] == "s3cret"
    assert (seen["PGUSER"], seen["PGHOST"], seen["PGPORT"]) == (
        "bob",
        "db.example",
        "6543",
    )
    assert "--dbname=smartride" in seen["ARGS"].split()


def test_backup_never_prints_the_password(tmp_path):
    result, _ = _run(tmp_path, "db_backup.sh")

    assert "s3cret" not in result.stdout + result.stderr


def test_an_existing_pgpassword_wins_over_the_one_in_the_url(tmp_path):
    result, seen = _run(tmp_path, "db_backup.sh", PGPASSWORD="from-env")

    assert result.returncode == 0, result.stderr
    assert seen["PGPASSWORD"] == "from-env"


def test_a_url_without_a_password_or_port_still_works(tmp_path):
    result, seen = _run(
        tmp_path, "db_backup.sh", DATABASE_URL="postgresql://bob@localhost/smartride"
    )

    assert result.returncode == 0, result.stderr
    assert seen["PGUSER"] == "bob"
    assert seen["PGHOST"] == "localhost"
    assert seen["PGPASSWORD"] == ""
    assert "--dbname=smartride" in seen["ARGS"].split()


def test_restore_asks_for_confirmation_without_printing_the_password(tmp_path):
    dump = tmp_path / "x.dump"
    dump.write_text("dump")

    result, seen = _run(tmp_path, "db_restore.sh", dump.as_posix())

    assert result.returncode == 1
    assert "CONFIRM=yes" in result.stderr
    assert "s3cret" not in result.stdout + result.stderr
    assert "db.example" in result.stderr  # still says where it would restore to
    assert seen == {}  # nothing ran


def test_restore_sends_the_password_in_the_environment_not_the_arguments(tmp_path):
    dump = tmp_path / "x.dump"
    dump.write_text("dump")

    result, seen = _run(tmp_path, "db_restore.sh", dump.as_posix(), CONFIRM="yes")

    assert result.returncode == 0, result.stderr
    assert "s3cret" not in seen["ARGS"]
    assert seen["PGPASSWORD"] == "s3cret"
    assert "--dbname=smartride" in seen["ARGS"].split()
