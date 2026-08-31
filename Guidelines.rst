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

- To trigger a service restart/reload when its configuration files get changed, use handlers calling them with ``notify:``.

- Prefer the ``blockinfile`` and ``template`` modules over ``lineinfile`` as they generally provide better idempotency.

Execution flow
--------------

- A task should not report a change if nothing has been changed as a result of the task. For that reason, if you can’t avoid using ``command`` or ``shell`` modules, also use ``creates:`` or ``changed_when:`` or similar to control the task's ``changed`` status.

- When enabling a systemd service, make sure to start it as well while specifying a condition ``when: ansible_connection not in 'lchroot'``. That would allow using the same role for both images and live nodes.

- Instead of including one role in another, list it as a dependency in ``<role>/meta/main.yml``.

Legal
=====

Contributions and waiver of claims
----------------------------------

By submitting any contribution to this project — including but not limited to
source code, configuration, documentation, patches, or pull requests — you
irrevocably and unconditionally waive any and all claims of ownership,
authorship, compensation, or any other right or interest in that contribution,
both now and at any time in the future.

This waiver applies in full regardless of the capacity in which the
contribution is made. It applies whether you contribute as an individual or on
behalf of, in the name of, or as a representative of any other person, company,
organisation, or other legal entity. No such company or organisation may assert
any claim over a contribution on the basis that the contributor acted in its
name.

A contribution, once submitted, is permanently waived from any claim. This
waiver is perpetual and irrevocable, and cannot be withdrawn, reversed, or
limited at any later date by the contributor or by any party on whose behalf the
contributor acted.

That said, the legal wording above is only there to keep things clear and
unencumbered for everyone. It takes nothing away from how much we value your
help: every contribution, large or small, is genuinely appreciated, and we are
grateful to everyone who takes the time to make this project better.
