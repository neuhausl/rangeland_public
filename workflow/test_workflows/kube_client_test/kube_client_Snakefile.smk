conda: "env.yaml"
# !!! conda: inside rules only works with shell, script, notebook, or wrapper directives, not run !!!
configfile: "env.yaml"
import kubernetes

def set_node_selector(rule_name, label_key, label_value):
    # Load Kubernetes configuration, loads conf from /.kube/conf
    kubernetes.config.load_kube_config()

    # Create a Kubernetes client
    kube_client = kubernetes.client.CoreV1Api()

    # Define node selector
    node_selector = {label_key: label_value}

    container_definition = kubernetes.client.V1Container(
        name = "snakemake-container",
        image = "snakemake/snakemake:v8.10.6",
        command=["/bin/bash", "-c"],  # Example command
    )

    pod_spec = kubernetes.client.V1PodSpec(
        containers = [container_definition],
        node_selector = node_selector  # Set the node selector
    )
    
    # Set node selector for the given rule
    kube_client.patch_namespaced_pod_template(
        name = rule_name,
        namespace = "neuhausl",  # Adjust namespace as needed
        body = kubernetes.client.V1PodTemplateSpec(
            spec = pod_spec
        )
    )


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
        set_node_selector("all", "usedby", "neuhausl")
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
        set_node_selector("process_data", "usedby", "neuhausl")
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
        set_node_selector("generate_report", "usedby", "neuhausl")
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