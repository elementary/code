# Scratch
[![Translation status](https://l10n.elementary.io/widgets/scratch/-/svg-badge.svg)](https://l10n.elementary.io/projects/scratch/?utm_source=widget)

## Building, Testing, and Installation

You'll need the following dependencies:
* cmake
* libgtksourceview-3.0-dev
* libgranite
* libzeitgeist-2.0
* valac

It's recommended to create a clean build environment

    mkdir build
    cd build/
    
Run `cmake` to configure the build environment and then `make` to build

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make
    
To install, use `make install`, then execute with `scratch-text-editor`

    sudo make install
    scratch-text-editor
