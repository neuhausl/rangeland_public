import glob
configfile: "config/original_config.yaml"
# checks from dir where it is started from (alway start from rangeland-main/) 
# TODO: add kubernetes import for nodeselector
            
DATA                =       config["data"]
PREP                =       config["preparation"]
MASK                =       config["mask"]
PREPROCESS          =       config["preprocess"]
HIGHERLVL           =       config["higher_level"]
TREND               =       config["trend"]
PARAMS              =       config["params"]
SENSORLVL1          =       config["sensors_level1"]
STARTDATE           =       config["start_date"]
ENDDATE             =       config["end_date"]
IMAGE               =       config["force_ver"]
force_run           =       'docker run --rm -v $(pwd):/data -v $(pwd):/results -w /results --user "$(id -u):$(id -g)" ' + IMAGE
                            # --rm ensures that the container and it's filesystem is removed after completion

# to get all files in a directory as wildcards:
# set wildcards in input/output directive (need to be the same wildcards)
# resolve wildcards in following rule/all rule with expand("", wildcard=DATA)
# !!! no comments directly after in/output directive otherwise snakemake gets confused !!!

# all target rules here
rule all:
    input:
        "results/trend/mosaic/",
        "results/trend/pyramid/"
        # "results/higher_level/"
        # "results/param/trend.prm"


# Preparation
# Check if all data is present
rule preparation:
    input:
        datacube = "data/datacube-definition.prj",
        aoi = "data/aoi.gpkg",
        data = "data/landsat/",
        wvdb = "data/wvdb/",
        dem = "data/dem/",
        endmember = "data/endmember/",

    # create output directories
    output:
        directory("results/tmp/"),
        directory("results/log/")


    # make directories
    shell:
        """
        echo "PREPARATION: check data..."

        mkdir -p {output}
        """


# generate processing masks
rule generate_masks:
    input:
        tmp         = "results/tmp/",
        aoi         = "data/aoi.gpkg",
        datacube    = "data/datacube-definition.prj",
        # tmp as input, so this runs after the preparation rule
        # one output to link dependencies

    # mask for whole region
    output:
        mask = directory(PREP + "mask/"),
    
    params:
        resolution = config["resolution"],

    shell:
        """
        echo "START: generate masks"

        mkdir -p {output.mask}

        # needs to be inside output dir, aoi is in mounted data dir
        cp {input.datacube} {output.mask}
    
        {force_run} force-cube -o {output.mask} -s {params.resolution} {input.aoi}
        """
        # force-cube command changed due to different data format
        # datacube-definition.prj needs to be in -o output directory


# generate a tile allow-list
rule generate_allowed_tiles_list:
    input:
        tmp      = "results/tmp",
        aoi      = "data/aoi.gpkg",
        datacube = "data/datacube-definition.prj"
        # tmp as input, so this runs after the preparation rule
        # one output to link dependencies 

    # allowed tiles
    output:    
        allowed_tiles = PREP + "allowed_tiles.txt"

    params:
        prep = PREP

    shell:
        """
        echo "START: generate allowed_tiles-list"

        mkdir -p {params.prep}

        # needs to be inside output dir, aoi is in mounted data dir
        cp {input.datacube} {params.prep}

        {force_run} force-tile-extent {input.aoi} {params.prep} {output.allowed_tiles}
        """


# Level 2 parameter file
rule prepare_lvl2:
    input: 
        allowed_tiles = PREP + "allowed_tiles.txt",
        mask = PREP + "mask/",
        datacube = "data/datacube-definition.prj"
        # masks and allowed_tiles list outputs, so this rule runs after 

    output:
        lvl2_paramfile = PARAMS + "l2ps.prm"
    
    params:
        l2ps_params_script = "workflow/original_workflow/force-l2ps-params.sh"

    # changed due to changes in FORCE
    shell:
        """
        echo "START: Generate Parameterfile(s) for Level 2 Processing"

        # create parameter file
        {force_run} force-parameter -c {output.lvl2_paramfile} LEVEL2

        # execute permission to shell script
        chmod +x {params.l2ps_params_script}

        # update parameterfile 
        {params.l2ps_params_script} {output.lvl2_paramfile} {input.datacube}
        """


