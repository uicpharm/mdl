# Database FAQs

How do I...

## Access Moodle database within the Docker stack?

Three possible ways to give yourself access to the database are: Access the `mysql` client
from CLI, set up phpMyAdmin, or probably the easiest, expose port 3306 on the database
container.

### Use the `mdl tunnel` script

The [mdl tunnel](./scripts.md#mdl-tunnel) script will allow you to set up a tunnel to a
port on an existing container. Run it and it's like you exposed the port! This is the
simplest way to get going. Its defaults are to connect to the database, so your command
can look very simple:

```sh
mdl tunnel $mname start
```

The tunnel is created via an additional container that connects to the Moodle
environment's same network.

When you are done, just stop the tunnel:

```sh
mdl tunnel $mname stop
```

### Expose port 3306

Alternatively to using `mdl tunnel`, you could literally expose port 3306 of the database
container by temporarily adding this to the `mariadb` service:

```yml
ports: [ 3306:3306 ]
```

### Use the `mdl exec-sql` script

If you just need to execute a SQL file on the database, you can just run it with the help
of the [mdl exec-sql](./scripts.md#mdl-exec-sql) script.

### Access `mysql` client from CLI

If you want to run the `mysql` CLI, you can enter the console of the database container
and run the `mysql` client. Something like this on the server hosting the container:

```sh
# Provide instance name depending on which environment you want
mname=mymoodle
# Database name is 'moodle_mymoodle'
dbname=moodle_mymoodle
docker exec -it "$(docker ps -f "label=com.docker.compose.project=$mname" --format '{{.Names}}' | grep mariadb)" mysql --user=root -p $dbname
```

## Access production database with GUI tools?

You can also use the [mdl tunnel](./scripts.md#mdl-tunnel) script to set up a tunnel to
the container on a remote host as well.

```sh
mdl tunnel $mname start your-host.com
```

This uses the same approach as it does for a local tunnel to the container: It sets up a
separate container that tunnels the desired port. When pointing to a remote host, it
creates the container on the host, and then sets up a corresponding SSH tunnel on the
client.

At that point, you can then login to the database with your GUI tool of choice, like
[Azure Data Studio][azure-data-studio], using the proper credentials, pointing to server
`localhost`. This works because now your local machine is sending port 3306 traffic that
it receives through the tunnel to the server. Keep your ssh connection open while working
through the tunnel.

[azure-data-studio]: https://learn.microsoft.com/en-us/sql/azure-data-studio/download-azure-data-studio
