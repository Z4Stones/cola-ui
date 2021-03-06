###
BindingFeature
###

class cola._BindingFeature
	init: () -> return

class cola._ExpressionFeature extends cola._BindingFeature
	constructor: (@expression) ->
		if @expression
			@path = @expression.path
			if !@path and @expression.hasCallStatement
				@path = "**"
				@delay = true
			@watchingMoreMessage = @expression.hasCallStatement or @expression.convertors

	evaluate: (domBinding, dataCtx) ->
		dataCtx ?= {}
		return @expression.evaluate(domBinding.scope, "auto", dataCtx)

	refresh: (domBinding, force) ->
		return unless @_refresh
		if @delay and !force
			cola.util.delay(@, "refresh", 100, () ->
				@_refresh(domBinding)
				return
			)
		else
			@_refresh(domBinding)
		return

class cola._I18nFeature extends cola._BindingFeature
	constructor: (@template, @args) ->
		paths = {}
		for arg in args
			if arg instanceof cola.Expression
				expression = arg
				path = expression.path
				if path
					if path typeof "string"
						paths[path] = true
					else
						paths[p] = true for p in path
				else
					if expression.hasCallStatement
						paths = null
						@path = "**"
						@delay = true
						break

				if not @watchingMoreMessage
					@watchingMoreMessage = expression.hasCallStatement or expression.convertors

		if paths
			path = []
			path.push(p) for p of paths
			if path.length then @path = path

	_processMessage: (domBinding)->
		@refresh(domBinding)
		return

	refresh: (domBinding) ->
		realArgs = []
		for arg in @args
			if arg instanceof cola.Expression
				dataCtx ?= {}
				realArgs.push(arg.evaluate(domBinding.scope, "auto", dataCtx))
			else
				realArgs.push(arg)
		text = cola.i18n.apply(cola, [@template].concat(realArgs))
		$fly(domBinding.dom).text(if !text? then "" else text)
		return

class cola._WatchFeature extends cola._BindingFeature
	constructor: (@action, @path) ->
		@watchingMoreMessage = true

	_processMessage: (domBinding)->
		@refresh(domBinding)
		return

	refresh: (domBinding) ->
		action = domBinding.scope.action(@action)
		if not action
			throw new cola.Exception("No action named \"#{@action}\" found.")
		action(domBinding.dom, domBinding.scope)
		return

class cola._EventFeature extends cola._ExpressionFeature
	constructor: (@expression, @event) ->

	init: (domBinding) ->
		expression = @expression
		domBinding.$dom.bind(@event, () ->
			oldScope = cola.currentScope
			cola.currentScope = domBinding.scope
			try
				return expression.evaluate(domBinding.scope, "never")
			finally
				cola.currentScope = oldScope
		)
		return

class cola._AliasFeature extends cola._ExpressionFeature
	constructor: (expression) ->
		super(expression)
		@alias = expression.alias

	init: (domBinding) ->
		domBinding.scope = new cola.AliasScope(domBinding.scope, @expression)
		domBinding.subScopeCreated = true
		return

	_processMessage: (domBinding, bindingPath, path, type, arg)->
		if cola.constants.MESSAGE_REFRESH <= type <= cola.constants.MESSAGE_CURRENT_CHANGE or @watchingMoreMessage
			@refresh(domBinding)
		return

	_refresh: (domBinding)->
		data = @evaluate(domBinding)
		domBinding.scope.data.setTargetData(data)
		return

