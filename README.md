An epub generation and exportation library for nim; it's not meant to be able to read and navigate EPUBs, created for use in [ADLCore](https://github.com/vrienstudios/ADLCore)<br>
Example:
```nim
import ./src/EPUB
import ./src/EPUB/Types/genericTypes

import strutils

var epub: Epub = Epub(title: "Shu", author: "test")

var path: string = "./hercu.epub"
discard epub.StartEpubExport(path)

var page: Page = Page(id: $0, text: "Hello, World!", fileName: "hello.xhtml", location: "heckifIknow")

discard epub.AddPage(page)

discard epub.EndEpubExport("hhhh", "Shu")
```
