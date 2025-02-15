# Babel Plugin JSX DOM Expressions

[![Build Status](https://img.shields.io/travis/com/ryansolid/babel-plugin-jsx-dom-expressions.svg?style=flat)](https://travis-ci.com/ryansolid/babel-plugin-jsx-dom-expressions)
[![Coverage Status](https://img.shields.io/coveralls/github/ryansolid/babel-plugin-jsx-dom-expressions.svg?style=flat)](https://coveralls.io/github/ryansolid/babel-plugin-jsx-dom-expressions?branch=master)
[![NPM Version](https://img.shields.io/npm/v/babel-plugin-jsx-dom-expressions.svg?style=flat)](https://www.npmjs.com/package/babel-plugin-jsx-dom-expressions)
![](https://img.shields.io/bundlephobia/minzip/babel-plugin-jsx-dom-expressions.svg?style=flat)
![](https://img.shields.io/david/ryansolid/babel-plugin-jsx-dom-expressions.svg?style=flat)
![](https://img.shields.io/npm/dt/babel-plugin-jsx-dom-expressions.svg?style=flat)

This package is a JSX compiler built for [DOM Expressions](https://github.com/ryansolid/dom-expressions) to provide a general JSX to DOM transformation for reactive libraries that do fine grained change detection. This package aims to convert JSX statements to native DOM statements and wrap JSX expressions with functions that can be implemented with the library of your choice. Sort of like a JSX to Hyperscript for fine change detection.

## Features

This plugin treats all lowercase tags as html elements and mixed cased tags as Custom Functions. This enables breaking up your view into functional components. This library supports Web Component Custom Elements spec. Support for common camelcase event handlers like React, dom safe attributes like class and for, a simple ref property, and parsing of objects for style, and classList properties.

In general JSX Attribute Expressions are treated as properties by default, with exception of hyphenated(-) ones that will always be set as attributes on the DOM element. Plain string attributes(Non expression, no {}) will be treated as attributes.

<b>For dynamic expressions that should be wrapped in a computation for partial re-render use inner parenthesis in the expression ```{( )}```.</b>

## Example

```jsx
const view = ({ item }) =>
  <tr class={( item.id === selected ? 'danger' : '' )}>
    <td class="col-md-1">{ item.id }</td>
    <td class="col-md-4">
      <a onclick={e => select(item, e)}>{( item.label )}</a>
    </td>
    <td class="col-md-1"><a onclick={e => del(item, e)}>
      <span class="glyphicon glyphicon-remove" aria-hidden="true"></span>
    </a></td>
    <td class="col-md-6"></td>
  </tr>
```
Compiles to:

```jsx
import { insert as _$insert } from "dom";
import { wrap as _$wrap } from "dom";

const _tmpl$ = document.createElement("template");
_tmpl$.innerHTML = "<tr><td class='col-md-1'></td><td class='col-md-4'><a></a></td><td class='col-md-1'><a><span class='glyphicon glyphicon-remove' aria-hidden='true'></span></a></td><td class='col-md-6'></td></tr>";

const view = ({ item }) =>
  function () {
    const _el$ = _tmpl$.content.firstChild.cloneNode(true),
          _el$2 = _el$.firstChild,
          _el$3 = _el$2.nextSibling,
          _el$4 = _el$3.firstChild,
          _el$5 = _el$3.nextSibling,
          _el$6 = _el$5.firstChild;
    _$wrap(() => _el$.className = item.id === selected ? 'danger' : '');
    _$insert(_el$2, item.id);
    _el$4.onclick = e => select(item, e);
    _$insert(_el$4, () => item.label);
    _el$6.onclick = e => del(item, e);
    return _el$;
  }();
```
The use of cloneNode improves repeat insert performance and precompilation reduces the number of references to the minimal traversal path. This is a basic example which doesn't leverage event delegation or any of the more advanced features described below.

## Example Implementations
* [Solid](https://github.com/ryansolid/solid): A declarative JavaScript library for building user interfaces.
* [ko-jsx](https://github.com/ryansolid/ko-jsx): Knockout JS with JSX rendering.
* [mobx-jsx](https://github.com/ryansolid/mobx-jsx): Ever wondered how much more performant MobX is without React? A lot.

## Plugin Options

### moduleName (required)
The name of the runtime module to import the methods from.

### delegateEvents
Boolean to indicate whether to enable automatic event delegation on camelCase.

### contextToCustomElements
Boeolean Indicates whether to set current render context on Custom Elements and slots. Useful for seemless Context API with Web Components.

## Special Binding

### ref

This binding will assign the variable you pass to it with the DOM element.

### forwardRef

This binding takes a props.ref for Function Components and forwards a Real DOM reference.

```jsx
const Child = props => <div forwardRef={props.ref} />

const Parent = () => {
  let ref;
  return <Child ref={ref} />
}
```

### on(eventName) / model

These will be treated as event handlers expecting a function. All lowercase are considered directly bound events(Level 1) and camelCase for delegated. The syntax and usage for delegation is still experimental. The model which can be the same node or closest ancestor is passed to delegated events as second argument.

```jsx
<ul>
  <$ each={list}>{ item => <li model={item.id} onClick={handler} /> }</$>
</ul>
```
This delegation solution works with Web Components and the Shadow DOM as well if the events are composed. That limits the list to custom events and most UA UI events like onClick, onKeyUp, onKeyDown, onDblClick, onInput, onMouseDown, onMouseUp, etc..

Important:
* To allow for casing to work all custom events should follow the all lowercase convention of native events. If you want to use different event convention (or use Level 3 Events "addEventListener") use the events binding.

* Event delegates aren't cleaned up automatically off Document. If you will be completely unmounting the library and wish to remove the handlers from the current page use r.clearDelegatedEvents.

### $____

Custom directives are written with a $ prefix. Their signature is:
```js
function(element, valueAccessor) {}
```
where valueAccessor is function wrapping the expression.

### classList

This takes an object and assigns all the keys as classes which are truthy.
```jsx
<div classList={({ selected: isSelected(), editing: isEditing() })} />
```
### events

Generic event method for Level 3 "addEventListener" events. Experimental.
```jsx
<div events={{ "Weird-Event": e => alert(e.detail) }} />
```

### ... (spreads)

Spreads let you pass multiple props at once. If you wish dynamic updating remember to wrap with a parenthesis:

```jsx
<div {...static} {...(dynamic)} />
```

Keep in mind given the independent nature of binding updates there is no guarantee of order using spreads at this time. It's under consideration.

## Components

Components are just Capital Cased tags. The same rules around dynamic wrapping apply. Instead of wrapping with computation dynamic props will just be getter accessors. * Remember property access triggers so don't destructure outside of computations.

```jsx
const MyComp = props => (
  <>
    <div>{( props.param )}</div>
    <div>{ props.static }</div>
  </>
);

<MyComp param={( dynamic() )} other={ static } />
```

Components may have children. This is available as props.children. It will either be the value of a single expression child or it will be a DOM node(Fragment in case of multi-children) which can be rendered. Children are always evaluated lazily upon access (like dynamic properties).

## Control Flow

Loops and conditionals are handled by a special JSX tag `<$></$>`. The reason to use a tag instead of just data.map comes from the fact that it isn't just a map function in fine grain. It requires creating nested contexts and memoizing values. Even with custom methods the injection can never be as optimized as giving a special helper and I found I was re-writing pretty much identical code in all implementations. Currently there is support for 6 props on this component 'each', 'when', 'switch', 'provide', 'suspend', and 'portal' where the argument is the list to iterate or the condition. The Child is a function (render prop). For each it passes the item and the index to the function, and for when it passes the evaluated value.

```jsx
<ul>
  <$ each={ state.users }>{
    user => <li>
      <div>{( user.firstName )}</div>
      <$ when={ user.stars > 100 }>{
        () => <div>Verified</div>
      }</$>
    </li>
  }</$>
</ul>
```
Often for when there is no need for the argument and it can be skipped if desired using direct descendants. Since this is parsed at compile time there is no concern about the inner code running if the outer condition is not met.

```jsx
<$ when={ todos.length > 0 }>
  <span>{( todos.length )}</span>
  <button onClick={ removeCompleted }>Clear Completed</button>
</$>
```
Sometimes you want mutually exclusive options. Switch will evaluate each child when in succession until it hits the first truthy value.

```jsx
<$ switch fallback={<div>Route not Found</div>}>
  <$ when={state.route === 'home'}><Home /></$>
  <$ when={state.route === 'profile'}><Profile /></$>
  <$ when={state.route === 'settings'}><Settings /></$>
</$>
```

Provide(Experimental) is used with a Context API to allow for hierarchically resolved dependency injection. The value provided will be either passed to an initializer function defined or will be the provided context. Opt in for the specific library runtime.

```jsx
<$ provide={ ThemeContext } value= { 'dark' }>
  <ThemedComponent />
</$>
```
Suspend(Experimental) works almost the opposite of when where a truthy value will put the child in suspense. It differs from when in that instead of not rendering the child content it attaches it to a foreign document(important to fire connectedCallbacks on Web Components). This is useful if you still want load child components but don't wish to attach them to the current DOM until your are ready and display some fallback content instead. Useful for upstream handling of loading mechanisms when fetching data. It either takes a specific boolean accessor or uses a defined Suspense Context provided by the library.

```jsx
<$ suspend={ state.loading } fallback={<div>Loading...</div>}>
  <MyComp query={( state.query )} onLoaded={() => setState({ loading: false })} />
</$>
```
Portal(Experimental) renders to a different than the current rendering tree. This is useful for handling modals. By default it will create a div under document.body but the target can be set by passing an argument. To support isolated styles there is an option to useShadow to stick the portal in an isolated ShadowRoot.

```jsx
<$ portal>
  <MyModal>
    <h1>Header</h1>
    <p>Lorem ipsum ...</p>
  </MyModal>
</$>
```

Control flow also has some additional options that can be passed as attributes.

### afterRender
Pass in a function that will be called after each update with the first element and next sibling of the inserted nodes. Useful for postprocessing nodes on mass. Like a batch ref.
Supported by: each, when

### fallback
If the condition is falsy this fallback content will rendered instead.
Supported by: each, when, suspend

### useShadow
Uses a Shadow Root for portals.
Supported by: portal

### value
Sets initialization value for provide control flow.
Supported by: provide

```jsx
<$ each={ todos } fallback={<span>Loading...</span>}>{ todo =>
  <div>{todo.title}</div>
}</$>
```

This plugin also supports JSX Fragments with `<></>` notation. This is the prefered way to add multi-node roots explicit arrays tend to create more HTML string templates than necessary.

## Work in Progress

I'm mostly focusing early on where I can make the biggest conceptual gain so the plugin lacks in a few key places most noticeably lack of complete SVG.

## Acknowledgements

The concept of using JSX to DOM instead of html strings and context based binding usually found in these libraries was inspired greatly by [Surplus](https://github.com/adamhaile/surplus).
