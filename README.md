# db-email-reports

This is a template for building SQL reports that can be scheduled by
`cron` and sent by email.  It is currently designed to work with
PostgreSQL.

## Installation

This template is designed to run locally on a database system.  It
relies on a local user existing who can connect without a password to
the databases.

Such a user can be created and assigned appropriate permissions with:

    useradd -rU -d /tmp dbreports
    sudo -u postgres psql template1 "create role dbreports login;"
    sudo -u postgres psql template1 "grant connect on database reportdb to dbreports;"
    sudo -u postgres psql reportdb "grant usage on schema public to dbreports;"
    sudo -u postgres psql reportdb "grant select on all tables in schema public to dbreports;"

We also need to ensure the user can connect without a password to the
database with:

    cat >> /etc/postgresql/*/main/pg_hba.conf <<EOF
    local all dbreports peer
    EOF

This causes PostgreSQL to check the local system user against the
requested database user to ensure that they match.

## Usage

This template is meant to be directly modified to include your report
and changes to the provided email template.

## Dependencies

This template depends on [shlib-mimemail](https://github.com/traviscross/shlib-mimemail).

This script runs under a POSIX-style `sh` (such as `dash`) on `linux`.
It also requires `sendmail`, `base64`, `gzip`, and `psql`.

## Templates

The template you'll want to use is:

[Report Template](db-email-reports.sh)

## License

This project is licensed under the
[MIT/Expat](https://opensource.org/licenses/MIT) license as found in
the [LICENSE](./LICENSE) file.
