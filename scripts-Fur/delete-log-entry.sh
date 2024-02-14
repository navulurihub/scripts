#!/bin/bash


curl -v -G -X POST 'https://logs-prod-004.grafana.net/loki/api/v1/delete' --data-urlencode 'query={stream_name="uos-gh-migration-test-01"}'  -u "$GRAFANA_USER:$GRAFANA_PASSWORD"

#curl -v -G -X POST 'https://logs-prod-004.grafana.net/api/v1/accesspolicies' -u "$GRAFANA_USER:$GRAFANA_PASSWORD"
