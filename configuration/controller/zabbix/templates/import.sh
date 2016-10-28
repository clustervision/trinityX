#!/bin/bash
display_usage() { 
	echo "This script import template into local zabbix server" 
	echo -e "\nUsage:\n$0 template file \n" 
	return 0
} 
if [  $# -lt 1  ] ||  [ ! -e $1 ] 
	then 
		display_usage
		exit 1
fi 

TEMPL=$(cat $1 |sed -e 's/"/\\"/g'|  sed -e 's/^[ \t]*//g' | tr -d '\n' )
source /trinity/trinity.shadow
echo "getting token"
TOKEN=$(curl -s localhost/zabbix/api_jsonrpc.php \
              -H 'Content-Type: application/json-rpc' \
              -d '{"jsonrpc": "2.0",
                   "method": "user.login",
                   "auth": null,
                   "id": 1,
                   "params": {
                        "user": "Admin",
                        "password": "'${ZABBIX_ADMIN_PASSWORD}'"
                   }}'  | python -c "import json,sys; auth=json.load(sys.stdin); print (auth[\"result\"])")
echo "Got token"
echo "importing template"
curl -s localhost/zabbix/api_jsonrpc.php \
              -H 'Content-Type: application/json-rpc' \
              -d '{"jsonrpc": "2.0",
                   "method": "configuration.import",
                  "params": {
                       "format": "xml",
                       "rules": {
                              "hosts": {
                                    "createMissing": true,
                                    "updateExisting": true
                              },
			      "templates": {
                                    "createMissing": true,
                                    "updateExisting": true
                              },
			      "applications": {
                                    "createMissing": true,
                                    "updateExisting": true
                              },
			      "discoveryRules": {
                                    "createMissing": true,
                                    "updateExisting": true
                              },

			      "graphs": {
                                    "createMissing": true,
                                    "updateExisting": true
                              },

			      "triggers": {
                                    "createMissing": true,
                                    "updateExisting": true
                              },
                              "items": {
                                    "createMissing": true,
                                    "updateExisting": true,
                                    "deleteMissing": true
                              }
				
                       },
                       "source": "'"${TEMPL}"'"
                   },
                   "auth": "'${TOKEN}'",
                   "id": 2
	         }'  
echo ""
