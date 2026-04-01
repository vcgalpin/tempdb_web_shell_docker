#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-8081}"
POSTGRES_DB="${2:-linksdb}"
POSTGRES_USER="${3:-linksuser}"
APP_START_COMMAND="${4:-linx --config=config.debug.0.9.8 src/startXPS.links}"

echo
echo "Useful commands"
echo "---------------"
echo "Host URL:"
echo "  http://localhost:${PORT}"
echo
echo "Inside the container:"
echo "  Start the web app:"
echo "    ${APP_START_COMMAND}"
echo
echo "  Start the Links REPL:"
echo "    linx"
echo
echo "  Connect to PostgreSQL:"
echo "    psql -h /tmp -p 5432 -d ${POSTGRES_DB} -U ${POSTGRES_USER}"
echo
echo "  Show PostgreSQL tables:"
echo "    psql -h /tmp -p 5432 -d ${POSTGRES_DB} -U ${POSTGRES_USER} -c '\\dt'"
echo
echo "  Show current database name:"
echo "    echo \$PGDATABASE"
echo
echo "  Show current user:"
echo "    whoami"
echo
echo "  Show current directory:"
echo "    pwd"
echo
echo "  Check repo status:"
echo "    git status"
echo
echo "  View recent commit history:"
echo "    git log --oneline -n 5"
echo
echo "From another terminal on the host:"
echo "  Open shell in running container:"
echo "    docker exec -it tempdb_web_shell bash"
echo
echo "  Show container logs:"
echo "    docker logs tempdb_web_shell"
echo
echo "  Stop the container:"
echo "    docker stop tempdb_web_shell"
echo
echo "  Remove the container:"
echo "    docker rm -f tempdb_web_shell"
echo
echo "  Remove the database volume:"
echo "    docker volume rm tempdb_web_shell_pgdata"
echo

