import os
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_directories(host):
    dirs = [
        "/var/lib/slurm_exporter"
    ]
    for dir in dirs:
        d = host.file(dir)
        assert d.exists


def test_user(host):
    assert not host.group("slurm-exp").exists
    assert not host.user("slurm-exp").exists


def test_service(host):
    s = host.service("slurm_exporter")
#    assert s.is_enabled
    assert s.is_running


def test_socket(host):
    sockets = [
        "tcp://127.0.0.1:8080"
    ]
    for socket in sockets:
        s = host.socket(socket)
        assert s.is_listening
