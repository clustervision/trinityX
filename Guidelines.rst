Ansible
=======

#. `Variables`_
#. `Passwords`_
#. `Tags`_
#. `Files`_
#. `Execution flow`_

Variables
----------

- Prepend role-level variable names with the name of the role::
  
    mariadb_packages:
      - mariadb
      - mariadb-server
      - MySQL-python  
    
    mariadb_db_path: '/var/lib/mysql'
  
- To make roles portable and reusable, avoid relying on playbook-level and trinityX-specific variables. Define all the variables that are needed to run the role in ``defaults/main.yml``::
  
    # cat roles/drbd/defaults/main.yml
    ---
    
    drbd_ctrl1_ip: '{{ trix_ctrl1_ip }}'
    drbd_ctrl2_ip: '{{ trix_ctrl2_ip }}'
    drbd_ctrl1_device: /dev/drbd1
    drbd_ctrl2_device: '{{ drbd_ctrl1_device }}'
    <...>
  
  
- Sometimes it's okay to override the most frequently redefined variable directly in a playbook, still the playbook should be kept relatively clean::
  
    - role: slurm
      slurmdbd_sql_user: 'slurm_accounting'
      slurmdbd_sql_db: 'slurm_accounting'
      tags: slurm
  
Passwords
---------
  
- Use the ``lookup()`` plugin to generate and retrieve stored passwords::
  
    - name: Acquire root password (generate or use one from /etc/trinity/passwords)
      set_fact:
        mysql_root_pwd: "{{ lookup('password',
                        '/etc/trinity/passwords/mysql/root.txt
                        chars=ascii_letters,digits,hexdigits') }}"
  
Tags
----
  
- Tag roles (and tasks if needed) to make their execution optional::
  
     roles:
       - role: hostname
           tags: hostname
       - role: drbd
           tags: drbd
         <...>
  
  That makes it possible to run a particular subset of roles by either specifying a list of roles, e.g.::
  
  # ansible-playbook --tags hostname,drbd
  
  or excluding some of the roles, e.g.::
  
  # ansible-playbook --skip-tags firewalld
  
Files
-----
  
- When changing configuration files, make a backup of them using the ``backup:`` argument in modules like ``template``, ``lineinfile`` and so on.
  
- Whenever possible, make use of the ``validate:`` argument to check the syntax first.
  
- To trigger a service restart/reload when its configuration files get changedr, use handlers calling them with ``notify:``.
  
- Prefer the ``blockinfile`` and ``template`` modules over ``lineinfile`` as they generally provide better idempotency.
  
Execution flow
--------------
  
- A task should not report a change if nothing has been changed as a result of the task. For that reason, if you can’t avoid using ``command`` or ``shell`` modules, also use ``creates:`` or ``changed_when:`` or similar to control the task's ``changed`` status.
  
- When enabling a systemd service, make sure to start it as well while specifying a condition ``when: ansible_connection not in 'lchroot'``. That would allow using the same role for both images and live nodes.
  
- Instead of including one role in another, list it as a dependency in ``<role>/meta/main.yml``.
