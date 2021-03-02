#!/usr/bin/env python3
import sys
import argparse
import urllib.request
import json
import time

PENDING_TIMEOUT = 300
PENDING_WAIT = 30


def get_pending_registrations(tenant, token):
    url = "https://%s.console.ves.volterra.io/api/register/namespaces/system/listregistrationsbystate" % tenant
    headers = {
        "Authorization": "APIToken %s" % token
    }
    data = {
        "namespace": "system",
        "state": "PENDING"
    }
    data = json.dumps(data)
    try:
        request = urllib.request.Request(
            url, headers=headers,  data=bytes(data.encode('utf-8')), method='POST')
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except Exception as ex:
        sys.stderr.write(
            'Can not fetch pending registrations for %s: %s' % (url, ex))
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
            'could not approve registration for %s : %s' % (url, ex))
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
            'Can not delete site %s: %s' % (url, ex))
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
            time.sleep(args.delay)
        end_time = time.time() + PENDING_TIMEOUT
        approved_registrations = 0
        while (end_time - time.time()) > 0:
            pending = get_pending_registrations(
                args.tenant, args.token)
            if not pending:
                time.sleep(PENDING_WAIT)
            else:
                for reg in pending['items']:
                    passport = reg['get_spec']['passport']
                    passport['tenant'] = reg['tenant']
                    passport['cluster_size'] = args.size
                    tunnel_type = 'SITE_TO_SITE_TUNNEL_IPSEC'
                    if args.ssl == 'true' and args.ipsec == 'true':
                        tunnel_type = 'SITE_TO_SITE_TUNNEL_IPSEC_OR_SSL'
                    elif args.ssl == 'true':
                        tunnel_type = 'SITE_TO_SITE_TUNNEL_SSL'
                    if approve_registration(args.tenant, args.token, reg['name'], reg['namespace'], 2, passport, tunnel_type):
                        approved_registrations = approved_registrations + 1
                    if approved_registrations == args.size:
                        sys.exit(0)

    if args.action == "sitedelete":
        decomission_site(args.site, args.tenant, args.token)

    sys.exit(0)


if __name__ == '__main__':
    main()
