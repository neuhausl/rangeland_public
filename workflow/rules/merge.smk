configfile: "config/config.yaml"
# checks from dir where it is started from (always start from rangeland-main/) 

DATA        =   config["data"]
PREPROCESS  =   config["preprocess"]
MERGED      =   config["merged"]
PARAMS      =   config["params"]
SCRIPT      =   config["scripts"]
HIGHERLVL   =   config["higher_level"]


# get subdirectories to use as wildcards
def get_all_subdirectories(root_dir, parent_dirs = None): # "= None" makes the argument optional
    if parent_dirs is None:
        parent_dirs = []
    # nothing gets cut if no parent directories are given

    subdirectories = []
    for root, dirs, _ in os.walk(root_dir):
        for subdir in dirs:
            subdirectories.append(os.path.join(root, subdir))
    
    # cuts the root from the path
    subdirs = [sub.replace(root_dir, "") for sub in subdirectories]

    # removes parent dirs if given
    subdirs_wo_parents = [item for item in subdirs if item not in parent_dirs] 
    return subdirs_wo_parents


checkpoint generate_merge_list:
    input:
        preprocess = expand(PREPROCESS + "{img_dirs}", img_dirs = get_all_subdirectories(DATA, os.listdir(DATA))),

    output:
        files_to_merge = PARAMS + "files_to_merge.txt",

    run:
        def split_path(directory, extension='.tif'):
            result = []
            
            # Walk through the directory and subdirectories
            for root, dirs, files in os.walk(directory):
                for file in files:
                    if file.endswith(extension):
                        # Get the basename, parent directory, and rest of the path
                        basename = os.path.basename(file)
                        parent_dir = os.path.basename(root)
                        rest_of_path = os.path.relpath(root, directory)
                        rest = rest_of_path.replace("/" + parent_dir, "")  # remove double '/'

                        # Append the tuple to the result list
                        result.append((rest, parent_dir, basename))

            return result


        def find_matching_files(tuple_list):
            seen = {}
            matches = []

            # store entry based on (parent_dir, filename) as "key"
            for rest_of_path, parent_dir, filename in tuple_list:
                key = (parent_dir, filename)
                if key in seen:
                    # If key already seen, add both current and previously seen entries
                    if seen[key] is not None:
                        matches.append(seen[key])
                        seen[key] = None  # mark to avoid duplicates
                    matches.append((rest_of_path, parent_dir, filename))
                else:
                    seen[key] = (rest_of_path, parent_dir, filename)

            return matches


        def filter_unique_files(matching_tuples):
            seen = set()
            unique_files = []

            for rest_of_path, parent_dir, filename in matching_tuples:
                key = (parent_dir, filename)
                if key not in seen:
                    seen.add(key)
                    unique_files.append((rest_of_path, parent_dir, filename))

            return unique_files


        unique_files_to_merge=filter_unique_files(find_matching_files(split_path(PREPROCESS)))

        with open(f"{output}", 'w') as f:
            for line in unique_files_to_merge:
                f.write(f"{line}\n")
        f.close()


rule merge_files:
    input:
        files_to_merge  = PARAMS + "files_to_merge.txt",
        lvl2_file       = PREPROCESS + "{dirs}/{tile}/{file}",
        merge_boa       = SCRIPT + "merge_boa.r",
        merge_qai       = SCRIPT + "merge_qai.r",

    output:
        merged_file     = MERGED + "{dirs}/{tile}/{file}",

    container:
        config["force"]

    shell:
        """
        mkdir -p {MERGED}

        files_to_merge=$(find -L {PREPROCESS} -type f -path "*/{wildcards.tile}/{wildcards.file}")

        # Check if there are at least two matching files
        matching_files_amount=$(echo $files_to_merge | wc -w)
        if [ "$matching_files_amount" -lt 2 ]; then
            echo "Skipping {input.lvl2_file}, minimum of 2 files to start merging"

        else
            # check filename and merge boa or qai files:
            if [[ "{input.lvl2_file}" =~ "BOA" ]]; then     # '=~' for matching substring
                
                chmod +x {input.merge_boa}
                
                echo "merging {input.lvl2_file} with $files_to_merge"
                {input.merge_boa} {output.merged_file} ${{files_to_merge}}
                

            elif [[ "{input.lvl2_file}" =~ "QAI" ]]; then   # '=~' for matching substring
                
                chmod +x {input.merge_qai}
                
                echo "merging {input.lvl2_file} with $files_to_merge"
                {input.merge_boa} {output.merged_file} ${{files_to_merge}}
            fi
            
            # copy meta information to new file
            force-mdcp {input.lvl2_file} {output.merged_file}
            
            # remove merged files
            rm -f {input.lvl2_file}
            for file in $files_to_merge; do
                rm -f $file
            done;
            # mv {output.merged_file} {input.lvl2_file}
        fi
        """