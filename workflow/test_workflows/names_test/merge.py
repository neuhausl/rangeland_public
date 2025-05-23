f = open(snakemake.input[0], "r")
text = f.read().strip()
key = list((snakemake.config["MEM_ST"]).keys())[list((snakemake.config["MEM_ST"]).values()).index(text)]
d = open(snakemake.output[0], "w")
d.write(key)
f.close
d.close