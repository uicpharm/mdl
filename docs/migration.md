# Migration Instructions

"Migration" means moving a Moodle environment from one hosted location to another. These
notes describe how to migrate our Moodle environments, both from a traditional server to
a Docker container, and from one Docker container to another (i.e. from a developer
workstation to a production server).

Formal instructions from Moodle:

   - <https://docs.moodle.org/39/en/Moodle_migration>
   - <https://docs.moodle.org/401/en/Moodle_migration>
   - <https://docs.moodle.org/405/en/Moodle_migration>
   - <https://docs.moodle.org/500/en/Moodle_migration>

::: warning Before You Begin

You should already be able to ssh into the remote server that you'll be backing up the
Moodle environment from. Commands will be issued to the remote server via ssh.

Also be sure your `.env` file (i.e. `environments/mymoodle/.env`) is set up correctly for
your environment *before* trying to migrate the environment. This file is automatically
generated with minimal settings if it doesn't yet exist, but it may not have a lot of the
settings you want. Setting it first will make things go more smoothly.

:::

## Migrating with the `mdl backup` script

A backup should always be performed while the source environment is **running** since part
of the backup involves a database dump.

1. Put the environment in [maintenance mode][moodle_maint_mode]. *(This is not strictly
   required if you are migrating to your workstation for development purposes.)*
2. Backup the source environment to your desired target environment by running
   `mdl backup` on the computer you want to run the migrated instance on.
3. Restore the backup with the `mdl restore` script.
4. Start the environment with the `mdl start` script.

Alternately, instead of running a `mdl backup` and `mdl restore`, you could run a single
call of `mdl backup --sync` to quickly *sync* your environment with the source
environment. This is faster and more efficient, and leaves no leftover backup files.
However, if you are developing where you may want to repeatedly reset your environment,
you may *prefer* to make a backup so that you can repeated restore from the backup set
quickly and without constantly hitting the production environment.

Note that the database backup isn't fully restored until the environment is started. The
first time the environment starts, it will detect and automatically restore the `.sql`
dump file which was copied to your environment as `backup.sql`.

[moodle_maint_mode]: https://docs.moodle.org/401/en/Maintenance_mode
