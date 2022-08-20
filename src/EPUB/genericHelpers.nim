import std/[xmlparser, parsexml, xmltree, os, strutils, tables, enumutils]
import types

proc GenXMLElementWithAttrs*(title: string, t: varargs[tuple[key, val: string]]): XmlNode =
  var item: XmlNode = newElement(title)
  item.attrs = t.toXmlAttributes
  return item
type nestedElement* = ref object
  self: XmlNode
  children: seq[nestedElement]
proc InlineElementBuilder*(host: XmlNode, elems: seq[nestedElement]): XmlNode =
  for elem in elems:
    if elem.children.len > 0:
      discard InlineElementBuilder(elem.self, elem.children)
    host.add(elem.self)
  return host
proc addMultipleNodes*(host: XmlNode, nodes: seq[XmlNode]): XmlNode =
  for n in nodes:
    host.add n
  return host
proc xhtmlifyTiNode*(nodes: seq[TiNode], title: string, imgPath: string): string =
  var xhtmlNode: XmlNode = newElement("body")
  for n in nodes:
    if n.text != "":
      xhtmlNode.add(InlineElementBuilder(newElement(symbolName(n.kind)), @[nestedElement(self: newText(n.text), children: @[])]))
    for image in n.images:
      xhtmlNode.add GenXMLElementWithAttrs("img", {"href": "../" & imgPath / image.name})
    continue
  return $InlineElementBuilder(GenXMLElementWithAttrs("html", {"xmlns": "http://www.w3.org/1999/xhtml", "xmlns:epub": "http://www.idpf.org/2007/ops"}), @[nestedElement(self: addMultipleNodes(newElement("head"), @[GenXMLElementWithAttrs("meta", {"http-equiv": "default-style", "content": "text/html; charset=utf-8"}), addMultipleNodes(newElement("title"), @[newText(title)])]), children: @[]), nestedElement(self: xhtmlNode, children: @[])])
proc SanitizePageProp*(filename: string): string =
  var newStr: string = ""
  var oS = filename.toLowerAscii()
  for chr in oS:
    # what is regex
    if (ord(chr) >= ord('a') and ord(chr) <= ord('z')) or (ord(chr) >= ord('0') and ord(chr) <= ord('9')) or (ord(chr) == ord('_')) or (ord(chr) == ord('.')):
      newStr.add(chr)
  return newStr