import os

files = [
    "20231130001134-2037.octoshift.log",
    "20231130002149-2339.octoshift.log",
    "20231130001352-2111.octoshift.log",
    "20231130000951-1851.octoshift.log",
    "20231130001608-2189.octoshift.log",
    "20231130002035-2287.octoshift.log",
    "20231130002312-2388.octoshift.log",
    "20231130002551-2475.octoshift.log",
    "20231130002429-2427.octoshift.log",
    "20231130002702-2519.octoshift.log"
]
for file in files:
    os.system(f"aws s3 cp s3://github-migration-log-bucket-7c3011f/UoS_prod_migrations/{file} .")
