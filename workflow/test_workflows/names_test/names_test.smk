# !!!don't ever create files or directories with whitespaces!!!

configfile: "config.yaml"
MEMs = config["MEM_ST"]

rule all:
	input:
		expand(
			"{st_names}/mem.txt", st_names = list(MEMs.values())
			)
		

# First real rule, this is using a wildcard called "names"

rule BM:
	output:
		"{st_names}/st.txt"
	shell:
		"""
		echo "{wildcards.st_names}" > {output}
		"""


rule members:
	input: 
		"{st_names}/st.txt"
	output:
		"{st_names}/mem.txt"
	script:
		"merge.py"
