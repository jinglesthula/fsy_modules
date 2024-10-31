# TamperMonkey Locally Hosted Scripts

Scripts stored in the plugin will die if the plugin is removed.  And you have to use the built-in editor.

To use VS Code or other editor of choice and keep your scripts safely in git, do this:

- In the TM extension, add a script for each of the files in this directory you wish to use
- In the script in TM, replace the content entirely with what's *between* the C-style comments at the bottom of the script file in this directory
- Save the TM script in the extension

Now enable File URL access (or it WON'T WORK)

- Visit [brave://extensions](brave://extensions) (or [chrome://extensions](chrome://extensions) or what have you)
- Click the Details button for the TM extension
- Enable the `Allow access to file URLs` setting

Should work now if you refresh your page the script targets.
