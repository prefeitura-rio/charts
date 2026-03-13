# Update all submodules to latest commit on their tracked branch
@update-submodules:
    git submodule update --remote --merge --recursive
    git add .
    git commit -m "chore: update all submodules to latest commit on their tracked branch"
