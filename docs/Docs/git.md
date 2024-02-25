### Look for a line in commit history

This command will list the commits where a specific string was added and removed from a file.
It will display the commit log along with the diff, showing where the line was added or removed.
``` bash
git log -p -S'example line' -- example.txt
```
---
