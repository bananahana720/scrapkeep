# Godot 4.7 command-line excerpt for TH-19 review R2

Retrieved by the coordinator with curl -sL at 2026-09-16T19:18:00Z from https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html (HTTP 200). Full HTML sha256 dbacfb7163f6b4a839bcd39fcc0cd203006769a04fd7b78976d9d73eda46ae56 and extracted text sha256 837c50d2c6976b8febd19cef92d708e40fd2df6031daf6cff78ed785ea881c93, kept under artifacts/local/tasks/TH-19/. Extracted text lines 9433-9434 and 9539-9556, verbatim:

```text
--headless
Enable headless mode ( --display-driver headless --audio-driver Dummy ). Useful for servers and with --script .
-s , --script <script>
Run a script. <script> must be a resource path relative to the project ( myscript.gd will be interpreted as res://my_script.gd )
or an absolute filesystem path (for example, on Windows: C:/tmp/my_script.gd ).
--main-loop <main_loop_name>
Run a MainLoop specified by its global class name.
--check-only
Only parse for errors and quit (use with --script ).
--import
Starts the editor, waits for any resources to be imported, and then quits. Implies --editor and --quit .
--export-release <preset> <path>
Export the project in release mode using the given preset and output path. The preset name should match one defined in "export_presets.cfg".
<path> should be absolute or relative to the project directory, and include the filename for the binary (e.g. "builds/game.exe"). The target
directory must exist.
--export-debug <preset> <path>
Like --export-release , but use debug template. Implies --import .
--export-pack <preset> <path>
Like --export-release , but only export the game pack for the given preset. The <path> extension determines whether it will be in PCK
or ZIP format. Implies --import .
```

Not stated on this page: whether a --script run imports resources, and whether an exported template honours --script.
