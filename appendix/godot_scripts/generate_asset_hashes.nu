# Generate a list of asset files and their hashes
def main [] {
    if ( which rgh | is-empty ) {
        print -e "rgh is not installed. Please install it first (`cargo install rustgenhash`)"
        exit 1
    }

    # let hash_algorithm = "tiger"
    let hash_algorithm = "blake3"
    let current_dir = $env.FILE_PWD
    let project_dir = [$current_dir ".."] | path join | path expand
    cd $project_dir
    let filelist_raw = fd -u -t f -g "*" assets
        | rg -v "list.txt"
        | rg -v "list_ignore_from_unused.txt"
        | rg -v "asset_hashes.csv"
        | rg -v ".translation"
        | rg -v ".import"
        | rg -v ".zip"
        | rg -v ".DS_Store"
        | rg -v ".gitkeep" | rg -v ".gdignore" | rg -v ".gitignore"
    # let filelist = $filelist_raw | lines | split column " " | rename name
    let hashes = $filelist_raw | lines | par-each { |e|
        # let hash = (open $e | hash sha256)
        let hash = rgh file $e --algorithm $hash_algorithm | lines | split column " " | rename hash name | get hash | to text
        let name = $e | str replace --all '\' '/'
        [$name, $hash] | str join ","
    } | split column "," | str trim | rename name hash | select name hash | sort-by name
        # | where {|e| not ($e | get name | str contains "\\")}
    $hashes | to csv
}