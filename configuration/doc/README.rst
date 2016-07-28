
.. vim: tw=0


Trinity X configuration tool documentation
==========================================

This directory contains the documentation for the Trinity X initial configuration tool.


Overview
--------

The Trinity X configuration tool revolves around the concept of post-installation scripts, or *post scripts*. After the installation of the base OS, the configuration tool will install packages and run an arbitrary list of those post scripts to implement the Trinity X configuration. Those scripts deal typically with one piece of software only or the configuration of one specific area of the system. Most of them are optional, allowing for a high level of control over the final state of the system.

The list of post scripts to run for a given installation is defined in a *configuration file*. That file may also contain additional configuration parameters for the various post scripts.

The configuration tool takes one or more configuration file names as parameters, and processes the configurations in that order. For ease of post script creation, it provides various *environment variables* and *common functions* that can be used by the post script writers.


Table of contents
-----------------

General documentation
~~~~~~~~~~~~~~~~~~~~~

The general documentation is split into the following chapters:

- `Configuration tool usage`_

- `Configuration files`_

- `Post scripts`_

- `Environment variables`_

- `Common functions`_


Post script documentation
~~~~~~~~~~~~~~~~~~~~~~~~~




.. include:: relative_links.rst

