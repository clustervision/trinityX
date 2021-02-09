from pyanaconda.installclasses.centos import RHELBaseInstallClass
from pyanaconda.product import productName


class TrinityXBaseInstallClass(RHELBaseInstallClass):
    name = "TrinityX"
    sortPriority = 30000
    if not productName.startswith("CentOS"):
        hidden = True

    defaultFS = "ext4"
