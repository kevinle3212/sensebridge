---
description: Prune Docker's build cache, unused images, stopped containers, and networks to reclaim disk space — safe by default, deep clean only with confirmation.
---

# docker-clean

Reclaims local disk space from Docker. Two tiers: a **safe** default that only
removes objects Docker can always recreate, and a **deep** tier (all unused
images, volumes) that requires explicit confirmation because it can destroy
data no `docker pull`/`docker build` gets back.

## Steps

1. Confirm Docker is running: `docker info`. If it's not, say so and stop.
2. Show current usage before touching anything: `docker system df -v`.
3. Run the safe prune — no confirmation needed, these are always reversible:
   - `docker container prune -f` — stopped containers.
   - `docker image prune -f` — dangling (untagged) images only.
   - `docker network prune -f` — unused user-defined networks.
   - `docker builder prune -f` — build cache.
4. Show usage after: `docker system df -v`, and report the space reclaimed.
5. **Deep clean — ask first, never run automatically.** If the user wants
   more space back, list what it would remove before running anything:
   - `docker image prune -a -f` — ALL unused images, not just dangling (any
     image not referenced by a running or stopped container gets deleted;
     re-pullable, but a slow re-pull for large images).
   - `docker volume ls -f dangling=true` — list unattached volumes **first**
     and let the user review; volumes can hold irreplaceable data (databases,
     generated state). Only run `docker volume prune -f` after the user
     confirms the listed volumes are safe to lose.
   - Never run the combined `docker system prune -a --volumes -f` without the
     user explicitly asking for it and confirming the volume list from the
     previous step.
6. Report exactly what was removed and how much space was reclaimed, and
   what's left available for a deep clean if the user wants it.

Note: SenseBridge doesn't use Docker for the app itself — serverless/on-device
by doctrine, see `docs/TOOLING.md`. This command is local machine hygiene
only, not a project dependency.