# preprocessing to Level 2 ARD
rule preprocess:
    input:
        paramfile = PARAMS + "l2ps.prm",
        image_dir = DATA + "181036/{image_dirs}"
        # TODO: adjust with glob
        # {sensor}_L1TP_{dirs}_{start_date}_{end_date}_02_T1/", 
        # dirs=DIRS18, sensor=SENSORLVL1, start_date=STARTDATE, end_date=ENDDATE)
        #
        # TODO: use {wildcards.image_dirs} to access the exact foldername of the images
        # TODO: use {wildcards.wildcard_name} to access exact wildcard values

    output:
        directory(PREPROCESS + "ard/181036/{image_dirs}"),
        # TODO: use glob

    shell:
        """
        echo "START: Preprocessing (Level 2 Processing)"

        # create output dir
        mkdir -p {output}
        # cp {input.paramfile} {output}
        # cd {output}
        

        {force_run} force-l2ps {input.image_dir} {input.paramfile}
        # l2ps.prm

        # cd ..

        # mkdir -p {output}
        """

# higher level (TSA) parameter file
# changed due to changes in FORCE 
rule higher_lvl_parameters:
    input:
        expand(PREPROCESS + "ard/181036/LT04_L1TP_181036_19880130_20200917_02_T1"),
        allowed_tiles = PREP + "allowed_tiles.txt"
        # needs to run after the preprocessing step
        # TODO: adjust for flattened filesystem
        
        # TODO: adjust for whole filesystem
        # expand("results/preprocess/ard/181036/{image_dirs}", image_dirs=os.listdir(DATA + "181036/")),
        # TODO: adjust for whole filesystem

    output:
        trend_param_file = PARAMS + "trend.prm"

    params:
        hlps_params_script = "workflow/original_workflow/force-hlps-params.sh"

    shell:
        """
        echo "START: Generate Parameterfile(s) for Higher Level Processing"

        # create parameter file
        {force_run} force-parameter -c {output.trend_param_file} TSA

        # execute permission to shell script
        chmod +x {params.hlps_params_script}

        # update parameterfile
        {params.hlps_params_script} {output.trend_param_file} {input.allowed_tiles} 
        """

# higher level processing
rule higher_lvl_processing:
    input:
        trend_param_file = PARAMS + "trend.prm"

    output:
        higher_lvl = directory(HIGHERLVL),
        # force might not know the created output

    shell:
        """
        echo "START: Higher Level Processing"

        # create output dir
        mkdir -p {output.higher_lvl}

        {force_run} force-higher-level {input.trend_param_file}
        """

# mosaicking
rule mosaicking:
    input:
        trend = HIGHERLVL,
        datacube = "data/datacube-definition.prj",
        # val = (product)

    output:
        mosaic = directory(TREND + "mosaic/"),
        # val = (product)

    shell:
        """
        echo "START: mosaicking"

        # create output dir
        mkdir -p {output.mosaic}

        # datacube-dir
        {force_run} force-mosaic {input.trend}

        """
    # TODO: creates output (mosaic) dir in input dir (higher_level)
    # TODO: maybe needs to be moved before into another dir (trend)

# pyramids
rule pyramids:
    input:
        higherlvl = expand(HIGHERLVL + "X0106_Y0102/{images}", 
            images=[f for f in os.listdir(HIGHERLVL + "X0106_Y0102/") if f.endswith(".tif")]),
        # higherlvl = expand("results/higher_level/X0106_Y0102/{images}.tif", images = glob.glob("results/higher_level/X0106_Y0102/*.tif")),
        # TODO: glob allows "*" in combination with wilcards

    output:
        pyramid = directory(TREND + "pyramid/"),

    shell:
        """
        echo "START: pyramids"

        # create output dir
        mkdir -p {output.pyramid}

        {force_run} force-pyramid {input.higherlvl}
        """
        # TODO: currently puts pyramid files in the same dir as the original input files

        # TODO: force-pyramid {image dir}
        # files="*.tif"
        # for file in \$files; do
        #   force-pyramid \$file
        # done;

        # TODO: Maybe move into output dir and change names for higher level, mosaicking, pyramids
