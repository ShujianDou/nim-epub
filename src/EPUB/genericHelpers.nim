import std/strutils
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

proc GeneratePage*(nodes: seq[TiNode], title: string): Page =
    var builder: string = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!DOCTYPE html PUBLIC \" -//W3C//DTD XHTML 1.1//EN\"\n\"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n<html xmlns=\"http://www.w3.org/1999/xhtml\">\n<head><title></title><link href=\"../Styles/stylesheet.css\" type=\"text/css\" rel=\"stylesheet\"/></head>\n"

    var imageList: seq[ref Image]
    builder.add("<body>\n<h1 class=\"entry-title\">$1</h1><p></p>" % title)
    var idx: int = 0
    while idx < nodes.len:
        let node: TiNode = nodes[idx]
        # seq can not be nil
        if node.images.len <= 0:
            if node.ignoreParsing == false:
                node.text = MakeTextXHTMLReader(node.text)
            for x in split(node.text):
                builder.add("<p>$1</p>" % x)
        else:
            for i in node.images:
                builder.add(i.ToString())
                builder.add("\n")
                imageList.add(i)
        inc idx
    builder.add("</body></html>")
    return Page(id: title, text: builder, fileName: title, location: "", images: imageList)

proc PageToItem*(page: Page): Item =
    return Item(id: page.id, href: page.location, mediaType: MediaType.pXhtml)
proc ImageToItem*(image: Image): Item =
    return Item(id: image.name, href: image.location, mediaType: MediaType.pImage)
