#!/usr/bin/env nu

use std log

# Configuration
let version = "0.0.1"
let command_name = "large-file-checker"
let hash_algorithm = "blake3"
let ids = ["assets" "common"]
let ignore_files = ["list.txt" "hash.txt" ".gitignore" ".gitkeep" ".DS_Store"]
let ids_with_all = ($ids | append "all")
let treat_empty_as_all = false
let do_ask_for_all_update = true
# NOTE: only for help message. Please also change get_large_file_dir function
let dir_pattern_for_help = "bin/data/**/from_gdrive"

def get_large_file_dir [id: string] {
    if $id == "all" {
        error make {msg: "[Error] id 'all' should not be used here"}
    }
    $"bin/data/($id)/from_gdrive"
}

# Helper functions

def get_hash [file: path] {
    rgh file $file --algorithm $hash_algorithm | split row " " | get 0
}

def is_ignored_file [file: string] {
    # $ignore_files | any { |f| $f == $file }
    $ignore_files | any { |f| ($file | str contains $f) }
}

def id_with_all_str [] {
    $ids_with_all | str join ','
}

def is_one_of_ids_or_all [id: string] {
    if $treat_empty_as_all == true and ($id | is-empty) {
        true
    } else {
        $ids_with_all | any { |i| $i == $id }
    }
}

def is_id_all [id: string] {
    if $treat_empty_as_all == true and ($id | is-empty) {
        true
    } else {
        $id == "all"
    }
}

let all_update_confirmed_tmp_file = mktemp -t "large-file-checker-all-update-confirmed.XXXXXXX"

def is_all_update_confirmed [] {
    if not ($all_update_confirmed_tmp_file | path exists) {
        touch $all_update_confirmed_tmp_file
    } 

    if (cat $all_update_confirmed_tmp_file | is-empty) {
        false
    } else {
        true
    }
}

def set_is_all_update_confirmed [confirmed: bool] {
    if $confirmed {
        echo "true" > $all_update_confirmed_tmp_file
    } else {
        rm $all_update_confirmed_tmp_file
    }
}

def ask_for_all_update [id: string] {
    if (is_id_all $id) {
        if $do_ask_for_all_update == true and (is_all_update_confirmed) == false {
            print "Do you want to update all ids (folders)?"
            print "This may break the current list and hash files."
            print "(Yes/no)"
            let answer = (input)
            if ($answer | str trim) == "Yes" {
                set_is_all_update_confirmed true
            } else {
                print "Update cancelled"
                exit 1
            }
        }
    }
}

def check_id_or_exit [id: string] {
    if not (is_one_of_ids_or_all $id) {
        let ids_with_all_s = (id_with_all_str)
        if $treat_empty_as_all == true {
            error make {
                msg: $"[Error] Invalid id '($id)'\n    Valid ids: ($ids_with_all_s)\n    \(If not specified, all ids will be checked/updated)"
            }
        } else {
            error make {
                msg: $"[Error] Invalid id '($id)'\n    Valid ids: ($ids_with_all_s)"
            }
        }
        exit 1
    }
}

def rustgenhash_installed_or_exit [] {
    if (which rgh | is-empty) {
        error make {
            msg: "[Error] rgh (rustgenhash) command not be found\n    Please install it by running 'cargo install rustgenhash'\n    (or download prebuilt binary from\n        https://github.com/vschwaberow/rustgenhash/releases )"
        }
    }
}

# def path_relative_to_lf_dir [path: string, id: string] {
#     let lf_dir = (get_large_file_dir $id)
#     print "lf_dir: " $lf_dir
#     print "path: " $path
#     let rel_path = ($path | path relative-to $lf_dir)
#     print $"rel_path: ($rel_path)"
#     if ($rel_path | is-empty) {
#         $path
#     } else {
#         $rel_path
#     }
# }

