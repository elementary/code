blacklisted_modules = ['strip-trailing-save']
blacklist_name = 'blacklist'

# Create a dummy module and overwrite existing listed module for each in blacklisted array
foreach module_name : blacklisted_modules
    shared_module(
        module_name,
        install: true,
        install_dir: join_paths(pluginsdir, module_name),
    )

    custom_target(module_name + '.plugin_merge',
        input: blacklist_name + '.plugin',
        output: module_name + '.plugin',
        command : [msgfmt,
                   '--desktop',
                   '--keyword=Description',
                   '--keyword=Name',
                   '-d' + join_paths(meson.source_root (), 'po', 'plugins'),
                   '--template=@INPUT@',
                   '-o@OUTPUT@',
                   ],
        install : true,
        install_dir: join_paths(pluginsdir, module_name),
    )
endforeach
