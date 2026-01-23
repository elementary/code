# Markdown Preview Plugin

Add a plugin to Elementary Code that allows users to preview rendered markdown in a side-by-side view alongside the editor.

## User Review Required

> [!IMPORTANT]
> **Rendering Approach**: This plugin will use WebKit (webkit2gtk-4.0) to render the markdown as HTML. The preview will appear in a separate pane that can be toggled on/off. The markdown will be converted to HTML and styled with GitHub-flavored markdown CSS for a clean, familiar appearance.

> [!IMPORTANT]
> **UI Integration**: The preview will be accessible via:
> - A toolbar button that appears when editing markdown files
> - A keyboard shortcut (Ctrl+Shift+M)
> - The preview pane will appear to the right of the editor in a split view

## Proposed Changes

### Markdown Preview Plugin

A new plugin that provides live markdown rendering capabilities for markdown files.

#### [NEW] [markdown-preview.vala](file:///home/chuck/Dropbox/Programming/Languages_and_Code/Programming_Projects/Programming_Tools/elementary-code-altdistros/plugins/markdown-preview/markdown-preview.vala)

Main plugin implementation with:
- WebKit WebView for rendering HTML
- Markdown to HTML conversion using a simple parser
- Live preview updates as the user types (with debouncing)
- Split pane integration with the editor
- Toggle button in toolbar for showing/hiding preview
- Keyboard shortcut (Ctrl+Shift+M) support
- Auto-scroll synchronization between editor and preview
- GitHub-flavored markdown CSS styling

#### [NEW] [markdown-preview.plugin](file:///home/chuck/Dropbox/Programming/Languages_and_Code/Programming_Projects/Programming_Tools/elementary-code-altdistros/plugins/markdown-preview/markdown-preview.plugin)

Plugin metadata file describing the plugin name, description, and author information.

#### [NEW] [meson.build](file:///home/chuck/Dropbox/Programming/Languages_and_Code/Programming_Projects/Programming_Tools/elementary-code-altdistros/plugins/markdown-preview/meson.build)

Build configuration for the markdown-preview plugin, including webkit2gtk-4.0 dependency.

---

### Plugin Registration

#### [MODIFY] [meson.build](file:///home/chuck/Dropbox/Programming/Languages_and_Code/Programming_Projects/Programming_Tools/elementary-code-altdistros/plugins/meson.build)

Add `subdir('markdown-preview')` to register the new plugin in the build system.

## Verification Plan

### Automated Tests
- Build the project with `meson setup build --prefix=/usr && ninja -C build`
- Verify no compilation errors
- Check that the plugin is installed to the correct directory

### Manual Verification
- Launch Elementary Code
- Open a markdown file ([.md](file:///home/chuck/.gemini/antigravity/brain/b88974f6-b6d8-4497-a368-2ef66eb65ce1/task.md) extension)
- Verify the preview toggle button appears in the toolbar
- Click the button or press Ctrl+Shift+M to show the preview pane
- Verify markdown is rendered correctly with:
  - Headers (H1-H6)
  - Bold and italic text
  - Lists (ordered and unordered)
  - Code blocks with syntax highlighting
  - Links
  - Images
  - Blockquotes
  - Tables
- Edit the markdown and verify the preview updates in real-time
- Verify the preview can be toggled on/off
- Test with non-markdown files to ensure the button doesn't appear