class cola._RepeatFeature extends cola._ExpressionFeature
	constructor: (expression) ->
		super(expression)
		@alias = expression.alias

	init: (domBinding) ->
		domBinding.scope = scope = new cola.ItemsScope(domBinding.scope, @expression)

		scope.onItemsRefresh = () =>
			@onItemsRefresh(domBinding)
			return
		scope.onCurrentItemChange = (arg) ->
			$fly(domBinding.currentItemDom).removeClass(cola.constants.COLLECTION_CURRENT_CLASS) if domBinding.currentItemDom
			if arg.current and domBinding.itemDomBindingMap
				itemId = cola.Entity._getEntityId(arg.current)
				if itemId
					currentItemDomBinding = domBinding.itemDomBindingMap[itemId]
					$fly(currentItemDomBinding.dom).addClass(cola.constants.COLLECTION_CURRENT_CLASS) if currentItemDomBinding
			domBinding.currentItemDom = currentItemDomBinding.dom
			return
		scope.onItemInsert = (arg) =>
			headDom = domBinding.dom
			tailDom = cola.util.userData(headDom, cola.constants.REPEAT_TAIL_KEY)
			templateDom = cola.util.userData(headDom, cola.constants.REPEAT_TEMPLATE_KEY)
			itemDom = @createNewItem(domBinding, templateDom, domBinding.scope, arg.entity)
			insertMode = arg.insertMode
			if !insertMode or insertMode == "end"
				$fly(tailDom).before(itemDom)
			else if insertMode == "begin"
				$fly(headDom).after(itemDom)
			else if domBinding.itemDomBindingMap
				refEntityId = cola.Entity._getEntityId(arg.refEntity)
				if refEntityId
					refDom = domBinding.itemDomBindingMap[refEntityId]?
					if refDom
						if insertMode == "before"
							$fly(refDom).before(itemDom)
						else
							$fly(refDom).after(itemDom)
			return
		scope.onItemRemove = (arg) ->
			itemId = cola.Entity._getEntityId(arg.entity)
			if itemId
				itemDomBinding = domBinding.itemDomBindingMap[itemId]
				if itemDomBinding
					arg.itemsScope.unregItemScope(itemId)
					itemDomBinding.remove()
					delete domBinding.currentItemDom if itemDomBinding.dom == domBinding.currentItemDom
			return

		domBinding.subScopeCreated = true
		return

	_refresh: (domBinding) ->
		domBinding.scope.refreshItems()
		return

	onItemsRefresh: (domBinding) ->
		scope = domBinding.scope

		items = scope.items
		originItems = scope.originData

		if items and !(items instanceof cola.EntityList) and !(items instanceof Array)
			throw new cola.I18nException("cola.error.repeatNeedCollection", @expression)

		if items != domBinding.items or (items and items.timestamp != domBinding.timestamp)
			domBinding.items = items
			domBinding.timestamp = items?.timestamp or 0

			headDom = domBinding.dom
			tailDom = cola.util.userData(headDom, cola.constants.REPEAT_TAIL_KEY)
			templateDom = cola.util.userData(headDom, cola.constants.REPEAT_TEMPLATE_KEY)
			if !tailDom
				tailDom = document.createComment("Repeat Tail ")
				$fly(headDom).after(tailDom)
				cola.util.userData(headDom, cola.constants.REPEAT_TAIL_KEY, tailDom)
			currentDom = headDom

			documentFragment = null
			if items
				domBinding.itemDomBindingMap = {}
				scope.resetItemScopeMap()

				$fly(domBinding.currentItemDom).removeClass(cola.constants.COLLECTION_CURRENT_CLASS) if domBinding.currentItemDom
				cola.each items, (item) =>
					if !item? then return

					itemDom = currentDom.nextSibling
					if itemDom == tailDom then itemDom = null

					if itemDom
						itemDomBinding = cola.util.userData(itemDom, cola.constants.DOM_BINDING_KEY)
						itemScope = itemDomBinding.scope
						if typeof item == "object"
							itemId = cola.Entity._getEntityId(item)
						else
							itemId = cola.uniqueId()
						scope.regItemScope(itemId, itemScope)
						itemDomBinding.itemId = itemId
						domBinding.itemDomBindingMap[itemId] = itemDomBinding
						itemScope.data.setTargetData(item)
					else
						itemDom = @createNewItem(domBinding, templateDom, scope, item)
						documentFragment ?= document.createDocumentFragment()
						documentFragment.appendChild(itemDom)
						$fly(tailDom).before(itemDom)

					if item == (items.current or originItems?.current)
						$fly(itemDom).addClass(cola.constants.COLLECTION_CURRENT_CLASS)
						domBinding.currentItemDom = itemDom

					currentDom = itemDom
					return

			if !documentFragment
				itemDom = currentDom.nextSibling
				while itemDom and itemDom != tailDom
					currentDom = itemDom
					itemDom = currentDom.nextSibling
					$fly(currentDom).remove()
			else
				$fly(tailDom).before(documentFragment)
		return

	createNewItem: (repeatDomBinding, templateDom, scope, item) ->
		itemScope = new cola.ItemScope(scope, @alias)
		itemScope.data.setTargetData(item, true)

		itemDom = templateDom.cloneNode(true)

		@deepCloneNodeData(itemDom, itemScope, false)
		templateDomBinding = cola.util.userData(templateDom, cola.constants.DOM_BINDING_KEY)
		domBinding = templateDomBinding.clone(itemDom, itemScope)
		@refreshItemDomBinding(itemDom, itemScope)

		if typeof item == "object"
			itemId = cola.Entity._getEntityId(item)
		else
			itemId = cola.uniqueId()
		scope.regItemScope(itemId, itemScope)
		domBinding.itemId = itemId
		repeatDomBinding.itemDomBindingMap[itemId] = domBinding
		return itemDom

	deepCloneNodeData: (node, scope, cloneDomBinding) ->
		store = cola.util.userData(node)
		if store
			clonedStore = {}
			for k, v of store
				if k == cola.constants.DOM_BINDING_KEY
					if cloneDomBinding
						v = v.clone(node, scope)
				else if k.substring(0, 2) == "__"
					continue
				clonedStore[k] = v
			cola.util.userData(node, clonedStore)

		child = node.firstChild
		while child
			if child.nodeType != 3 and !child.hasAttribute?(cola.constants.IGNORE_DIRECTIVE)
				@deepCloneNodeData(child, scope, true)
			child = child.nextSibling
		return

	refreshItemDomBinding: (dom, itemScope) ->
		domBinding = cola.util.userData(dom, cola.constants.DOM_BINDING_KEY)
		if domBinding
			domBinding.refresh()
			itemScope = domBinding.subScope or domBinding.scope
			if domBinding instanceof cola._RepeatDomBinding
				currentDom = cola.util.userData(domBinding.dom, cola.constants.REPEAT_TAIL_KEY)

		child = dom.firstChild
		while child
			if child.nodeType != 3 and !child.hasAttribute?(cola.constants.IGNORE_DIRECTIVE)
				child = @refreshItemDomBinding(child, itemScope)
			child = child.nextSibling

		initializers = cola.util.userData(dom, cola.constants.DOM_INITIALIZER_KEY)
		if initializers
			initializer(itemScope, dom) for initializer in initializers
			cola.util.removeUserData(dom, cola.constants.DOM_INITIALIZER_KEY)
		return currentDom or dom

