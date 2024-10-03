# Docs: Git

## Look for a line in commit history

This command will list the commits where a specific string was added and removed from a file.
It will display the commit log along with the diff, showing where the line was added or removed.
```bash
git log -p -S'example line' -- example.txt
```
---

## Copy file from a commit/branch to another branch

Place yourself on the branch you would like to copy **to**, and run
```bash
git checkout <SOURCE_BRANCH> myfile
```
Or to modify only the working directory (the previous command also copies to the staging area)
```bash
git restore --source <SOURCE_BRANCH> myfile
```
