# Code
[![Translation status](https://l10n.elementary.io/widgets/scratch/-/svg-badge.svg)](https://l10n.elementary.io/projects/scratch/?utm_source=widget)

![Screenshot](data/screenshot.png?raw=true)

Code is the editor that works for you. It auto-saves your files, meaning they're always up-to-date. Plus it remembers your tabs so you never lose your spot, even in between sessions.

Code is written from the ground up to be extensible and closely follows our high standards of design, speed, and consistency. It's sexy, but not distracting.

Whether you're crafting code in Vala, scripting with PHP, or marking things up in HTML, Code has you covered. Experience full syntax highlighting with nearly all programming, scripting, and markup languages.


## Building, Testing, and Installation

You'll need the following dependencies:
* cmake
* libdevhelp-dev
* libgail-3-dev
* libgee-0.8-dev
* libgtksourceview-3.0-dev
* libgtkspell-3-dev
* libgranite-dev
* libpeas-dev
* libsoup2.4-dev
* libvala-0.34-dev
* libvte-2.91-dev
* libwebkit2gtk-4.0-dev
* libzeitgeist-2.0
* valac

It's recommended to create a clean build environment

    mkdir build
    cd build/

Run `cmake` to configure the build environment and then `make` to build

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make

To install, use `make install`, then execute with `io.elementary.code`

    sudo make install
    io.elementary.code
