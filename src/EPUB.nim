import EPUB/[types, EPUB3]

#block:
#  var testEpub: EPUB3
#  let mdataList: seq[metaDataList] = @[
#    (metaType: MetaType.dc, name: "title", attrs: @[("id", "title")], text: "hellow"),
#    (metaType: MetaType.dc, name: "creator", attrs: @[("id", "creator")], text: "melul"),
#    (metaType: MetaType.dc, name: "language", attrs: @[], text: "en"),
#    (metaType: MetaType.dc, name: "identifier", attrs: @[("id", "pub-id")], text: "helloworld"),
#    (metaType: MetaType.meta, name: "", attrs: @[("property", "dcterms:modified")], text: "2022-01-02T03:50:100"),
#    (metaType: MetaType.dc, name: "publisher", attrs: @[], text: "vrienco")]
#  testEpub = CreateEpub3(mdataList, "/mnt/General/work/Programming/EPUB/src/helloCuteWorld")
#  AddPage(testEpub, GeneratePage("dlrowolleh", @[TiNode(text: "helloWorld")]))
#  FinalizeEpub(testEpub)
