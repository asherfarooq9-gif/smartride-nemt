# Sourced by db_backup.sh and db_restore.sh (not run on its own).
#
# Splits DATABASE_URL into PG* environment variables, so the password travels in
# the environment instead of on a command line, where `ps` shows it to every user
# on the host, and so it never has to be printed.
#
# Sets DB_NAME and DB_DISPLAY (user@host:port/db, safe to print). A PGPASSWORD that
# is already set wins over the one in the URL. The password is not percent-decoded:
# if it contains special characters, set PGPASSWORD yourself.

load_database_url() {
  url="${DATABASE_URL:-postgresql://smartride:password@localhost:5432/smartride}"
  # libpq wants a plain postgresql:// URL: drop any SQLAlchemy driver suffix.
  url="$(printf '%s' "$url" | sed 's#+asyncpg##; s#postgresql+psycopg2#postgresql#')"

  case "$url" in
    postgresql://* | postgres://*) ;;
    *)
      # Not a URL (a key=value connection string): hand it over unchanged.
      DB_NAME="$url"
      DB_DISPLAY="(connection string)"
      return 0
      ;;
  esac

  rest="$(printf '%s' "$url" | sed 's#^[a-z]*://##')"
  auth="$(printf '%s' "$rest" | sed -n 's#^\([^@/]*\)@.*#\1#p')"
  hostdb="$(printf '%s' "$rest" | sed 's#^[^@/]*@##')"

  user="${auth%%:*}"
  pass=""
  case "$auth" in *:*) pass="${auth#*:}" ;; esac

  host="${hostdb%%[:/]*}"
  after_host="${hostdb#"$host"}"
  port=""
  case "$after_host" in
    :*)
      port="${after_host#:}"
      port="${port%%/*}"
      ;;
  esac
  DB_NAME="${hostdb#*/}"
  DB_NAME="${DB_NAME%%\?*}"

  [ -n "$user" ] && export PGUSER="$user"
  [ -n "$host" ] && export PGHOST="$host"
  [ -n "$port" ] && export PGPORT="$port"
  if [ -z "${PGPASSWORD:-}" ] && [ -n "$pass" ]; then
    export PGPASSWORD="$pass"
  fi
  DB_DISPLAY="${user:+$user@}${host}${port:+:$port}/${DB_NAME}"
}
