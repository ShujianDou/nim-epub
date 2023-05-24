Documentation for the rewrite version is not yet available, since things are not yet finalized.

To open an epub to read content:
```nim
import EPUB

# Loads your EPUBs' metadata, manifest, spine.
var myEpub = LoadEpubFromDir("./yourEpublocation")
# Loads the table of contents for navigation of pages.
loadTOC(myEpub)
```

There are currently no functions to generate TiNodes from pages, nor create pages/epubs in this version.
