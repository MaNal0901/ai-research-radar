# Deployment: weekly run on a Windows PC

The workflow is started from outside through its webhook, so n8n does not need to stay
running all week. `scripts/run-radar.bat` starts everything, runs the workflow, then shuts
everything down.

## What the script does

1. Takes a lock file so two runs never overlap (a lock older than one day is treated as a
   leftover from a crash and removed).
2. Starts Docker Desktop if it is not running and waits for the engine (5 minutes max).
3. Starts the n8n container with the `n8n_data` volume (workflows, credentials and the
   `papers_seen` table are kept between runs).
4. Calls `POST /webhook/run-radar`, retrying until n8n is ready (5 minutes max).
5. Waits for the workflow to finish, then stops n8n, Docker Desktop and WSL, and
   removes the lock.

Everything is logged to `C:\radar\run.log`.

## Install

1. Create the folder and copy the script:

```powershell
mkdir C:\radar
copy scripts\run-radar.bat C:\radar\
```

The script uses `C:\radar` for its log and lock file; edit the `LOG` and `LOCK` variables
at the top if you want another location.

2. Make sure n8n has been set up once (see [SETUP.md](SETUP.md)) and the workflow is **active**.
3. Run `C:\radar\run-radar.bat` by hand once and check `C:\radar\run.log`.

## Schedule it

```powershell
schtasks /Create /TN "AI Research Radar" /TR "C:\radar\run-radar.bat" /SC WEEKLY /D MON /ST 08:00 /F
```

Then open **Task Scheduler**, edit the task and tick **Run task as soon as possible after a
scheduled start is missed**, so a run is not lost if the PC was off on Monday morning.
The task must run while you are logged in (Docker Desktop needs a user session).

## Adjusting the wait time

The script waits a fixed time for the workflow to finish (`Start-Sleep -Seconds 900`).
Increase it if your runs take longer: a run is mostly Gemini calls, and the free tier is rate-limited.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `already running, abort` in the log | A previous run is still going, or a stale `run.lock` younger than one day: delete it |
| `docker timeout` | Docker Desktop did not start within 5 minutes |
| `webhook failed` | Workflow not active, or n8n did not start (check `docker logs n8n`) |
| arXiv branch fails | `NODES_EXCLUDE=[]` missing from the `docker run` command |

## Alternative: a server

On an always-on machine, skip the script: run n8n permanently and enable the deactivated
`Schedule Trigger` in the workflow instead of calling the webhook.