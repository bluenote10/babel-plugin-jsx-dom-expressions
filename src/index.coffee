import SyntaxJSX from '@babel/plugin-syntax-jsx'
import Attributes from './Attributes'

export { createRuntime } from './createRuntime'

export default (babel) ->
  { types: t } = babel

  document = t.identifier("document");
  createElement = t.identifier("createElement");
  createElementNS = t.identifier("createElementNS");
  createFragment = t.identifier("createDocumentFragment");
  createTextNode = t.identifier("createTextNode");
  appendChild = t.identifier("appendChild");
  setAttribute = t.identifier("setAttribute");
  hasOwnProperty = t.identifier("hasOwnProperty");
  string = t.stringLiteral("string");
  length = t.identifier("length");
  ArrayClass = t.identifier("Array");
  StringClass = t.identifier("String");
  NodeClass = t.identifier("Node");
  zero = t.numericLiteral(0);
  one = t.numericLiteral(1);
  moduleName = 'r'

  text = (string) ->
    t.callExpression(t.memberExpression(document, createTextNode), [string])

  append = (node, child) ->
    call = t.callExpression(t.memberExpression(node, appendChild), [child])
    t.expressionStatement(call)

  declare = (name, value) ->
    t.variableDeclaration("let", [t.variableDeclarator(name, value)])

  toEventName = (name) ->
    name.slice(2).replace(/^(.)/, ($1) -> $1.toLowerCase())

  checkDoubleParens = (jsx, path) ->
    e = path.hub.file.code[jsx.start+1...jsx.end-1].trim()
    e[0] is '(' and e[1] is '(' and e[e.length - 2] is ')' and e[e.length - 1] is ')'

  setAttr = (elem, name, value) ->
    isAttribute = name.indexOf('-') > -1
    if attribute = Attributes[name]
      if attribute.type is 'attribute'
        isAttribute = true
      else name = attribute.alias

    # if name.startsWith('fn')
    #   t.callExpression(value, [elem])
    if name.startsWith('$')
      t.callExpression(t.identifier(name.slice(1)), [elem, value])
    else if isAttribute
      t.callExpression(t.memberExpression(elem, setAttribute), [t.stringLiteral(name), value])
    else
      t.assignmentExpression('=', t.memberExpression(elem, t.identifier(name)), value)

  setAttrExpr = (path, elem, name, value) ->
    if (name.startsWith("on"))
      return t.expressionStatement(t.callExpression(t.memberExpression(elem, t.identifier('addEventListener')), [t.stringLiteral(toEventName(name)), value]))

    return t.expressionStatement(t.assignmentExpression("=", value, elem)) if name is 'ref'

    # if name.startsWith('fn')
    #   return t.expressionStatement(t.callExpression(t.identifier("#{moduleName}.wrap"), [t.arrowFunctionExpression([t.identifier('_current$')], t.callExpression(value, [elem, t.identifier('_current$')]))]))

    if name.startsWith('$')
      return t.expressionStatement(t.callExpression(t.identifier(name.slice(1)), [elem, t.arrowFunctionExpression([], value)]))

    content = switch name
      when 'style'
        [t.arrowFunctionExpression([], t.callExpression(t.identifier("#{moduleName}.assign"), [t.memberExpression(elem, t.identifier(name)), value]))]
      when 'classList'
        iter = t.identifier("className");
        [
          t.arrowFunctionExpression(
            [],
            t.blockStatement([
              t.forInStatement(
                declare(iter),
                value,
                t.ifStatement(
                  t.callExpression(t.memberExpression(value, hasOwnProperty), [iter]),
                  t.expressionStatement(t.callExpression(t.memberExpression(elem, t.identifier("classList.toggle")), [iter, t.memberExpression(value, iter, true)]))
                )
              )
            ])
          )
        ]
      else
        [t.arrowFunctionExpression([], setAttr(elem, name, value))]

    t.expressionStatement(t.callExpression(t.identifier("#{moduleName}.wrap"), content))

  generateHTMLNode = (path, jsx, opts) ->
    if t.isJSXElement(jsx)
      name = path.scope.generateUidIdentifier("el$")
      tagName = jsx.openingElement.name.name
      elems = []

      if tagName isnt tagName.toLowerCase()
        props = []
        runningObject = []
        for attribute in jsx.openingElement.attributes
          if t.isJSXSpreadAttribute(attribute)
            if runningObject.length
              props.push(t.objectExpression(runningObject))
              runningObject = []
            props.push(attribute.argument)
          else
            value = attribute.value
            if t.isJSXExpressionContainer(value)
              runningObject.push(t.objectProperty(t.identifier(attribute.name.name), value.expression))
            else
              runningObject.push(t.objectProperty(t.identifier(attribute.name.name), value))

        children = []
        for child in jsx.children
          child = generateHTMLNode(path, child, opts);
          continue if child is null
          if child.id
            children.push(t.callExpression(t.arrowFunctionExpression([], t.blockStatement([...child.elems, t.returnStatement(child.id)])), []))
          else if child.expression
            children.push(t.callExpression(child.elems[0], []))
          else children.push(child.elems[0])
        if children.length
          runningObject.push(t.objectProperty(t.identifier("children"), t.arrayExpression(children)))

        if runningObject.length
          props.push(t.objectExpression(runningObject))

        if props.length > 1
          props = [t.callExpression(t.identifier("#{moduleName}.assign"), props)]

        elems = [t.callExpression(t.identifier(tagName), props)]

        return { elems }

      namespace = null;
      nativeExtension = undefined;
      for attribute in jsx.openingElement.attributes
        if t.isJSXSpreadAttribute(attribute)
          elems.push(
            t.expressionStatement(t.callExpression(t.identifier("#{moduleName}.spread"), [name, t.arrowFunctionExpression([], attribute.argument)]))
          )
        else
          if attribute.name.name is "namespace"
            namespace = attribute.value
            continue

          if attribute.name.name is 'is'
            nativeExtension = attribute.value
            continue

          value = attribute.value

          skip = false
          if checkDoubleParens(value, path)
            skip = true
            value = value.expression

          if t.isJSXExpressionContainer(value) and not skip
            elems.push(setAttrExpr(path, name, attribute.name.name, value.expression))
          else
            elems.push(t.expressionStatement(setAttr(name, attribute.name.name, value)))

      if namespace
        call = t.callExpression(t.memberExpression(document, createElementNS), [namespace, t.stringLiteral(tagName)])
      else if nativeExtension
        call = t.callExpression(t.memberExpression(document, createElement), [t.stringLiteral(tagName), t.objectExpression([t.objectProperty(t.identifier('is'), nativeExtension)])])
      else
        call = t.callExpression(t.memberExpression(document, createElement), [t.stringLiteral(tagName)])

      decl = t.variableDeclaration("const", [t.variableDeclarator(name, call)])
      elems.unshift(decl)

      childExpressions = []
      for child in jsx.children
        child = generateHTMLNode(path, child, opts)
        continue if child is null
        if child.id
          elems.push(...child.elems)
          elems.push(append(name, child.id))
        else
          elems.push(t.expressionStatement(t.callExpression(t.identifier("#{moduleName}.insert#{if jsx.children.length > 1 then 'M' else ''}"), [name, child.elems[0]])))

      return { id: name, elems: elems }
    else if t.isJSXFragment(jsx)
      name = path.scope.generateUidIdentifier("el$")
      elems = []

      call = t.callExpression(t.memberExpression(document, createFragment), [])

      decl = t.variableDeclaration("const", [t.variableDeclarator(name, call)])
      elems.unshift(decl)

      for child in jsx.children
        child = generateHTMLNode(path, child, opts)
        continue if child is null
        if child.id
          elems.push(...child.elems)
          elems.push(append(name, child.id))
        else
          elems.push(t.expressionStatement(t.callExpression(t.identifier("#{moduleName}.insert#{if jsx.children.length > 1 then 'M' else ''}"), [name, child.elems[0]])))

      return { id: name, elems: elems }
    else if t.isJSXText(jsx)
      return null if not opts.allowWhitespaceOnly and /^\s*$/.test(jsx.value)
      return { id: text(t.stringLiteral(jsx.value)), elems: [] }
    else if t.isJSXExpressionContainer(jsx)
      if checkDoubleParens(jsx, path)
        return { elems: [jsx.expression], expression: true }

      return { elems: [t.arrowFunctionExpression([], jsx.expression)], expression: true }
    else
      return { elems: [jsx] }

  return {
    name: "ast-transform",
    inherits: SyntaxJSX
    visitor:
      JSXElement: (path, { opts }) ->
        moduleName = opts.moduleName if opts.moduleName
        result = generateHTMLNode(path, path.node, opts)
        if result.id
          path.replaceWithMultiple(result.elems.concat(t.expressionStatement(result.id)))
        else if result.expression
          path.replaceWith(t.callExpression(result.elems[0], []));
        else
          path.replaceWith(result.elems[0]);
        return
      JSXFragment: (path, { opts }) ->
        moduleName = opts.moduleName if opts.moduleName
        result = generateHTMLNode(path, path.node, opts)
        path.replaceWithMultiple(result.elems.concat(t.expressionStatement(result.id)))
        return
  }

