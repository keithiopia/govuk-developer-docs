---
owner_slack: '#navigation'
title: Bouncer
section: Transition
layout: manual_layout
parent: "/manual.html"
old_path_in_opsmanual: "../opsmanual/2nd-line/applications/bouncer-and-transition.html"
last_reviewed_on: 2017-05-03
review_in: 6 months
---

[Bouncer](https://github.com/alphagov/bouncer) is a Ruby/Rack web app that receives requests for the URLs of government sites that have either been transitioned to GOV.UK, archived or removed. It queries the database it shares with Transition and replies with a
redirect, an archive page or a 404 page. It also handles `/robots.txt`
and `/sitemap.xml` requests.

Transition is a Rails app that allows users in transitioning
organisations and at GDS to view, add and edit the mappings used by
Bouncer. It also presents traffic data sourced from CDN logs and logs
provided by transitioning organisations (though this latter activity has
now ended).

## Bouncer's stack

### DNS

When sites transition they are generally CNAMEd to a domain we control that
points to our CDN (an A record is used for root domains which can't be CNAMEd).

Some sites partially transition, which means that they redirect some paths to
their AKA domain, which is CNAMEd to us.

GDS doesn't control the DNS for most transitioned domains, except for some domains such as
`*.direct.gov.uk`, `*.businesslink.co.uk`, `*.alphagov.co.uk`. We are working on providing a more exhaustive list. If the DNS
for a particular transitioned site isn't configured correctly we need to inform
the responsible department so they can fix it themselves.

### CDN

Bouncer has a separate CDN service at Fastly ("Production Bouncer") from the
main GOV.UK one, and it's configured by a
[separate Jenkins job](../../infrastructure/architecture/cdn.html#bouncer-s-fastly-service)
which adds and removes domains to and from the service.
That job fetches the list of domains which should be configured at the CDN from
Transition's [hosts API](https://transition.publishing.service.gov.uk/hosts), so
will fail if that is unavailable.

[More information about Bouncer's Fastly service](https://docs.publishing.service.gov.uk/manual/cdn.html#bouncer39s-fastly-service)

### Machines

Bouncer runs on 3 machines in the `redirector` vDC (`bouncer-[1-3].redirector`),
and they are load-balanced at the vShield Edge rather than by a separate machine.
Bouncer's traffic does not go through the `cache-*` nodes - the CDN proxies all
requests to `bouncer.publishing.service.gov.uk` which points to its vShield Edge.

It uses an Nginx default vhost so that requests for all domains are passed on to
the application; there's generally no Nginx configuration for individual
transitioned sites (but see [Special cases](#special-cases) below).

In the case of a data centre failure, within the disaster recovery (DR) vCloud organisation we have:

* Bouncer application servers which read from the DR database slave
* a second PostgreSQL slave for the Transition database

### Application

Bouncer is a small application, and so long as its dependencies are present the
only thing to do if it's erroring is to restart it.

### Database

Bouncer reads from the `transition_production` database by connecting to
`transition-postgresql-slave-1.backend`. It authenticates using its own
postgresql role which is granted `SELECT` permissions on all tables
[by Puppet](https://github.com/alphagov/govuk-puppet/blob/master/modules/govuk/manifests/apps/bouncer/postgresql_role.pp#L17-L33),
and that role is further restricted to connecting only to the slave because the
[pg_hba.conf rule](https://github.com/alphagov/govuk-puppet/blob/master/modules/govuk/manifests/node/s_transition_postgresql_slave.pp#L24-L30)
to allow it isn't present on the master.

### Special cases

- We reverse-proxy requests for [some paths on www.mhra.gov.uk](https://github.com/alphagov/govuk-puppet/blob/master/modules/bouncer/templates/www.mhra.gov.uk_nginx.conf.erb#L16-L56)
to the old site because some tools had not yet been redeveloped when they
transitioned and they needed to continue to be served; their site is often slow
to respond and may time out. This proxying is handled by Nginx so these requests
are not routed to Bouncer.
- We serve some assets which were previously on directgov and businesslink
[via Nginx](https://github.com/alphagov/govuk-puppet/blob/master/modules/govuk/manifests/apps/bouncer.pp#L56-L146)
on the Bouncer machines. The assets live in [two](https://github.com/alphagov/assets-directgov)
[repos](https://github.com/alphagov/assets-businesslink) which are [fetched and
rsynced](https://github.com/alphagov/govuk-app-deployment/blob/master/bouncer/config/deploy.rb#L16-L41)
to the machines when Bouncer is deployed.
