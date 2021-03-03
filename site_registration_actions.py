#!/usr/bin/env python3
import sys
import argparse
import urllib.request
import json
import time

PENDING_TIMEOUT = 300
PENDING_WAIT = 30

# REGISGTRATION_STATES = [ 'NOTSET', 'NEW', 'APPROVED', 'ADMITTED', 'RETIRED', 'FAILED', 'DONE', 'PENDING', 'ONLINE', 'UPGRADING', 'MAINTENANCE' ]

COUNT_REGISTRATION_STATES = ['APPROVED', 'ADMITTED', 'ONLINE']


def get_registrations(site, tenant, token):
    url = "https://%s.console.ves.volterra.io/api/register/namespaces/system/registrations_by_site/" % site
    headers = {
        "Authorization": "APIToken %s" % token
    }
    try:
        request = urllib.request.Request(
            url, headers=headers, method='GET')
        with urllib.request.urlopen(request) as response:
            return response['items']
    except Exception as ex:
        sys.stderr.write(
            "Can not fetch site registrations for %s: %s\n" % (url, ex))
        sys.exit(1)


def approve_registration(tenant, token, name, namespace, state, passport, tunnel_type):
    url = "https://%s.console.ves.volterra.io/api/register/namespaces/system/registration/%s/approve" % (
        tenant, name)
    headers = {
        "Authorization": "APIToken %s" % token
    }
    data = {
        "namespace": namespace,
        "name": name,
        "state": state,
        "passport": passport,
        "connected_region": "",
        "tunnel_type": tunnel_type
    }
    data = json.dumps(data)
    try:
        request = urllib.request.Request(
            url=url, headers=headers, data=bytes(data.encode('utf-8')), method='POST')
        urllib.request.urlopen(request)
        return True
    except Exception as ex:
        sys.stderr.write(
            "could not approve registration for %s : %s\n" % (url, ex))
        return False


def decomission_site(site, tenant, token):
    url = "https://%s.console.ves.volterra.io/api/register/namespaces/system/site/%s/state" % (
        tenant, site)
    headers = {
        "Authorization": "APIToken %s" % token
    }
    data = {
        "namespace": "system",
        "name": site,
        "state": "DECOMMISSIONING"
    }
    data = json.dumps(data)
    try:
        request = urllib.request.Request(
            url=url, headers=headers, data=bytes(data.encode('utf-8')), method='POST')
        urllib.request.urlopen(request)
    except Exception as ex:
        sys.stderr.write(
            "Can not delete site %s: %s\n" % (url, ex))
        sys.exit(1)


def main():
    ap = argparse.ArgumentParser(
        prog='site_registration_actions',
        usage='%(prog)s.py [options]',
        description='preforms Volterra API node registrations and site delete actions'
    )
    ap.add_argument(
        '--action',
        help='action to perform: registernodes or sitedelete',
        required=True
    )
    ap.add_argument(
        '--site',
        help='Volterra site name',
        required=True
    )
    ap.add_argument(
        '--tenant',
        help='Volterra site tenant',
        required=True
    )
    ap.add_argument(
        '--token',
        help='Volterra API token',
        required=True
    )
    ap.add_argument(
        '--ssl',
        help='Allow SSL tunnels',
        required=False,
        default='true'
    )
    ap.add_argument(
        '--ipsec',
        help='Allow SSL tunnels',
        required=False,
        default='true'
    )
    ap.add_argument(
        '--size',
        help='Node(s) in cluster to register',
        required=False,
        default=1,
        type=int
    )
    ap.add_argument(
        '--delay',
        help='seconds to delay before processing',
        required=False,
        default=0,
        type=int
    )
    args = ap.parse_args()

    if args.action == "registernodes":
        if args.delay > 0:
            sys.stdout.write(
                "delaying polling for CE pending registrations for %d seconds..\n" % args.delay)
            sys.stdout.flush()
            time.sleep(args.delay)
        end_time = time.time() + PENDING_TIMEOUT
        counted_registrations = 0
        while (end_time - time.time()) > 0:
            registrations = get_registrations(
                args.site, args.tenant, args.token)
            if not registrations:
                sys.stdout.write(
                    "no registrations pending approval.. retrying in %d seconds.\n" % PENDING_WAIT)
                sys.stdout.flush()
                time.sleep(PENDING_WAIT)
            else:
                for reg in registrations:
                    if reg['object']['status']['current_state'] == "PENDING":
                        passport = reg['get_spec']['passport']
                        passport['tenant'] = reg['tenant']
                        passport['cluster_size'] = args.size
                        tunnel_type = 'SITE_TO_SITE_TUNNEL_IPSEC'
                        if args.ssl == 'true' and args.ipsec == 'true':
                            tunnel_type = 'SITE_TO_SITE_TUNNEL_IPSEC_OR_SSL'
                        elif args.ssl == 'true':
                            tunnel_type = 'SITE_TO_SITE_TUNNEL_SSL'
                        if approve_registration(args.tenant, args.token, reg['name'], reg['namespace'], 2, passport, tunnel_type):
                            sys.stdout.write("approved registration %s for node %s\n" % (reg['name'], reg['get_spec']['infra']['hostname']))
                            counted_registrations = counted_registrations + 1
                    elif reg['object']['status']['current_state'] in COUNT_REGISTRATION_STATES:
                        counted_registrations = counted_registrations + 1
                    if counted_registrations == args.size:
                        sys.exit(0)
        sys.stderr.write(
            "no registrations pending approval after %d seconds.. giving up.\n" % PENDING_TIMEOUT)
        sys.stdout.flush()

    if args.action == "sitedelete":
        decomission_site(args.site, args.tenant, args.token)

    sys.exit(0)


if __name__ == '__main__':
    main()
