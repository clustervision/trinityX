ansible-role-ssl-certs
======================

Generate and/or deploy SSL certificate

Available on Ansible Galaxy: [jdauphant.ssl-certs](https://galaxy.ansible.com/list#/roles/3115)

# Examples

## Example to generate a self-signed SSL certificate

```YAML
 - hosts: all
   roles:
     - jdauphant.ssl-certs
```

This will create certificate and private key in:

- `/etc/ssl/myserver.mydomain.com.key`
- `/etc/ssl/myserver.mydomain.com.pem`

## Example to deploy a SSL certificate

```YAML
 - hosts: all
   roles:
    - role: jdauphant.ssl-certs
      ssl_certs_common_name: "example.com"
```

The certificate has to be placed in `files/ssl/example.com.key` and `files/ssl/example.com.pem`. If
they don't exist, the key and a **self-signed** certificate will be generated at
`/etc/ssl/example.com/example.com.key` and `/etc/ssl/example.com/example.com.pem` using the provided common name.


## Example to deploy a SSL certificate using local key/pem files

```YAML
 - hosts: all
   roles:
    - role: jdauphant.ssl-certs
      ssl_certs_local_privkey_path: '/path/to/example.com.key'
      ssl_certs_local_cert_path: '/path/to/example.com.pem'
```

## Example to deploy a SSL certificate stored in variables

An SSL certificate and key are just text that can be stored as a variable, which is useful when
using ansible vault.

Example variable data, note how the text blob is indented. This is needed to correctly insert the
text via the template module.

```YAML
ssl_certs_local_privkey_data: |
  -----BEGIN RSA PRIVATE KEY-----
  MIIEpQIBAAKCAQEAu2uhv2cjoN4F3arUZ5cDrwuxf3koCwrKSK75as0WZoxYrpyw
  Lyx9ldyD4nGabVep0R/uAgQ/HqEf2jC7WIvGcEq8bHB9PyEEWzT8IjKQX0YTc//4
  gkHBkpyU0fVrj5nkc30EIbcbH4RHRDwye4VhP/iCPchDG7OqvCyOdm8=
  -----END RSA PRIVATE KEY-----
ssl_certs_local_cert_data: |
  -----BEGIN CERTIFICATE-----
  MIIDmzCCAoOgAwIBAgIJAKWMlgLwrBzXMA0GCSqGSIb3DQEBCwUAMGQxCzAJBgNV
  QAL3naEfBSZBl0tBohuxn8Xd3yLPuKGUOk3pSL1IJy0Ca6p+QwjkaZUd9X3gf1V2
  SEfYSaGPvfIlSuHIshno
  -----END CERTIFICATE-----
```

Then simply include the role as in the first example.

## Example to use this role with my Nginx role: [jdauphant.nginx](https://github.com/jdauphant/ansible-role-nginx)

```YAML
 - hosts: all
   roles:
     - jdauphant.ssl-certs
       ssl_certs_generate_dh_param: true
     - role: jdauphant.nginx
       nginx_configs:
          ssl:
               - ssl_certificate_key {{ssl_certs_privkey_path}}
               - ssl_certificate     {{ssl_certs_cert_path}}
               - ssl_dhparam         {{ssl_certs_dhparam_path}}
       nginx_sites:
          default:
               - listen 443 ssl
               - server_name _
               - root "/usr/share/nginx/html"
               - index index.html
```
