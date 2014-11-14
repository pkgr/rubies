# rubies

This repository hosts the source code that compiles up to date MRI Ruby versions, and releases them as DEB or RPM packages for a wide range of linux distributions.

This work is supported by [Packager.io](https://packager.io).

## Supported Ruby versions

* MRI 2.1.5 (patchlevel 273, rubygems 2.2.2)
* MRI 2.0.0 (patchlevel 594, rubygems 2.0.14)
* MRI 1.9.3 (patchlevel 550, rubygems 1.8.23.2)

Note: MRI rubies include statically compiled versions of libffi (3.0.10), libyaml (0.1.6), and libjemalloc (3.6.0).

## Supported distributions

* Ubuntu 14.04 LTS x86_64
* Ubuntu 12.04 LTS x86_64
* Debian 7 x86_64
* CentOS 6 x86_64
* RedHat 6 x86_64

## Installation & Usage

Head over to <https://packager.io/gh/pkgr/rubies>, and select the instructions for your distribution.

For instance, on Ubuntu 14.04, to install the latest ruby-2.1:

    wget -qO - https://deb.packager.io/key | sudo apt-key add -
    echo "deb https://deb.packager.io/gh/pkgr/rubies trusty stable" | sudo tee /etc/apt/sources.list.d/rubies.list
    sudo apt-get update
    sudo apt-get install ruby-2.1

The package will install files in `/opt/ruby-2.1`, and executables in `/opt/ruby-2.1/bin`.

Using the installed ruby is then simple:

    $ /opt/ruby-2.1/bin/ruby -v
    ruby 2.1.5p273 (2014-11-13 revision 48405) [x86_64-linux]

    $ /opt/ruby-2.1/bin/gem -v
    2.2.2

    $ /opt/ruby-2.1/bin/bundle -v
    Bundler version 1.6.3

Note: You probably want to add `/opt/ruby-2.1/bin` to your `$PATH` environment variable for convenience.

## Extras

A version of `node` is also shipped with the package, in `/opt/ruby-{2.1,2.0,1.9}/node/bin`. This is an old version (0.6.8), but could be useful if you just want to precompile assets and don't need a more recent version.

## Maintenance

Packages will be updated whenever a patch-level release is released, i.e. ruby-2.1 will include the latest stable release of ruby `2.1.*`, ruby-2.0 will include the latest stable release of ruby `2.0.0-p*`, and ruby-1.9 will include the latest stable release of ruby `1.9.3-p*`.

## Maintainers

* Cyril Rohr <support@packager.io>
