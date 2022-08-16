import std/[xmlparser, parsexml, xmltree, os, strutils, tables]

proc GenXMLElementWithAttrs*(title: string, t: varargs[tuple[key, val: string]]): XmlNode =
  var item: XmlNode = newElement(title)
  item.attrs = t.toXmlAttributes
  return item