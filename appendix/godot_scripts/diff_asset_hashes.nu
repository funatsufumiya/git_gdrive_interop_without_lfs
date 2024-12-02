#!/usr/bin/env nu

# diff a list of asset files and their hashes
def main [
    csv = "assets/asset_hashes.csv" # csv file with the asset hashes
] {
    if ( which rgh | is-empty ) {
        print -e "rgh is not installed. Please install it first (`cargo install rustgenhash`)"
        exit 1
    }

    let current_dir = $env.FILE_PWD
    let project_dir = [$current_dir ".."] | path join | path expand
    cd $project_dir

    let old_hash_table = cat $csv | from csv | sort-by name | rename name old_hash
    let new_hash_table = nu scripts/generate_asset_hashes.nu | from csv | sort-by name | rename name new_hash
    $new_hash_table | join --outer $old_hash_table name
        | where { |row| $row.old_hash != $row.new_hash }
}
