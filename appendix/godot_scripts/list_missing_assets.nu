#!/usr/bin/env nu

# Check for missing assets in the project

def check_file [
    file: string
] {
    # echo $"file: ($file)"

    # check if the file exists
    let original_file = $file | parse "{path}.import" | get path
     
    if not ($original_file | path exists | first) {
        echo $original_file | path expand
    }
     
}

def check_list [
    file: string
] {
    # echo $"list: ($list)"
    let orig_path = pwd
    let list_parent_dir = echo $file | path expand |  path dirname
    cd $list_parent_dir

    let list = cat $file | lines

    let missing_files = $list | each { |e|
        if not ($e | path exists) {
            echo $e | path expand
        }
    }
    cd $orig_path

    $missing_files
}

def check_dir [
    dir: directory
    --base_dir: directory
] {
    # using fd

    mut result = fd ".import" $dir | lines | each { |e|
        check_file $e
    }

    $result ++= (fd -u "list.txt" $dir | lines | each { |e|
        check_list $e
    })
    
    echo $result | each { |e|
        $e | path relative-to $base_dir
    } | flatten | uniq
}

# Check for missing assets in the project
# (for example, if .png.import file only exists but .png file is missing, it will be reported)
def main [
    --project_dir (-d): directory # if not given, it will use the parent directory of the current directory
] {
    # check recursively for all files in the project directory

    if ($project_dir | is-empty) {
        # set project_dir to parent of the current directory
        # $env.FILE_PWD
         
        let current_dir = $env.FILE_PWD
        let project_dir = [$current_dir ".."] | path join | path expand
        # echo $"project_dir: ($project_dir)"
        check_dir $project_dir --base_dir $project_dir
    } else {
        check_dir $project_dir --base_dir $project_dir
    }
}