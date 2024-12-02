#!/usr/bin/env nu

# Find unused assets in the project
def main [] {
    use std log

    let current_dir = $env.FILE_PWD
    let project_dir = [$current_dir ".."] | path join | path expand
    cd $project_dir
    let filelist_raw = fd -u -t f -g "*" assets
        | rg -v "list.txt"
        | rg -v "list_ignore_from_unused.txt"
        | rg -v "asset_hashes.csv"
        | rg -v ".import"
        | rg -v ".DS_Store"
        | rg -v ".translation"
        | rg -v ".gitkeep" | rg -v ".gdignore" | rg -v ".gitignore"

    let files = $filelist_raw | lines | str replace --all '\' '/' | sort

    mut res = $files | each { |e|
        # log info $"file: ($e)"
        let rg_result_raw =  $"(rg $'($e)' -g '*.{gd,tscn,godot,md}')"
        # log info $"rg_result_raw: ($rg_result_raw)"
        # log info $"file: ($e), rg_result_raw: ($rg_result_raw)"
        let used_count = $rg_result_raw | lines | length
        # log info $"used_count: ($used_count)"
        if ($used_count == 0) {
            echo $e
        }
    }

    # remove ignored files, using rg
    let res = $res | where { |e|
        (rg $'($e)' "assets/list_ignore_from_unused.txt" | lines | length) == 0
    }

    $res
}