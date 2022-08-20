An epub generation and exportation library for nim; it's not meant to be able to read and navigate EPUBs, created for use in [ADLCore](https://github.com/vrienstudios/ADLCore)<br>
Example:
```nim
  import EPUB/[types, EPUB3]

  var testEpub: EPUB3
  let mdataList: seq[metaDataList] = @[
    (metaType: MetaType.dc, name: "title", attrs: @[("id", "title")], text: "hellow"),
    (metaType: MetaType.dc, name: "creator", attrs: @[("id", "creator")], text: "melul"),
    (metaType: MetaType.dc, name: "language", attrs: @[], text: "en"),
    (metaType: MetaType.dc, name: "identifier", attrs: @[("id", "pub-id")], text: "helloworld"),
    (metaType: MetaType.meta, name: "", attrs: @[("property", "dcterms:modified")], text: "2022-01-02T03:50:100"),
    (metaType: MetaType.dc, name: "publisher", attrs: @[], text: "vrienco")]
  testEpub = CreateEpub3(mdataList, "./helloCuteWorld")
  AddPage(testEpub, GeneratePage("dlrowolleh", @[TiNode(text: "helloWorld")]))
  FinalizeEpub(testEpub)
```
Creates an epub called helloCuteWorld with title 'hellow', and a single chapter titled dlrowolleh with a header of helloWorld.
This is currently an experimental library for EPUB writing/reading.

If you're planning to use this library, be warned: it's not recommended to use this for opening and reading EPUBs currently, but writing EPUBs should work just fine.