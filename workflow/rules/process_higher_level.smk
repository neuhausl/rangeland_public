configfile: "config/config.yaml"
# relative path where the snakemake command is executed (always start from rangeland-main/) 

container:
    config["force"]

PREPROCESS  =   config["preprocess"]
MERGED      =   config["merged"]
PARAMS      =   config["params"]
CUBE        =   config["datacube"]
HLPS_SCRIPT =   config["hlps_script"]
HIGHERLVL   =   config["higher_level"]
TILES       =   config["tile_range"]


# input function to connect output of another rule  
def get_merge_list(wildcards):
    # get checkpoint ouptput of generate_merge_list
    checkpoint_output = checkpoints.generate_merge_list.get().output.files_to_merge  # .output[0]
    unique_files_to_merge = []

    f = open(checkpoint_output, "r")
    merge_strings = f.readlines()

    for line in merge_strings:
        # convert string back to tuple
        # remove parentheses and split by comma
        tuple_str = line.strip('(').strip(')').strip("')\n")  
        tuple_list = [elem.strip("'") for elem in tuple_str.split(', ')]
        new_tuple = tuple(tuple_list)
        unique_files_to_merge.append(new_tuple)

    dirs=([i[0] for i in unique_files_to_merge])
    tile=([i[1] for i in unique_files_to_merge])
    file=([i[2] for i in unique_files_to_merge])

    merged_files = expand(MERGED + "{dirs}/{tile}/{file}", zip, dirs=dirs, tile=tile, file=file)

    return merged_files


# higher level (TSA) parameter file
checkpoint higher_lvl_parameters:
    input:
        merged_files       = get_merge_list,
        files_to_merge     = PARAMS + "files_to_merge.txt",
        allowed_tiles      = PREP + "allowed_tiles.txt",
        hlps_params_script = HLPS_SCRIPT,
        # needs to run after the merge step

    output:
        trend_param_file = PARAMS + "hlps.prm",
        prov_files       = directory(HIGHERLVL + "prov/"),
        merged_ard       = directory(HIGHERLVL + "ard/"),

    params:
        resolution     = config["resolution"],
        sensors_level2 = config["sensors_level2"],
        start_date     = config["start_date"],
        end_date       = config["end_date"],

    shell:
        """
        echo "START: Generate Parameterfile(s) for Higher Level Processing"
        
        mkdir -p {output.prov_files}
        mkdir -p {output.merged_ard}

        # move all files from preprocess and merged_preprocess
        # merged dir might not exist, if there weren't any duplicate files
        if test -d {MERGED}; then
            merged_ard=$(find {MERGED} -name '*.tif')
            for file in $merged_ard; do
                base=$(basename "$file")
                parent_dir=$(dirname "$file")
                tile=$(basename "$parent_dir")
                
                mkdir -p {output.merged_ard}/${{tile}}
                # cp $file {output.merged_ard}/${{tile}}/${{base}}
                mv $file {output.merged_ard}/${{tile}}/${{base}}
            done;    
        fi;
        
        ard=$(find {PREPROCESS} -name '*.tif')
        for file in $ard; do    
            base=$(basename "$file")
            parent_dir=$(dirname "$file")
            tile=$(basename "$parent_dir")

            mkdir -p {output.merged_ard}/${{tile}}
            # cp $file {output.merged_ard}/${{tile}}/${{base}}
            mv $file {output.merged_ard}/${{tile}}/${{base}}
        done;

        # create parameter file
        force-parameter -c {output.trend_param_file} TSA

        # execute permission to shell script
        chmod +x {input.hlps_params_script}

        # update parameterfile
        {input.hlps_params_script} {output.trend_param_file} {input.allowed_tiles} 
	
	    # input will be changed later with wildcards for parallel processing 	
	    sed -i "/^DIR_LOWER /cDIR_LOWER = {output.merged_ard}" {output.trend_param_file}

        # provenance
        sed -i "/^DIR_PROVENANCE /cDIR_PROVENANCE = {output.prov_files}" {output.trend_param_file}

        # resolution
        sed -i "/^RESOLUTION /c\\RESOLUTION = {params.resolution}" {output.trend_param_file}

        # sensors
        sed -i "/^SENSORS /c\\SENSORS = {params.sensors_level2}" {output.trend_param_file}

        # date range
        sed -i "/^DATE_RANGE /c\\DATE_RANGE = {params.start_date} {params.end_date}" {output.trend_param_file}

        # tile range
        # X1={TILES[0]}
        # X2={TILES[1]}
        # Y1={TILES[2]}
        # Y2={TILES[3]}
        # sed -i "/^X_TILE_RANGE /c\\X_TILE_RANGE = $X1 $X2" {output.trend_param_file}
        # sed -i "/^Y_TILE_RANGE /c\\Y_TILE_RANGE = $Y1 $Y2" {output.trend_param_file}
        """

