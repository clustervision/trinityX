#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule
from zabbix_api.zabbix_api import ZabbixAPIException, ZabbixAPI
import xml.etree.ElementTree as ET


def get_templateid_by_name(zapi, xml_doc):
    xml_root = ET.fromstring(xml_doc)
    templ_name = xml_root.findall(".//*name/../template")
    params = {
        "output": "extend",
        "filter": {
            "host": [t.text for t in templ_name]
        }
    }
    templ_object = getattr(zapi, 'template')
    method = getattr(templ_object, 'get')
    result = method(params)
    return [r['templateid'] for r in result if 'templateid' in r]


def main():
    module = AnsibleModule(
        argument_spec=dict(
            username=dict(required=True),
            password=dict(required=True, no_log=True),
            hostname=dict(required=True),
            proto=dict(default="http", choices=["http", "https"]),
            validate_certs=dict(default=True, type="bool"),
            timeout=dict(default=120, type="int"),
            object=dict(required=True),
            action=dict(required=True, choices=["get", "set"]),
            params=dict(default={}, type="dict"),
            filter=dict(default={}, type="dict"),
        )
    )
    try:
        zapi = ZabbixAPI(
            "{}://{}/zabbix".format(
                module.params["proto"],
                module.params["hostname"]
            ),
            validate_certs=module.params["validate_certs"],
            timeout=module.params["timeout"])
        zapi.login(module.params["username"], module.params["password"])
        conf_object = getattr(zapi, module.params["object"])
        msg = []

        # Firt handle objcects witout 'get' method

        # 'configuration'
        if module.params["object"] == "configuration":
            temp_ids = get_templateid_by_name(
                zapi, module.params['params']['source']
            )
            if len(temp_ids) > 0:
                result = "Template already exists in Zabbix config"
                module.exit_json(changed=False, result=result, msg=msg)
                return
            method = getattr(conf_object, "import")
            result = method(module.params['params'])
            msg.append(module.params['params'])
            module.exit_json(changed=True, result=result, msg=msg)
            return

        # passed params become filter if latter is not specified
        # we need to find a desired object somehow
        if module.params["filter"] == {}:
            query_filter = module.params["params"]
        else:
            query_filter = module.params["filter"]

        method = getattr(conf_object, "get")
        params = {}
        params["output"] = "extend"
        # add additional options for actions:
        if module.params["object"] == 'action':
            params.update({
                "selectOperations": "extend",
                "selectRecoveryOperations": "extend",
                "selectFilter": "extend",
            })
        params["filter"] = query_filter
        result = method(params)

        # if 'get' was specified exit right here
        if module.params["action"] == "get":
            module.exit_json(changed=False, result=result, msg=msg)
            return

        # 'set' was specified
        # 'mediatype', 'hostgroup' and 'action'
        # not all methods for hostgroup are supported
        if module.params["object"] not in ["action", "mediatype", "hostgroup"]:
            msg = (
                "Unable to operate with object '{}'"
            ).format(module.params["object"])
            module.fail_json(msg=msg)
            return

        # No objects found. Need to create objects
        if len(result) == 0:
            method = getattr(conf_object, "create")
            result = method(module.params['params'])
            module.exit_json(changed=True, result=result, msg=msg)
            return

        # One or more objects exist. Need to update them.
        method = getattr(conf_object, "update")

        # If more than 1 object found makes sense to warn user
        warnings = None
        if len(result) > 1:
            warnings = "Filter '{}' matches several items".format(query_filter)

        # Loop over found object if they match desired config
        need_to_change = False
        for elem in result:
            for k, v in module.params['params'].items():
                if k in elem and elem[k] == v:
                    continue
                need_to_change = True

        return_obj = {"changed": False, "result": result, "msg": msg}
        if warnings is not None:
            return_obj["warnings"] = warnings

        # Nothing should be changed. Return.
        if not need_to_change:
            module.exit_json(**return_obj)
            return

        # Now we need to update objects
        # copy result to data and update fields from module.params['params']
        data = []
        for elem in result:
            obj_ids = {k: v for k, v in elem.items() if k.endswith("id")}
            obj_ids.update(module.params['params'])
            data.append(obj_ids)

        result = method(data)

        return_obj["changed"] = True
        return_obj["result"] = data
        module.exit_json(**return_obj)
        return
    except ZabbixAPIException as e:
        module.fail_json(msg="Zabbix API exception:{}".format(e))
        return

if __name__ == '__main__':
    main()
