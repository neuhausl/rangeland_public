import numpy as np

conda: "env.yaml"
# !!! conda: inside rules only works with shell, script, notebook, or wrapper directives, not run !!!

def quick_maths():
    return str(np.__version__)


def process_data(rule_name, label_key, label_value):
    return str(rule_name + ", " + label_key + " : " + label_value + "\n")
    

# rule all
rule all:
    input:
        "processed_data.txt",
        "report.txt"

    output:
        "output.txt"

    run:
        quick_maths()
        process_data("all", "usedby", "neuhausl")
        shell(
            """
            echo 'Rule all output' > {output}
            """
        )
        # always use {output} not the filepath itself, snakemake gets confused when not locally executed
        # quick_maths()/process_data(...) to test how 'run' directive works

# Set node selector for pods spawned by rule all


# Rule process data
rule process_data:
    output:
        "processed_data.txt"

    run:
        quick_maths()
        process_data("process_data", "usedby", "neuhausl")
        shell(
            """
            echo 'Processing data' > {output}
            """
        )
        # always use {output} not the filepath itself, snakemake gets confused when not locally executed
        # quick_maths()/process_data(...) to test how 'run' directive works

# Set node selector for pods spawned by rule process_data


# Rule generate report
rule generate_report:
    input:
        "processed_data.txt"

    output:
        "report.txt"

    run:
        quick_maths()
        process_data("generate_report", "usedby", "neuhausl")
        shell(
            """
            echo 'Generating report' > {output}
            """
        )
        # always use {output} not the filepath itself, snakemake gets confused when not locally executed
        # quick_maths()/process_data(...) to test how 'run' directive works

# Set node selector for pods spawned by rule generate_report
