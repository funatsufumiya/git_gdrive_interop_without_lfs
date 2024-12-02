#!/usr/bin/env nu

# save asset hashes to a file, using generate_asset_hashes.nu
def main [] {
    let current_dir = $env.FILE_PWD
    let project_dir = [$current_dir ".."] | path join | path expand
    cd $project_dir
    nu scripts/generate_asset_hashes.nu | save assets/asset_hashes.csv -f
}