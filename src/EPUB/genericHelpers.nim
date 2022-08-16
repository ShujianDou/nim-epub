import std/[xmlparser, parsexml, xmltree, os, strutils, tables]

proc GenXMLElementWithAttrs*(title: string, t: varargs[tuple[key, val: string]]): XmlNode =
  var item: XmlNode = newElement(title)
  item.attrs = t.toXmlAttributes
  return item
type nestedElement* = ref object
  self: XmlNode
  children: seq[XmlNode]
proc InlineElementBuilder*(host: XmlNode, elems: seq[nestedElement]) =
  for elem in elems:
    if elem.children.len > 0:
      InlineElementBuilder(elem.self, elem.children)
    host.add(elem.self)
proc xhtmlifyTiNode*(nodes: seq[TiNode], imgPath: string): string =
  var xhtmlNode: XmlNode = newElement("body")
  for n in nodes:
    if n.text != "":
      xhtmlNode.add InlineElementBuilder(newElement("p"), @[nestedElement(self: newText(n.text), children: @[])])
    for image in n.images:
      xhtmlNode.add GenXMLElementWithAttrs("img", {"href": imgPath / image.name})
    continue
  return $InlineElementBuilder(newElement("html"), @[nestedElement(self: xhtmlNode, children: @[])])
