# This file is used to provide internationalization
# support to .plugin files. This is not the most
# elegant solution to do that and I know it.
# If you find a better way to do that, just let me know!
# Mario Guerriero <mario@elementaryos.org>

import locale
import polib
import os

class Translation:
    def __init__ (self, plugin_path):
        self.get_po_file ()
        self.plugin_file = plugin_path
    
    def get_po_file (self):
        # Get some possible language name files
        # EXAMPLE: it_IT.po, it.po or IT.po 
        lang = locale.getdefaultlocale ()[0] + ".po"
        lang1 = lang.split ("_")[0] + ".po"
        lang2 = lang.split ("_")[1] + ".po"

        # Load the file with translations
        for f in os.listdir ("po"):
            pofile = os.path.join (os.getcwd (), "po", f)
            
            basename = os.path.basename (pofile)
            if basename == lang or basename == lang1 or basename == lang2:
                self.pofile = polib.pofile (pofile)
    
    def translate (self):
        f = file (self.plugin_file, 'r')
        # Translate the content
        content = []
        for line in f.readlines ():
            if line[0] == '_':
                text = line.split ("=")[-1]
                for entry in self.pofile:
                    if entry.msgid == text.replace ("\n", ""):
                        line = line.replace ("_", "").replace (entry.msgid, entry.msgstr)
            if line != None:
                text = line.replace ("_", "")
                content.append (text)
        # Write the new content in the file
        nf = file (self.plugin_file.replace (".in", ""), "w")
        for line in content:
            nf.write (line)

# Get .plugin file
def get_plugin_file (parent_path):
    if os.path.isdir (parent_path):
        for f in os.listdir (parent_path):
            plugin_file = os.path.join (parent_path, f)
            if os.path.splitext (f)[1] == ".in":
                return os.path.join (parent_path, f)
        return None

# Parse all .plugin file
path = os.path.join (os.getcwd (), "plugins")

for f in os.listdir (path):
    plugin_file_path = get_plugin_file (os.path.join (path, f))
    if plugin_file_path != None:
        t = Translation (plugin_file_path)
        t.translate ()