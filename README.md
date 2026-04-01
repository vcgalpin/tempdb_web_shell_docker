# tempdb_web_shell

This directory contains a shell-first Docker setup for a Links web application with PostgreSQL.

It is intended for interactive use.

The container provides:

- the Links application code
- PostgreSQL
- `bash`
- `psql`
- `linx`
- an interactive shell environment

The web app does **not** start automatically when you enter the container.  
Instead, you are dropped into a shell and can choose what to run.

---

## Files

This setup uses:

- `Dockerfile`
- `entrypoint.sh`
- `run-web-shell.sh`
- `show-status.sh`
- `show-change-status.sh`
- `show-commands.sh`

---

## What `run-web-shell.sh` does

When you run:

```bash
./run-web-shell.sh
```

the script can:

1. optionally show the current local Docker status
   - image
   - container
   - volume

2. check GitHub for the latest version of the configured branch

3. compare the current local image commit with the latest remote commit

4. classify changes as:
   - no changes
   - only code changed
   - only SQL dump changed
   - both code and SQL dump changed

5. show a second status section describing:
   - local commit
   - remote commit
   - detected change type
   - currently selected actions

6. let the user choose manual override actions:
   - rebuild image anyway
   - recreate database volume anyway
   - both
   - neither

7. ask any additional targeted questions if needed

8. start or attach to the shell container

---

## First-time setup

Make the scripts executable:

```bash
chmod +x run-web-shell.sh show-status.sh show-change-status.sh show-commands.sh
```

Then run:

```bash
./run-web-shell.sh


---

## What happens when the container starts

The container entrypoint:

1. starts PostgreSQL
2. creates the database role if needed
3. creates the database if needed
4. loads the SQL dump if the database does not already exist
5. opens an interactive shell with the correct `opam` environment loaded

This means `linx` should be available directly in the shell.

---

## Typical usage

### Start the shell container

```bash
./run-web-shell.sh
```

### Start the web app from inside the container

```bash
linx --config=config.debug.0.9.8 src/startXPS.links
```

### Start the Links REPL

```bash
linx
```

### Connect to PostgreSQL

```bash
psql -h /tmp -p 5432 -d linksdb -U linksuser
```

### Show PostgreSQL tables

```bash
psql -h /tmp -p 5432 -d linksdb -U linksuser -c '\dt'
```

### Check Git repo status

```bash
git status
```

### Show recent commits

```bash
git log --oneline -n 5
```

---

## Ports

The container is started with this mapping:

- host port `8081`
- container port `8080`

So if you start the web app inside the container, it should be reachable at:

- <http://localhost:8081>

---

## Rebuild and database behaviour

### If only code changed
The script can ask whether to rebuild the image.

### If only the SQL dump changed
The script can ask whether to recreate the database volume.

### If both changed
The script can ask separately about:
- rebuilding the image
- recreating the database volume

### Manual override
Even if nothing changed, you can still choose to:

- rebuild the image anyway
- recreate the volume anyway
- do both

---

## Database persistence

The PostgreSQL data is stored in the Docker volume:

```text
tempdb_web_shell_pgdata
```

This means:

- the database persists across container restarts
- rebuilding the image does not automatically reset the database
- recreating the volume removes the existing database state

---

## Useful host-side commands

### Show running containers

```bash
docker ps
```

### Open a shell in the running container

```bash
docker exec -it tempdb_web_shell bash
```

### Show logs

```bash
docker logs tempdb_web_shell
```

### Stop the container

```bash
docker stop tempdb_web_shell
```

### Remove the container

```bash
docker rm -f tempdb_web_shell
```

### Remove the database volume

```bash
docker volume rm tempdb_web_shell_pgdata
```

---

## Resetting everything

To remove both the container and the database volume:

```bash
docker rm -f tempdb_web_shell
docker volume rm tempdb_web_shell_pgdata
```

Then run again:

```bash
./run-web-shell.sh
```

---

## Configuration values in the script

The main values are currently set in `run-web-shell.sh`:

- image name
- container name
- volume name
- GitHub repo URL
- GitHub branch
- SQL dump path
- database name
- database user
- database password
- web app start command

If you need to change behaviour, those are the first places to look.

---

## Notes

### Linux user
The container runs as:

```text
linksuser
```

### Shell
The interactive shell is:

```text
bash
```

### Links executable
Use:

```bash
linx
```

not `links`.

---

## Summary

This setup is designed to be:

- interactive
- shell-first
- easy to inspect
- easy to rebuild when GitHub changes
- able to distinguish between code changes and SQL dump changes

The main entry point for normal use is:

```bash
./run-web-shell.sh
```
```
