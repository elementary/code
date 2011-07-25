#!/bin/bash
cd src
valac --vapidir=. --pkg granite --pkg gtk+-3.0 --pkg gtksourceview-3.0 *.vala -o scratch && ./scratch
