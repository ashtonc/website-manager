# Base home directory
gsutil -m rsync -r -x ".git/" "ashtonc" "gs://ashtonc.ca"

# TA content
cd ta; hugo; cd ..
gsutil -m rsync -r -x ".git/" "ta/public" "gs://ashtonc.ca/ta"

# Debate content
#cd debate; hugo; cd ..
#gsutil -m rsync -r -x ".git/" "debate/public" "gs://ashtonc.ca/debate"

# Blog content
#cd blog; hugo; cd ..
#gsutil -m rsync -r -x ".git/" "blog/public" "gs://ashtonc.ca/blog"

