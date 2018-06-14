all: rpm

rpm:
	/bin/bash packaging/rpm/rpmbuild.sh

clean:
	rm -rf packaging/rpm/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
	rm -rf packaging/iso/ISO
	rm -rf packaging/iso/TrinityX-*.iso