class cola._DomFeature extends cola._ExpressionFeature
	writeBack: (domBinding, value) ->
		path = @path
		if path and typeof path == "string"
			@ignoreMessage = true
			domBinding.scope.set(path, value)
			@ignoreMessage = false
		return

	_processMessage: (domBinding, bindingPath, path, type, arg)->
		if cola.constants.MESSAGE_REFRESH <= type <= cola.constants.MESSAGE_CURRENT_CHANGE or @watchingMoreMessage
			@refresh(domBinding)
		return

	_refresh: (domBinding)->
		return if @ignoreMessage
		value = @evaluate(domBinding)
		@_doRefresh(domBinding, value)
		return

class cola._TextNodeFeature extends cola._DomFeature
	_doRefresh: (domBinding, value) ->
		$fly(domBinding.dom).text(if !value? then "" else value)
		return

class cola._DomAttrFeature extends cola._DomFeature
	constructor: (expression, @attr, @isStyle) ->
		super(expression)

	_doRefresh: (domBinding, value) ->
		attr = @attr
		if attr == "text"
			domBinding.$dom.text(if !value? then "" else value)
		else if attr == "html"
			domBinding.$dom.html(if !value? then "" else value)
		else if @isStyle
			domBinding.$dom.css(attr, value)
		else
			domBinding.$dom.attr(attr, if !value? then "" else value)
		return

class cola._DomClassFeature extends cola._DomFeature
	constructor: (expression, @className) ->
		super(expression)

	_doRefresh: (domBinding, value) ->
		domBinding.$dom[if value then "addClass" else "removeClass"](@className)
		return

class cola._TextBoxFeature extends cola._DomFeature
	init: (domBinding) ->
		feature = @
		domBinding.$dom.on "input", () ->
			feature.writeBack(domBinding, @value)
			return
		super()
		return

	_doRefresh: (domBinding, value)->
		domBinding.dom.value = value or ""
		return

class cola._CheckboxFeature extends cola._DomFeature
	init: (domBinding) ->
		feature = @
		domBinding.$dom.on("click", () ->
			feature.writeBack(domBinding, @checked)
			return
		)
		super()
		return

	_doRefresh: (domBinding, value)->
		checked = cola.DataType.defaultDataTypes.boolean.parse(value)
		domBinding.dom.checked = checked
		return

class cola._RadioFeature extends cola._DomFeature
	init: (domBinding) ->
		domBinding.$dom.on("click", () ->
			checked = this.checked
			if checked then @writeBack(domBinding, checked)
			return
		)
		super()
		return

	_doRefresh: (domBinding, value)->
		domBinding.dom.checked = (value == domBinding.dom.value)
		return

class cola._SelectFeature extends cola._DomFeature
	init: (domBinding) ->
		feature = @
		domBinding.$dom.on("change", () ->
			value = @options[@selectedIndex]
			feature.writeBack(domBinding, value?.value)
			return
		)
		super()
		return

	_doRefresh: (domBinding, value)->
		domBinding.dom.value = value
		return

class cola._DisplayFeature extends cola._DomFeature
	_doRefresh: (domBinding, value)->
		domBinding.dom.style.display = if value then "" else "none"
		return

class cola._SelectOptionsFeature extends cola._DomFeature
	_doRefresh: (domBinding, optionValues)->
		return unless optionValues instanceof Array or optionValues instanceof cola.EntityList

		options = domBinding.dom.options
		if optionValues instanceof cola.EntityList
			options.length = optionValues.entityCount
		else
			options.length = optionValues.length

		cola.each optionValues, (optionValue, i) ->
			option = options[i]
			if cola.util.isSimpleValue(optionValue)
				$fly(option).removeAttr("value").text(optionValue)
			else if optionValue instanceof cola.Entity
				$fly(option).attr("value",
					optionValue.get("value") or optionValue.get("key")).text(optionValue.get("text") or optionValue.get("name"))
			else
				$fly(option).attr("value",
					optionValue.value or optionValue.key).text(optionValue.text or optionValue.name)
			return
		return