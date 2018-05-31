all: rpm

rpm:
	/bin/bash packaging/rpmbuild.sh

clean:
	rm -rf packaging/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