# Main functions
def update_list_impl [id: string] {
    ask_for_all_update $id

    let lf_dir = (get_large_file_dir $id)
    let list_file = $"($lf_dir)/list.txt"

    let current_dir = (pwd)
    cd $lf_dir
    
    # Get all files recursively, filter ignored files, and sort
    let files = ls **/*
    | where type == "file" 
    | get name 
    | where { |path| not (is_ignored_file ($path | path basename)) }
    | sort

    cd $current_dir
    
    # Save the list
    $files | save -f $list_file
    
    print $"update ($id) list: Updated ($list_file)"
}

def update_hash_impl [id: string] {
    ask_for_all_update $id

    let lf_dir = (get_large_file_dir $id)
    let list_file = $"($lf_dir)/list.txt"
    let hash_file = $"($lf_dir)/hash.txt"
    
    # First update the list
    update_list_impl $id
    
    # Read list and generate hashes
    open $list_file
    | lines
    | each { |line|
        let file = $"($lf_dir)/($line)"
        let hash = (get_hash $file)
        $"($line) --- ($hash)"
    }
    | save -f $hash_file
    
    print $"update ($id) hash: Updated ($hash_file)"
}

def check_list_impl [id: string] {
    let lf_dir = (get_large_file_dir $id)
    let list_file = $"($lf_dir)/list.txt"
    
    if not ($list_file | path exists) {
        error make {msg: $"check ($id) list: [Error] ($list_file) not found"}
        return
    }
    
    let missing = (open $list_file 
    | lines 
    | each { |line|
        let file = $"($lf_dir)/($line)"
        if not ($file | path exists) {
            $line
        }
    }
    | compact)
    
    if ($missing | length) == 0 {
        print $"check ($id) list: ALL OK"
    } else {
        $missing | each { |file| print $"check ($id) list: ($file) not found" }
    }
}

def check_hash_impl [id: string] {
    let lf_dir = (get_large_file_dir $id)
    let hash_file = $"($lf_dir)/hash.txt"
    
    if not ($hash_file | path exists) {
        error make {msg: $"check ($id) hash: [Error] ($hash_file) not found"}
        return
    }
    
    let has_errors = (open $hash_file
    | lines
    | each { |line|
        let parts = ($line | split row " --- ")
        let file = $parts.0
        let expected_hash = $parts.1
        let file_path = $"($lf_dir)/($file)"
        
        if not ($file_path | path exists) {
            print $"check ($id) hash: '($file)' not found"
            true
        } else {
            let current_hash = (get_hash $file_path)
            if $current_hash != $expected_hash {
                print $"check ($id) hash: '($file)' hash mismatch"
                true
            } else {
                false
            }
        }
    }
    | any { |error| $error })
    
    if not $has_errors {
        print $"check ($id) hash: ALL OK"
    }
}

def iterate_all_or_once [func: closure, id: string] {
    if (is_id_all $id) {
        $ids | each { |i| do $func $i }
    } else {
        do $func $id
    }
}

# Command handlers
def update_list [id: string] {
    rustgenhash_installed_or_exit
    check_id_or_exit $id
    iterate_all_or_once {|i| update_list_impl $i} $id
    exit 0
}

def update_hash [id: string] {
    rustgenhash_installed_or_exit
    check_id_or_exit $id
    iterate_all_or_once {|i| update_hash_impl $i} $id
    exit 0
}

def check_list [id: string] {
    rustgenhash_installed_or_exit
    check_id_or_exit $id
    iterate_all_or_once {|i| check_list_impl $i} $id
    exit 0
}

def check_hash [id: string] {
    rustgenhash_installed_or_exit
    check_id_or_exit $id
    iterate_all_or_once {|i| check_hash_impl $i} $id
    exit 0
}

def check [id: string] {
    rustgenhash_installed_or_exit
    check_id_or_exit $id
    iterate_all_or_once {|i| 
        check_list_impl $i
        check_hash_impl $i
    } $id
    exit 0
}

def update_ [id: string] {
    rustgenhash_installed_or_exit
    check_id_or_exit $id
    ask_for_all_update $id
    iterate_all_or_once {|i| update_hash_impl $i} $id
    exit 0
}

def get_hash_of_file [file: string] {
    rustgenhash_installed_or_exit
    print (get_hash $file)
}

# Help and version commands
def print_help [] {
    print $"\nDescription:\n   ($command_name): Check and update list and hash for files in ($dir_pattern_for_help)\n"
    print $"Usage:\n   ($command_name) -h | --help\n        Print this help message"
    print $"   ($command_name) -v | --version\n        Print version\n"
    print $"   ($command_name) update [id]\n        Update both list and hash"
    print $"   ($command_name) check [id]\n        Check both list and hash\n"
    print $"   ($command_name) update list [id]\n        Update list.txt"
    print $"   ($command_name) update hash [id]\n        Update hash.txt"
    print $"   ($command_name) check list [id]\n        Check list.txt"
    print $"   ($command_name) check hash [id]\n        Check hash.txt\n"
    print $"   ($command_name) get_hash [file]\n        Print hash of a file\n"
    print $"   [id]: ($ids_with_all | str join ',')\n"
    if $treat_empty_as_all == true {
        print "        (If not specified, all ids will be checked/updated)"
    }
}

def print_version [] {
    print $"($command_name) ($version)"
}

# # Main command handler
# export def large-file-checker [
#     --version (-v) # Print version
# ] {
#     if $version {
#         print_version
#     } else {
#         help large-file-checker
#     }
# }

export def --wrapped large-file-checker [...args] {
    # if any args have -h or --help, print help
    if ($args | any { |arg| $arg == "-h" or $arg == "--help" }) {
        print_help
        exit 0
    }

    # Parse arguments
    match $args {
        [] | ['-h'] | ['--help'] => { print_help }
        ['-v'] | ['--version'] => { print_version }
        ['update' 'list' $id] => { update_list $id }
        ['update' 'hash' $id] => { update_hash $id }
        ['update' $id] => { update_hash $id }
        ['check' 'list' $id] => { check_list $id }
        ['check' 'hash' $id] => { check_hash $id }
        ['check' $id] => { check $id }
        ['get_hash' $file] => { get_hash_of_file $file }
        _ => {
            print "[Error] Invalid arguments"
            print_help
            exit 1
        }
    }
}

# # below functions are only exist for showing help message in the nu shell

# # check
# export def 'large-file-checker check' [
#     id: string
# ] {
#     # help check
#     print_help
# }

# # update
# export def 'large-file-checker update' [
#     id: string
# ] {
#     help 'large-file-checker update'
# }

# # check list
# export def 'large-file-checker check list' [
#     id: string
# ] {
#     help 'large-file-checker check list'
# }

# # check hash
# export def 'large-file-checker check hash' [
#     id: string
# ] {
#     help 'large-file-checker check hash'
# }

# # update list
# export def 'large-file-checker update list' [
#     id: string
# ] {
#     help 'large-file-checker update list'
# }

# # update hash
# export def 'large-file-checker update hash' [
#     id: string
# ] {
#     help 'large-file-checker update hash'
# }

# alias main = large-file-checker
# alias 'main check' = check
# alias 'main update' = update_
# alias 'main check list' = check_list
# alias 'main check hash' = check_hash
# alias 'main update list' = update_list
# alias 'main update hash' = update_hash

alias main = large-file-checker