To open an epub to read content:
```nim
import EPUB

# Loads your EPUBs' metadata, manifest, spine.
var myEpub = LoadEpubFromDir("./yourEpublocation")
# Loads the table of contents for navigation of pages.
loadTOC(myEpub)
# Get the first "Page" object from a navigation node
let ourPage = myEpub.getPageFromNode(myEpub.navigation.nodes[0])
# Print the raw text of this Page object (ignores images) (note: currently computes text every call, does not cache)
echo $ourPage
```