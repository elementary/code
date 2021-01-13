# Code
[![Translation status](https://l10n.elementary.io/widgets/code/-/svg-badge.svg)](https://l10n.elementary.io/projects/code/?utm_source=widget)

![Screenshot](data/screenshot.png?raw=true)

## Building, Testing, and Installation

```sh
# add repositories
sudo apt-add-repository "deb http://ftp.de.debian.org/debian sid main"
sudo apt-add-repository "deb http://ftp.de.debian.org/debian stretch main"
# read source lists (WARNING! THESE REPOS ARE NOT SIGNED)
sudo apt update --allow-insecure-repositories
# install the dependencies
sudo apt install -y \
    meson\
    libeditorconfig-dev\
    libgail-3-dev\
    libgee-0.8-dev\
    libgit2-glib-1.0-dev\
    libgtksourceview-4-dev\
    libgtkspell3-3-dev\
    libgranite-dev\
    libpeas-dev\
    libhandy-1-dev\
    libvala-0.48-dev\
    libsoup2.4-dev\
    libvte-2.91-dev\
    libzeitgeist-2.0-dev\
    valac\
```

Run `meson build` to configure the build environment. Change to the build directory and run `ninja test` to build

    meson build --prefix=/usr
    cd build
    ninja test

To install, use `ninja install`, then execute with `io.elementary.code`

    sudo ninja install
    io.elementary.code
