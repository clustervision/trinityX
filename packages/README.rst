
:Name:          trinityX installation packages
:Post script:   local-repo.sh

During the trinityX controller installation, the optional `local-repo.sh` script
can create a local RPM repository to install custom-built packages or to work
around the lack of connectivity.

It does this by copying the contents of the `packages` directory (which contains
this file) as-is. Therefore the directory must contain a ready-to-use repository
in its top level. When preparing the installation media for trinityX, don't
forget to run a command similar to this one::

        createrepo -v --update --compress-type bz2 --basedir packages

The internal layout of the directory doesn't matter, as long as the repository
was created in its top level.

