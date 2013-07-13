effective-tlds.org
==================

## Why?

Ever needed to match the official list of TLDs? Ever parsed the Mozilla TLD file?
Yeah - we did too.  You are not alone.

After doing this one time too many, we decided it was time to feed many birds with one seed. 
We fetch, parse, and host it -so you don't have to. 

Wouldn't it be nice to have a semi-authoritative, parsed representation of this file's data
at a reliable location?  What happens then? 

## How?

At this time, we offer the following for your view and consumption:
    /api/v1/changes.json
    /api/v1/tld_flat.json
    /api/v1/tld_rev.json
    /api/v1/tld_tree.json

### Status

see TODO vis-a-vis DONE

## DONE

* fetch, parse, json-ify code. Using AnyEvent 

## TODO

* watcher - or at least cron to get updates
* XML format
* any other formats that could/would be useful? 
* wiki links as metadata
* per-node metadata, eg who/when added entry X?
* other metadata?

## Who?

gleeco - inspired, and not necessarily cajoled by RayRay.