# higher level processing
rule higher_lvl_processing:
    input:
        datacube         = CUBE,
        trend_param_file = PARAMS + "hlps.prm",
        merged_ard       = HIGHERLVL + "ard/",
        prov_files       = HIGHERLVL + "prov/",
        tiled_merged_ard = HIGHERLVL + "ard/{tile}",

    output:
        higher_lvl = directory(HIGHERLVL + "trend/{tile}"),
        # Snakemake might not know how many tiles are there yet

    shell:
        """
        # create output dir
        mkdir -p {output.higher_lvl} 

        # copy datacube must be in the input directory
        cp {input.datacube} {input.tiled_merged_ard}

        # mv files in a subdirectory because FORCE is stupid
        mkdir -p {input.tiled_merged_ard}/{wildcards.tile}
        tiled_files=$(find {input.tiled_merged_ard} -type f -name "*.tif") 
        for file in $tiled_files; do
            # check if file and dest are the same
            # this can happen on reruns, file exists in dest dir
            file_name=$(basename "$file")
            if [ "$file" = "{input.tiled_merged_ard}/{wildcards.tile}/$file_name" ]; then
                echo "file: {input.tiled_merged_ard}/{wildcards.tile}/$file_name exists, skipping!"
            else
                mv $file "{input.tiled_merged_ard}/{wildcards.tile}"
            fi
        done;

        # create param_file for every tile_ID dir
        cp {input.trend_param_file} "{PARAMS}/{wildcards.tile}_hlps.prm"

        # input 
        # needs to be changed here with wildcards for parallel processing, otherwise input wildcards might not exist before this rule
        sed -i "/^DIR_LOWER /c\\DIR_LOWER = {input.tiled_merged_ard}" {PARAMS}/{wildcards.tile}_hlps.prm

        # output
        # needs to be set here, output directories are created in this rule
        sed -i "/^DIR_HIGHER /c\\DIR_HIGHER = {output.higher_lvl}" {PARAMS}/{wildcards.tile}_hlps.prm

        echo "START: Higher Level Processing"

        # higher level processing
        force-higher-level {PARAMS}/{wildcards.tile}_hlps.prm
        
        # rename files: <Tile>/<Filename> to <Tile>_<Filename>, 
        # otherwise we can not reextract the tile name later

        # find all .tif files in the 'higher_lvl' directory
        results=$(find {output.higher_lvl} -name '*.tif*')

        for path in $results; do
            # get tile name
            dir_name=$(basename $(dirname $path))

            # get file name
            file_name=$(basename $path)

            # new file name with tile as prefix
            new_name="${{dir_name}}_${{file_name}}"

            # new path with files in the same directory
            new_path="$(dirname $path)/$new_name"

            # Rename the file
            mv "$path" "$new_path"
        done;
        
        # for disk space reasons remove input files
        rm -r {input.tiled_merged_ard}
        """


