configfile: "config/config.yaml"
# checks from dir where it is started from (always start from rangeland-main/) 

DATA        =   config["data"]
PREPROCESS  =   config["preprocess"]
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


IMAGE_DIRS = get_all_subdirectories(DATA, os.listdir(DATA))



rule merge_boa:
    input: 
        lvl2 = expand(PREPROCESS + "{img_dirs}", img_dirs = IMAGE_DIRS),
        merge_boa = SCRIPT + "merge_boa.r",

    output:
        merged = directory(HIGHERLVL + "boa/"),

    container:
        config["force"]

    shell:
        """

        # find all preprocessed files to rename them
        # put Tile_ID in the name, this makes merging much easier
        ard_files=`find -L {input.lvl2} -type f -name '*_BOA.tif'`

        for file in $ard_files; do

            ard=$(basename "$file")
            parent_dir=$(dirname "$file")
            tile=$(basename "$parent_dir")

            combined="${{parent_dir}}/${{tile}}_${{ard}}"    

            mv $file $combined

        done;


        # take names of all .tif files, sort and only keep uniques
        files=$(find -L {input.lvl2} -type f -name '*_BOA.tif' -printf "%f\n" | sort | uniq)

        # count files, create counter
        file_amount=`echo $files | wc -w`
        current_file=0
        merged_files=0

        chmod +x {input.merge_boa}

        # loop over files
        for file in $files; do

            # increment
            current_file=$((current_file+1))

            # path of current file
            tmp_file=$(find {input.lvl2} -type f -name "$file" | head -1)
            tmp_par=$(dirname "$tmp_file")

            # find matches
            matching_files=$(find {input.lvl2} -type f -name "$file")

            # Check if there are at least two matching files
            matching_files_amount=`echo $matching_files | wc -w`
            if [ "$matching_files_amount" -lt 2 ]; then
                # echo "Skipping $file, minimum of 2 files to start merging"
                continue
            fi

            # check filename and merge boa files:
            {input.merge_boa} "${{tmp_par}}/merged_${{file}}" ${{matching_files}}
            echo "\n--> merging:\n${{matching_files}}\n"

            # apply meta info
            force-mdcp $tmp_file "${{tmp_par}}/merged_${{file}}"

            # remove original files that got merged:
            echo "remove original files:\n${{matching_files}}\n"
            merged_files=$((merged_files+1))
            
            echo "$merged_files\n"
            now=$(date)
            echo "$now\n"

            rm -f ${{matching_files}}
            echo "keep merged file:\n${{tmp_par}}/merged_${{file}}\n"

            mv "${{tmp_par}}/merged_${{file}}" "$tmp_file"

        done;

        # find all files to reverse renaming, remove Tile_ID from name
        # copy files to higher_level processing, they need to be in one dir per tile

        ard_files=$(find -L {input.lvl2} -type f -name '*_BOA.tif')

        for file in $ard_files; do

            ard=$(basename "$file")
            parent_dir=$(dirname "$file")
            tile_=$(basename "$parent_dir")
            tile=$(basename "$parent_dir")

            mkdir -p {output.merged}/$tile

            # remove Tile_ID from filename
            tile_+="_"   # remove trailing underscore 
            rm_tile=${{ard//${{tile_}}/}}

            cp $file {output.merged}/$tile/$rm_tile
            mv $file ${{parent_dir}}/${{rm_tile}}

            # if low on diskspace, remove the mv command and instead of cp, write mv   

        done;
        """


rule merge_qai:
    input: 
        lvl2 = expand(PREPROCESS + "{img_dirs}", img_dirs = IMAGE_DIRS),
        merge_qai = SCRIPT + "merge_qai.r",

    output:
        merged = directory(HIGHERLVL + "qai/"),

    container:
        config["force"]

    shell:
        """

        # find all preprocessed files to rename them
        # put Tile_ID in the name, this makes merging much easier
        ard_files=`find -L {input.lvl2} -type f -name '*_QAI.tif'`

        for file in $ard_files; do

            ard=$(basename "$file")
            parent_dir=$(dirname "$file")
            tile=$(basename "$parent_dir")

            combined="${{parent_dir}}/${{tile}}_${{ard}}"    

            mv $file $combined

        done;


        # take names of all .tif files, sort and only keep uniques
        files=$(find -L {input.lvl2} -type f -name '*_QAI.tif' -printf "%f\n" | sort | uniq)

        # count files, create counter
        file_amount=`echo $files | wc -w`
        current_file=0
        merged_files=0

        chmod +x {input.merge_qai}

        # loop over files
        for file in $files; do

            # increment
            current_file=$((current_file+1))

            # path of current file
            tmp_file=$(find {input.lvl2} -type f -name "$file" | head -1)
            tmp_par=$(dirname "$tmp_file")

            # find matches
            matching_files=$(find {input.lvl2} -type f -name "$file")

            # Check if there are at least two matching files
            matching_files_amount=`echo $matching_files | wc -w`
            if [ "$matching_files_amount" -lt 2 ]; then
                # echo "Skipping $file, minimum of 2 files to start merging"
                continue
            fi

            # check filename and merge qai files:
            {input.merge_qai} "${{tmp_par}}/merged_${{file}}" ${{matching_files}}
            echo "\n--> merging:\n${{matching_files}}\n"

            # apply meta info
            force-mdcp $tmp_file "${{tmp_par}}/merged_${{file}}"

            # remove original files that got merged:
            echo "remove original files:\n${{matching_files}}\n"
            merged_files=$((merged_files+1))
            
            echo "$merged_files\n"
            now=$(date)
            echo "$now\n"

            rm -f ${{matching_files}}
            echo "keep merged file:\n${{tmp_par}}/merged_${{file}}\n"

            mv "${{tmp_par}}/merged_${{file}}" "$tmp_file"

        done;

        # find all files to reverse renaming, remove Tile_ID from name
        # copy files to higher_level processing, they need to be in one dir per tile

        ard_files=$(find -L {input.lvl2} -type f -name '*_QAI.tif')

        for file in $ard_files; do

            ard=$(basename "$file")
            parent_dir=$(dirname "$file")
            tile_=$(basename "$parent_dir")
            tile=$(basename "$parent_dir")

            mkdir -p {output.merged}/$tile

            # remove Tile_ID from filename
            tile_+="_"   # remove trailing underscore 
            rm_tile=${{ard//${{tile_}}/}}

            cp $file {output.merged}/$tile/$rm_tile
            mv $file ${{parent_dir}}/${{rm_tile}}

            # if low on diskspace, remove the mv command and instead of cp, write mv   

        done;
        """