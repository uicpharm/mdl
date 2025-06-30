# Scheduled Tasks

This documents scheduled tasks that are used in the host of our Moodle environments.
Scheduled tasks that should occur *within* the Moodle environment should be set up within
Moodle itself. These are intended to run on the host server.

## Production

In all cases, these backups are uploaded to Box.com and then deleted locally to avoid
taking too much server storage.

Database backups everyday at 12:07am, 6:07am, 12:07pm, 6:07pm.

```txt
7 0,6,12,18 * * * root /data/moodle/bk.sh all containers -m db -l midday && /data/moodle/cp.sh all midday -b -r
```

Full daily backup at 2:05am.

```txt
5 2 * * * root /data/moodle/bk.sh all containers -l daily && /data/moodle/cp.sh all daily -b -r
```

Monthly backup on 1st of month at 4:05am with a date stamp label.

```txt
5 4 1 * * root /data/moodle/bk.sh all containers -l "$(date +\%Y\%m\%d)" && /data/moodle/cp.sh all "$(date +\%Y\%m\%d)" -b -r
```

## Staging

Sync with the production server data every Sunday at 3:00am.

```txt
0 3 * * 0 root /data/moodle/backup.sh all containers ocems.pharm.uic.edu:/data/moodle -s -e '-i /home/jcurt/.ssh/id_rsa' && /data/moodle/start.sh all
```
