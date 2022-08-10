import std/[strutils, unicode]
import ./Types/genericTypes

proc MakeTextXHTMLReader(text: string): string =
    var builder: string = ""
    for i in @text:
        case i
        of '<':
            builder.add("&lt;")
        of '>':
            builder.add("&gt;")
        of '&':
            builder.add("&amp;")
        else:
            builder.add(i)
    return builder
proc EscapeValues*(text: string): string =
    var str = ""
    var runes = toRunes(text)
    var i = 0
    while i < runes.len:
        if (ord(runes[i]) >= ord(' ')) and (ord(runes[i]) <= ord('~')):
            str.add($runes[i])
        else:
            var hex = runes[i].int.toHex()
            hex.removePrefix('0')
            str.add("&#x" & hex & ";")
        inc i
    return str
proc SanitizePageProp*(filename: string): string =
  var newStr: string = ""
  var oS = filename.toLowerAscii()
  for chr in oS:
    # what is regex
    if (ord(chr) >= ord('a') and ord(chr) <= ord('z')) or (ord(chr) >= ord('0') and ord(chr) <= ord('9')) or (ord(chr) == ord('_')) or (ord(chr) == ord('.')):
      newStr.add(chr)
  return newStr
proc GeneratePage*(nodes: seq[TiNode], title: string): Page =
    var builder: string = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!DOCTYPE html PUBLIC \" -//W3C//DTD XHTML 1.1//EN\"\n\"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n<html xmlns=\"http://www.w3.org/1999/xhtml\">\n<head><title></title></head>\n"

    var imageList: seq[Image]
    builder.add("<body>\n<h1 class=\"entry-title\">$1</h1><p></p>" % title)
    var idx: int = 0
    while idx < nodes.len:
        let node: TiNode = nodes[idx]
        # seq can not be nil
        if node.images.len <= 0:
            if node.ignoreParsing == false:
                node.text = MakeTextXHTMLReader(node.text)
                builder.add("<p>$1</p>" % node.text)
        else:
            for i in node.images:
                builder.add(i.ToString())
                builder.add("\n")
                imageList.add(i)
        inc idx
    builder.add("</body></html>")
    return Page(id: SanitizePageProp(title), text: builder, fileName: title, location: "", images: imageList)

proc PageToItem*(page: Page): Item =
    return Item(id: page.id, href: "Text/" & page.fileName & ".xhtml", mediaType: MediaType.pXhtml)
proc ImageToItem*(image: Image): Item =
    return Item(id: image.name, href: "Pictures/" & image.name, mediaType: MediaType.pImage)
