all: rpm iso

rpm:
	/bin/bash packaging/rpm/rpmbuild.sh

iso:
	/bin/bash packaging/iso/isobuild.sh

clean:
	rm -rf packaging/rpm/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
	rm -rf packaging/iso/ISO
	rm -rf packaging/iso/TrinityX-*.iso
