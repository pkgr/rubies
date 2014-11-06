# rubies

This repository hosts the source code that compiles up to date MRI Ruby versions, and releases them as DEB or RPM packages for a wide range of linux distributions.

This work is supported by [Packager.io](https://packager.io).

## Included Ruby versions

* MRI 2.1.4 (patchlevel 265, rubygems 2.2.2)
* MRI 2.0.0 (patchlevel 594, rubygems 2.0.14)
* MRI 1.9.3 (patchlevel 550, rubygems 1.8.23.2)

Note: MRI rubies include statically compiled versions of libffi (3.0.10), libyaml (0.1.6), and libjemalloc (3.6.0).

## Supported distributions

* Ubuntu 14.04 LTS x86_64
* Ubuntu 12.04 LTS x86_64
* Debian 7 x86_64
* CentOS 6 x86_64
* RedHat 6 x86_64

## How to install

Head over to <https://packager.io/gh/pkgr/rubies>, and select the instructions for your distribution.

For instance, on Ubuntu 14.04:

    wget -qO - https://deb.packager.io/key | sudo apt-key add -
    echo "deb https://deb.packager.io/gh/pkgr/rubies trusty master" | sudo tee /etc/apt/sources.list.d/rubies.list
    sudo apt-get update
    sudo apt-get install rubies

## Usage

The package installs files in `/opt/rubies`. Here is the content of that directory:

    $  ls /opt/rubies/
    1.9.3  2.0.0  2.1.4  log  node  vendor

Using one of those rubies (for instance 2.1.4) is as simple as:

    $ /opt/rubies/2.1.4/bin/ruby -v
    ruby 2.1.4p265 (2014-10-27 revision 48166) [x86_64-linux]

    $ /opt/rubies/2.1.4/bin/gem -v
    2.2.2

    $ /opt/rubies/2.1.4/bin/bundle -v
    Bundler version 1.6.3

Note: You probably want to add `/opt/rubies/2.1.4/bin` to your `$PATH` environment variable for convenience.

## Extras

A version of `node` is also shipped with the package, in `/opt/rubies/node/bin`. This is an old version (0.6.8), but could be useful if you just want to precompile assets and don't need a more recent version.

## Maintainers

* Cyril Rohr <support@packager.io>
