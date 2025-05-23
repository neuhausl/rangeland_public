configfile: "../../config/download_config.yaml"

force_ver       =   config["force_ver"]
sensors_level1  =   config["sensors_level1"]
start_date      =   config["start_date"]
end_date        =   config["end_date"]
time_range      =   start_date.replace('-', '') + "," + end_date.replace('-', '')

PATH            =   config["resources"]
force_run       =   "docker run --rm -v " + PATH + ":/data/input -v " + PATH + \
                    ":/data/eo -w /data/eo -u $(id -u):$(id -g) " + force_ver
                    # "docker run -v " + PATH + "/force:/opt/data --user $(id -u):$(id -g) " + force_ver



# start downloads
rule all:
    input: 
        expand("{path}/wvdb", path=PATH),                                   # watervapordb download
        expand("{path}/data/", path=PATH),                                  # data download
        expand("{path}/meta/", path=PATH),

        # expand("{path}/input/grid/datacube-definition.prj", path=PATH),     # auxiliary download
        # expand("{path}/input/vector/aoi.gpkg", path=PATH),                   
        # expand("{path}/input/endmember/hostert-2003.txt", path=PATH)


# get force 
rule download_force:
    # input:
    output:
        directory("{PATH}/force")

    # --rm to cleanup container after exiting, -p for already existing files
    # docker run -v {PATH}/force:/opt/data --user "$(id -u):$(id -g)" {force_ver}
    shell:
        """
        mkdir -p {output}
        {force_run}
        """

# download watervapor files
rule download_watervapor_db:
    # force output dir, so it runs after the force download
    input:
        "{PATH}/force"

    output: 
        directory("{PATH}/wvdb")

    shell: 
        """
        wget -O wvp-global.tar.gz https://zenodo.org/record/4468701/files/wvp-global.tar.gz?download=1
        mkdir -p {output}
        tar -xzf wvp-global.tar.gz --directory {output}/
        """


# download data
rule download_data:
    # auxiliary output dirs, so it runs after the auxiliary download
    input:
        "{PATH}/input/grid/datacube-definition.prj",
        "{PATH}/input/vector/aoi.gpkg",
        "{PATH}/input/endmember/hostert-2003.txt"

    output: 
        directory("{PATH}/data/"),
        directory("{PATH}/meta/")

    shell: 
    # gcloud init TODO: needs testing
    # {force_run} force-level1-csd -s {sensors_level1} -d {time_range} -c 0,70 {PATH}/meta/ {PATH}/data/ {PATH}/data/queue.txt aoi/aoi.gpkg
        """
        mkdir -p {PATH}/meta
        {force_run} force-level1-csd -s {sensors_level1} -u {output[1]}
        mkdir -p {PATH}/data
        {force_run} force-level1-csd -s {sensors_level1} -d {time_range} -c 0,70 {output[1]} {output[0]} {PATH}/data/queue.txt {input[1]}
        """

# download auxiliary
rule download_auxiliary:
    # force output dir, so it runs after the force download
    input:
        "{PATH}/force"

    output:
        "{PATH}/input/grid/datacube-definition.prj",
        "{PATH}/input/vector/aoi.gpkg",
        "{PATH}/input/endmember/hostert-2003.txt"

    shell:
        """
        wget -O auxiliary.tar.gz https://box.hu-berlin.de/f/c4d90fc5b07c4955b979/?dl=1
        tar -xzf auxiliary.tar.gz
        mv EO-01/input/ {PATH}/input
        """