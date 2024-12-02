# appendix/godot_scripts

This folder contains original (old) scripts when I was using for [Godot Engine](https://godotengine.org/) projects.

This is a similar concept to [large-file-checker](../../scripts/large-file-checker) script, but easpecially for Godot Engine projects. (Utilizing `*.import` files. If not `*.import` exists, you can define `list.txt` in any folder you want. But you should modify `list.txt` by hands, in this old version.)

## Usage

- Please create `scripts` folder on the top of your Godot project, and put *.nu files into `scripts` folder.
  - I also recommend to put `.gdignore` file in it to ignore `*.nu` files from Godot Editor. 
- `assets` folder is for storing assets to be checked as large files.
  - I was using `src` folder for storing code files, for git management. I also put into git management `.import` files in `assets` folder.

### Folder structure

```
- (project_root)
    - scripts
        - *.nu
        - .gdignore
    - src
        - *.gd
    - assets
        - *.png
        - *.png.import
        - some_folder
          - list.txt
          - *.mp4
        - (etc...)
```

NOTE: `some_folder` is just example, which has no `.import` files (especially controlled from addons. This is special case, not normal folder.)