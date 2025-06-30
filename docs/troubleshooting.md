# Troubleshooting FAQs

How do I troubleshoot...

## MariaDB won't start or database is empty

If the MariaDB container won't stay started or its database is empty, this is probably a
sign of a file permission issue. The `backup.sql` file should have the owner set to the
`docker` user when running Docker.

Generally, permissions are set properly for this file within the backup/restore scripts,
but if you placed it there manually, make sure this permission is set.

## Moodle is in a restart loop

If the Moodle container is in a restart loop, it's possible that it is trying to perform
an upgrade unsuccessfully, or cannot connect to the database.

**If it can't connect to the database.** First of all, be patient. If you just performed
a restore, it can take a while for the one-time initialization of the database from the
`backup.sql` file to be accomplished, and the Moodle container will timeout and restart
while it is waiting for the database to be reachable. Secondly, if the database container
has any permission issues causing it to not stay started, that must be addressed first.
Conversely, a third possibility, if the database had been initialized when the `.env`
file had different database settings, it could be that it just legitimately can't connect
with the database settings. Either change the `.env` file or delete the existing database
volume (you could fully remove all environment data with `mdl rm $mname`) and then do a
fresh restore again which will use the current database settings.

**If it looks like it's restarting when "Running database upgrade".** This would be
unusual, but it could be that the database and Moodle code are out of sync, which would
imply it is in the middle of an upgrade/downgrade and thus it is resetting while it waits
for the matter to get resolved.

You could get some insight in asking the CLI to report its status checks:

```sh
mdl cli $mname checks
```

Additionally, and to be used with more caution, you could initiate an upgrade to see what
happens. If there's no upgrade action to be performed, it will not do anything.

```sh
mdl cli $mname upgrade --non-interactive
```
